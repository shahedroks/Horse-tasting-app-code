import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../models/models.dart';
import 'calibration_service.dart';

/// Detects round/elliptical object in image and measures pixel dimensions.
/// Uses simple threshold + center-of-mass heuristics; fallback to manual bounds.
/// Note: For stronger contour/ellipse detection, consider adding image_processing_contouring.
class MeasurementService {
  MeasurementService(this._calibration);

  final CalibrationService _calibration;

  /// Attempt automatic detection of the largest rectangular object in the image.
  ///
  /// Pipeline (OpenCV‑style, implemented with `image`):
  /// 1) Convert to grayscale
  /// 2) Gaussian blur (approx. 5x5)
  /// 3) Edge detection (Sobel magnitude as Canny‑like edges)
  /// 4) Threshold to binary edge map
  /// 5) Dilate edges to connect gaps
  /// 6) Connected‑component labelling as contour groups
  /// 7) Filter components by area and rectangularity
  /// 8) Choose the largest valid rectangle and map back to full resolution.
  ///
  /// Returns null if detection is unreliable (caller should fall back to manual).
  Future<ObjectBounds?> detectObject(Uint8List imageBytes) async {
    return compute(_detectObjectIsolate, imageBytes);
  }

  static Future<ObjectBounds?> _detectObjectIsolate(Uint8List bytes) async {
    final original = img.decodeImage(bytes);
    if (original == null) return null;
    final ow = original.width;
    final oh = original.height;
    if (ow < 20 || oh < 20) return null;

    // Resize to speed up processing while keeping aspect ratio.
    const maxSize = 400;
    final scale =
        (ow > maxSize || oh > maxSize) ? (maxSize / (ow > oh ? ow : oh)) : 1.0;
    final small = scale < 1
        ? img.copyResize(
            original,
            width: (ow * scale).round(),
            height: (oh * scale).round(),
          )
        : original;

    final sw = small.width;
    final sh = small.height;
    if (sw < 20 || sh < 20) return null;

    // Step 1: grayscale (keep a copy for intensity-based mask).
    final gray = img.grayscale(small);
    final grayForEdges = img.Image.from(gray);

    // Step 2: Gaussian blur (radius 2 ~ 5x5 kernel) on edge image.
    img.gaussianBlur(grayForEdges, radius: 2);

    // Step 3: Sobel edge detection (Canny‑like) on blurred copy.
    img.sobel(grayForEdges);

    // Step 4: Threshold to get binary edge map and dark-region mask.
    // Sobel output is in [0, 255]; values above this are considered strong edges.
    const edgeThreshold = 40;
    // Dark object on lighter background (phone on table, etc.).
    const darkThreshold = 170;
    final int len = sw * sh;
    final List<int> mask = List<int>.filled(len, 0);
    for (int y = 0; y < sh; y++) {
      for (int x = 0; x < sw; x++) {
        final int idx = y * sw + x;
        final int edgeVal = grayForEdges.getPixel(x, y).r.toInt();
        final int lum = gray.getPixel(x, y).r.toInt();
        final bool isEdge = edgeVal > edgeThreshold;
        final bool isDark = lum < darkThreshold;
        if (isEdge || isDark) {
          mask[idx] = 1;
        }
      }
    }

    // Step 4.5: Dilate mask once to connect small gaps.
    List<int> dilated = List<int>.from(mask);
    for (int y = 1; y < sh - 1; y++) {
      for (int x = 1; x < sw - 1; x++) {
        final idx = y * sw + x;
        if (mask[idx] == 1) continue;
        bool anyNeighbor = false;
        for (int dy = -1; dy <= 1 && !anyNeighbor; dy++) {
          for (int dx = -1; dx <= 1; dx++) {
            final nIdx = (y + dy) * sw + (x + dx);
            if (mask[nIdx] == 1) {
              anyNeighbor = true;
              break;
            }
          }
        }
        if (anyNeighbor) {
          dilated[idx] = 1;
        }
      }
    }

    // Step 5–7: Connected components as "contours" and rectangle filtering.
    final List<int> visited = List<int>.filled(len, 0);
    int bestArea = 0;
    int bestMinX = 0, bestMinY = 0, bestMaxX = 0, bestMaxY = 0;

    // Scale area threshold from original requirement (> 5000 px in full image).
    final double areaScale = (ow * oh) / (sw * sh);
    final int minComponentArea = (5000 / areaScale).round();

    for (int y = 0; y < sh; y++) {
      for (int x = 0; x < sw; x++) {
        final startIdx = y * sw + x;
        if (dilated[startIdx] == 0 || visited[startIdx] == 1) continue;

        // BFS / DFS for this component.
        final List<int> stack = <int>[startIdx];
        visited[startIdx] = 1;
        int minX = x, maxX = x, minY = y, maxY = y;
        int count = 0;

        while (stack.isNotEmpty) {
          final idx = stack.removeLast();
          final cx = idx % sw;
          final cy = idx ~/ sw;
          count++;
          if (cx < minX) minX = cx;
          if (cx > maxX) maxX = cx;
          if (cy < minY) minY = cy;
          if (cy > maxY) maxY = cy;

          for (int dy = -1; dy <= 1; dy++) {
            for (int dx = -1; dx <= 1; dx++) {
              if (dx == 0 && dy == 0) continue;
              final nx = cx + dx;
              final ny = cy + dy;
              if (nx < 0 || nx >= sw || ny < 0 || ny >= sh) continue;
              final nIdx = ny * sw + nx;
              if (dilated[nIdx] == 1 && visited[nIdx] == 0) {
                visited[nIdx] = 1;
                stack.add(nIdx);
              }
            }
          }
        }

        if (count < minComponentArea) continue;

        final int boxW = maxX - minX + 1;
        final int boxH = maxY - minY + 1;
        if (boxW < 10 || boxH < 10) continue;

        final double aspect = boxW / boxH;
        if (aspect < 0.2 || aspect > 5.0) continue;

        final double boxArea = (boxW * boxH).toDouble();
        final double fillRatio = count / boxArea;
        if (fillRatio < 0.2) continue;

        if (count > bestArea) {
          bestArea = count;
          bestMinX = minX;
          bestMinY = minY;
          bestMaxX = maxX;
          bestMaxY = maxY;
        }
      }
    }

    if (bestArea <= 0) return null;

    // Refine inside the best component: tighten to the densest mask region so
    // we do not include too much background above/below the object.
    int refMinX = bestMaxX, refMaxX = bestMinX, refMinY = bestMaxY, refMaxY = bestMinY;
    int refCount = 0;
    for (int y = bestMinY; y <= bestMaxY; y++) {
      for (int x = bestMinX; x <= bestMaxX; x++) {
        final idx = y * sw + x;
        if (mask[idx] == 1) {
          refCount++;
          if (x < refMinX) refMinX = x;
          if (x > refMaxX) refMaxX = x;
          if (y < refMinY) refMinY = y;
          if (y > refMaxY) refMaxY = y;
        }
      }
    }
    if (refCount < minComponentArea ~/ 2) {
      refMinX = bestMinX;
      refMaxX = bestMaxX;
      refMinY = bestMinY;
      refMaxY = bestMaxY;
    }

    // Map refined rectangle back to original resolution.
    final double invScale = 1 / scale;
    final double rectMinX = refMinX * invScale;
    final double rectMaxX = refMaxX * invScale;
    final double rectMinY = refMinY * invScale;
    final double rectMaxY = refMaxY * invScale;

    final double width = rectMaxX - rectMinX + 1;
    final double height = rectMaxY - rectMinY + 1;
    if (width < 10 || height < 10) return null;

    final double cx = rectMinX + width / 2;
    final double cy = rectMinY + height / 2;

    return ObjectBounds(
      center: Offset(cx, cy),
      halfWidth: width / 2,
      halfHeight: height / 2,
    );
  }

  /// Convert object bounds + optional reference corners to MeasurementResult (mm).
  /// [scalePxPerMm] can come from reference detection in same image or from fixed calibration.
  MeasurementResult? toMeasurementResult({
    required ObjectBounds objectBounds,
    double? scalePxPerMm,
    ReferenceCorners? referenceCorners,
    ReferenceType? referenceType,
    double? rulerSegmentMm,
    MeasurementQuality quality = MeasurementQuality.medium,
  }) {
    double? scale = scalePxPerMm;
    if (scale == null && referenceCorners != null && referenceType != null) {
      final refW = referenceType == ReferenceType.ruler && rulerSegmentMm != null
          ? rulerSegmentMm
          : referenceType.widthMm;
      final refH = referenceType == ReferenceType.ruler && rulerSegmentMm != null
          ? rulerSegmentMm
          : referenceType.heightMm;
      scale = _calibration.computeScaleFromReference(
        referenceCorners: referenceCorners,
        referenceWidthMm: refW,
        referenceHeightMm: refH,
      );
    }
    if (scale == null) scale = _calibration.current?.pixelsPerMm;
    if (scale == null || scale <= 0) return null;

    final widthPx = objectBounds.widthPx;
    final heightPx = objectBounds.heightPx;
    final widthMm = widthPx / scale;
    final heightMm = heightPx / scale;

    return MeasurementResult(
      widthMm: widthMm,
      heightMm: heightMm,
      widthPx: widthPx,
      heightPx: heightPx,
      quality: quality,
    );
  }

  /// Evaluate measurement quality from bounds and image size (e.g. too small = poor).
  MeasurementQuality evaluateQuality(ObjectBounds bounds, int imageWidth, int imageHeight) {
    final area = bounds.widthPx * bounds.heightPx;
    final total = imageWidth * imageHeight;
    final ratio = area / total;
    if (ratio < 0.02) return MeasurementQuality.poor;
    if (ratio < 0.05) return MeasurementQuality.medium;
    return MeasurementQuality.good;
  }
}
