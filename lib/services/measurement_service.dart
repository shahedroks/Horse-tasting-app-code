import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

import '../models/models.dart';
import 'calibration_service.dart';
import 'ml_object_detector.dart';

/// Detects rectangular object in image (phone, box, etc.).
/// On Android uses native Kotlin detector for better performance; elsewhere uses Dart isolate.
/// Fallback to manual bounds when detection is unreliable.
class MeasurementService {
  MeasurementService(this._calibration);

  static const MethodChannel _nativeDetectChannel =
      MethodChannel('com.example.test_project_glue_u/object_detection');

  final CalibrationService _calibration;

  /// Internal: bounds plus a label showing which detector produced it.
  static ({ObjectBounds bounds, DetectionMethod method, double confidence})
      _pack(ObjectBounds bounds, DetectionMethod method, double confidence) {
    return (bounds: bounds, method: method, confidence: confidence);
  }

  /// Detect object and return bounds + method + confidence.
  Future<({ObjectBounds bounds, DetectionMethod method, double confidence})?>
      detectObjectDetailed(Uint8List imageBytes) async {
    int? ow;
    int? oh;
    ObjectBounds? nativeBounds;

    // Try Android native first.
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        final result =
            await _nativeDetectChannel.invokeMethod<Map<Object?, Object?>>(
          'detectObject',
          imageBytes,
        );
        if (result != null) {
          final cx = (result['centerX'] as num).toDouble();
          final cy = (result['centerY'] as num).toDouble();
          final hw = (result['halfWidth'] as num).toDouble();
          final hh = (result['halfHeight'] as num).toDouble();
          nativeBounds = ObjectBounds(
            center: Offset(cx, cy),
            halfWidth: hw,
            halfHeight: hh,
          );
        }
      } catch (_) {
        // ignore
      }
    }

    // Decode once for heuristics + ML scaling.
    final decoded = img.decodeImage(imageBytes);
    if (decoded != null) {
      ow = decoded.width;
      oh = decoded.height;
    }

    bool looksReasonable(ObjectBounds b) {
      if (ow == null || oh == null) return true;
      final areaRatio = (b.widthPx * b.heightPx) / (ow * oh);
      final aspect = b.widthPx / b.heightPx;
      final okArea = areaRatio >= 0.05 && areaRatio <= 0.85;
      final okAspect = aspect >= 0.25 && aspect <= 4.0;
      return okArea && okAspect;
    }

    // Foreground fallback: good for dark object on light background (e.g. hoof photo).
    // Compute early so we can prefer it.
    final fg = await compute(_detectForegroundBoundsIsolate, imageBytes);

    double? areaRatioOf(ObjectBounds? b) {
      if (b == null || ow == null || oh == null) return null;
      return (b.widthPx * b.heightPx) / (ow * oh);
    }

    // Prefer native when it looks reasonable.
    if (nativeBounds != null && looksReasonable(nativeBounds)) {
      // If native is tiny but foreground is big, prefer foreground.
      final nArea = areaRatioOf(nativeBounds);
      final fArea = areaRatioOf(fg);
      if (nArea != null &&
          fArea != null &&
          nArea < 0.20 &&
          fArea >= 0.35 &&
          fArea <= 0.98) {
        return _pack(fg!, DetectionMethod.autoForeground, 0.68);
      }
      return _pack(nativeBounds, DetectionMethod.autoNative, 0.7);
    }

    // If foreground looks good, prefer it (useful for hoof images).
    final fArea = areaRatioOf(fg);
    if (fArea != null && fArea >= 0.35 && fArea <= 0.98) {
      return _pack(fg!, DetectionMethod.autoForeground, 0.66);
    }

    // ML fallback last.
    if (ow != null && oh != null) {
      final ml = await MlObjectDetector.detect(imageBytes, ow, oh);
      if (ml != null) {
        // Reject tiny/invalid ML boxes (common when model doesn't know the object).
        final areaRatio = (ml.widthPx * ml.heightPx) / (ow * oh);
        if (areaRatio >= 0.02 && areaRatio <= 0.90) {
          return _pack(ml, DetectionMethod.autoMl, 0.75);
        }
      }
    }

    // If we haven't returned yet, keep the previous fallback behavior.
    if (fg != null && ow != null && oh != null) {
      final areaRatio = (fg.widthPx * fg.heightPx) / (ow * oh);
      if (areaRatio >= 0.05 && areaRatio <= 0.98) {
        return _pack(fg, DetectionMethod.autoForeground, 0.65);
      }
    }

    if (nativeBounds != null) return _pack(nativeBounds, DetectionMethod.autoNative, 0.4);
    return null;
  }

  /// Foreground detector for light background scenes.
  /// Uses Otsu threshold on grayscale, selects largest dark component, returns its bounding box.
  static Future<ObjectBounds?> _detectForegroundBoundsIsolate(Uint8List bytes) async {
    final original = img.decodeImage(bytes);
    if (original == null) return null;
    final ow = original.width;
    final oh = original.height;
    if (ow < 20 || oh < 20) return null;

    const maxSize = 450;
    final scale =
        (ow > maxSize || oh > maxSize) ? (maxSize / (ow > oh ? ow : oh)) : 1.0;
    final small = scale < 1
        ? img.copyResize(
            original,
            width: (ow * scale).round(),
            height: (oh * scale).round(),
            interpolation: img.Interpolation.average,
          )
        : original;
    final sw = small.width;
    final sh = small.height;

    final gray = img.grayscale(small);

    // Otsu threshold
    final hist = List<int>.filled(256, 0);
    for (int y = 0; y < sh; y++) {
      for (int x = 0; x < sw; x++) {
        final v = gray.getPixel(x, y).r.toInt();
        hist[v]++;
      }
    }
    final total = sw * sh;
    double sum = 0;
    for (int i = 0; i < 256; i++) {
      sum += i * hist[i];
    }
    double sumB = 0;
    int wB = 0;
    int wF = 0;
    double varMax = 0;
    int threshold = 128;
    for (int t = 0; t < 256; t++) {
      wB += hist[t];
      if (wB == 0) continue;
      wF = total - wB;
      if (wF == 0) break;
      sumB += t * hist[t];
      final mB = sumB / wB;
      final mF = (sum - sumB) / wF;
      final varBetween = wB * wF * (mB - mF) * (mB - mF);
      if (varBetween > varMax) {
        varMax = varBetween;
        threshold = t;
      }
    }

    ObjectBounds? best;
    double bestScore = -1;

    ObjectBounds? runMask(bool darkForeground) {
      final len = sw * sh;
      final mask = List<int>.filled(len, 0);
      for (int y = 0; y < sh; y++) {
        for (int x = 0; x < sw; x++) {
          final idx = y * sw + x;
          final v = gray.getPixel(x, y).r.toInt();
          final isFg = darkForeground ? (v < threshold) : (v > threshold);
          if (isFg) mask[idx] = 1;
        }
      }

      // Dilate once to connect holes.
      final dilated = List<int>.from(mask);
      for (int y = 1; y < sh - 1; y++) {
        for (int x = 1; x < sw - 1; x++) {
          final idx = y * sw + x;
          if (mask[idx] == 1) continue;
          bool any = false;
          for (int dy = -1; dy <= 1 && !any; dy++) {
            for (int dx = -1; dx <= 1; dx++) {
              if (mask[(y + dy) * sw + (x + dx)] == 1) {
                any = true;
                break;
              }
            }
          }
          if (any) dilated[idx] = 1;
        }
      }

      final visited = List<int>.filled(len, 0);
      int bestCount = 0;
      int bestMinX = 0, bestMinY = 0, bestMaxX = 0, bestMaxY = 0;
      final minArea = (0.01 * len).round(); // >= 1% of image

      for (int y = 0; y < sh; y++) {
        for (int x = 0; x < sw; x++) {
          final start = y * sw + x;
          if (dilated[start] == 0 || visited[start] == 1) continue;
          final stack = <int>[start];
          visited[start] = 1;
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

          if (count < minArea) continue;

          // reject components that touch too much border (background)
          final touchesBorder =
              minX == 0 || minY == 0 || maxX == sw - 1 || maxY == sh - 1;
          if (touchesBorder) continue;

          if (count > bestCount) {
            bestCount = count;
            bestMinX = minX;
            bestMinY = minY;
            bestMaxX = maxX;
            bestMaxY = maxY;
          }
        }
      }

      if (bestCount == 0) return null;

      final invScale = 1 / scale;
      final minX = bestMinX * invScale;
      final maxX = bestMaxX * invScale;
      final minY = bestMinY * invScale;
      final maxY = bestMaxY * invScale;
      final w = (maxX - minX + 1).clamp(1.0, ow.toDouble());
      final h = (maxY - minY + 1).clamp(1.0, oh.toDouble());
      final cx = minX + w / 2;
      final cy = minY + h / 2;

      return ObjectBounds(
        center: Offset(cx, cy),
        halfWidth: w / 2,
        halfHeight: h / 2,
      );
    }

    double score(ObjectBounds b) {
      final areaRatio = (b.widthPx * b.heightPx) / (ow * oh);
      final centerDx = ((b.center.dx / ow) - 0.5).abs();
      final centerDy = ((b.center.dy / oh) - 0.5).abs();
      final centerScore = (1 - (centerDx + centerDy)).clamp(0.0, 1.0);
      // Prefer larger objects, but not whole image.
      final areaScore = ((areaRatio - 0.05) / 0.75).clamp(0.0, 1.0);
      return areaScore * 0.7 + centerScore * 0.3;
    }

    for (final dark in [true, false]) {
      final b = runMask(dark);
      if (b == null) continue;
      final s = score(b);
      if (s > bestScore) {
        bestScore = s;
        best = b;
      }
    }

    return best;
  }

  /// Attempt automatic detection of the largest rectangular object in the image.
  /// On Android tries native (Kotlin) detector first, then Dart fallback.
  /// Returns null if detection is unreliable (caller should fall back to manual).
  Future<ObjectBounds?> detectObject(Uint8List imageBytes) async {
    final detailed = await detectObjectDetailed(imageBytes);
    return detailed?.bounds;
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
