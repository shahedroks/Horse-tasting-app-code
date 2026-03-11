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

  /// Attempt automatic detection of the largest round/elliptical region.
  /// Returns null if detection is unreliable (caller should use manual adjustment).
  Future<ObjectBounds?> detectObject(Uint8List imageBytes) async {
    return compute(_detectObjectIsolate, imageBytes);
  }

  static Future<ObjectBounds?> _detectObjectIsolate(Uint8List bytes) async {
    final image = img.decodeImage(bytes);
    if (image == null) return null;
    final small = img.copyResize(image, width: 300);
    final gray = img.grayscale(small);
    // Use luminance threshold to separate darker object from background
    const threshold = 150;
    int sumX = 0, sumY = 0, count = 0;
    int minX = small.width, minY = small.height, maxX = 0, maxY = 0;
    for (int y = 0; y < gray.height; y++) {
      for (int x = 0; x < gray.width; x++) {
        final p = gray.getPixel(x, y);
        final v = p.r;
        if (v < threshold) {
          sumX += x;
          sumY += y;
          count++;
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;
        }
      }
    }
    if (count < 100) return null;
    final scaleX = image.width / 300.0;
    final scaleY = image.height / 300.0;
    final cx = (sumX / count) * scaleX;
    final cy = (sumY / count) * scaleY;
    final w = (maxX - minX + 1) * scaleX;
    final h = (maxY - minY + 1) * scaleY;
    if (w < 10 || h < 10) return null;
    return ObjectBounds(
      center: Offset(cx, cy),
      halfWidth: w / 2,
      halfHeight: h / 2,
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
