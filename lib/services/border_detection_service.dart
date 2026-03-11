import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../models/object_bounds.dart';

/// Output of border detection: bounds in cropped image coordinates and confidence.
class BorderDetectionOutput {
  final ObjectBounds bounds;
  final double confidence;
  final int imageWidth;
  final int imageHeight;

  const BorderDetectionOutput({
    required this.bounds,
    required this.confidence,
    required this.imageWidth,
    required this.imageHeight,
  });
}

/// Detects the main oval/round object inside the image (cropped guide region).
/// Pipeline: resize → grayscale → blur → edge → threshold → largest central blob → fit bbox.
class BorderDetectionService {
  /// Run detection on image bytes (e.g. cropped to guide). Returns null if no suitable object.
  Future<BorderDetectionOutput?> detect(Uint8List imageBytes) async {
    return compute(_detectIsolate, imageBytes);
  }

  static Future<BorderDetectionOutput?> _detectIsolate(Uint8List bytes) async {
    final image = img.decodeImage(bytes);
    if (image == null) return null;
    final w = image.width;
    final h = image.height;
    if (w < 10 || h < 10) return null;

    const maxSize = 400;
    final scale = (w > maxSize || h > maxSize)
        ? (maxSize / math.max(w, h))
        : 1.0;
    final small = scale < 1
        ? img.copyResize(image, width: (w * scale).round(), height: (h * scale).round())
        : image;

    final gray = img.grayscale(small);
    img.gaussianBlur(gray, radius: 2);
    img.sobel(gray);
    const threshold = 40;
    final centerX = small.width / 2.0;
    final centerY = small.height / 2.0;

    int sumX = 0, sumY = 0, count = 0;
    int minX = small.width, minY = small.height, maxX = 0, maxY = 0;
    for (int y = 0; y < small.height; y++) {
      for (int x = 0; x < small.width; x++) {
        final v = gray.getPixel(x, y).r;
        if (v > threshold) {
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

    if (count < 50) return null;

    final cx = sumX / count;
    final cy = sumY / count;
    final distFromCenter = math.sqrt(
        math.pow(cx - centerX, 2) + math.pow(cy - centerY, 2));
    final maxDist = math.sqrt(centerX * centerX + centerY * centerY);
    final centerScore = 1 - (distFromCenter / (maxDist + 1)).clamp(0.0, 1.0);

    final boxW = (maxX - minX + 1).toDouble();
    final boxH = (maxY - minY + 1).toDouble();
    if (boxW < 5 || boxH < 5) return null;

    final area = boxW * boxH;
    final totalArea = small.width * small.height;
    final areaRatio = area / totalArea;
    if (areaRatio < 0.01 || areaRatio > 0.95) return null;

    final aspect = boxW / boxH;
    final ovalScore = aspect >= 0.3 && aspect <= 3 ? 1.0 : (1 - (aspect - 1).abs() * 0.3).clamp(0.0, 1.0);

    final confidence = (centerScore * 0.4 + ovalScore * 0.3 + (areaRatio * 2).clamp(0.0, 1.0) * 0.3).clamp(0.0, 1.0);

    final invScale = 1 / scale;
    final bounds = ObjectBounds(
      center: Offset(
        (minX + maxX) / 2 * invScale,
        (minY + maxY) / 2 * invScale,
      ),
      halfWidth: boxW / 2 * invScale,
      halfHeight: boxH / 2 * invScale,
      angle: 0,
    );

    return BorderDetectionOutput(
      bounds: bounds,
      confidence: confidence,
      imageWidth: w,
      imageHeight: h,
    );
  }
}
