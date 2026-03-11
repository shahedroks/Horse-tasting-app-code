import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Crops image to the guide region (center portion).
/// Guide is specified as fraction of width/height (e.g. 0.1 margin = 0.8 inner).
class ImageProcessingService {
  /// Crop image to center region. [marginFraction] = fraction of width/height to cut from each side (default 0.1 = 80% inner).
  static Future<Uint8List?> cropToGuide(
    Uint8List imageBytes, {
    double marginFraction = 0.1,
  }) async {
    return compute(_cropToGuideIsolate, _CropInput(imageBytes, marginFraction));
  }

  static Uint8List? _cropToGuideIsolate(_CropInput input) {
    final image = img.decodeImage(input.bytes);
    if (image == null) return null;
    final w = image.width;
    final h = image.height;
    final marginX = (w * input.marginFraction).round();
    final marginY = (h * input.marginFraction).round();
    final x = marginX.clamp(0, w - 1);
    final y = marginY.clamp(0, h - 1);
    final cw = (w - 2 * marginX).clamp(1, w);
    final ch = (h - 2 * marginY).clamp(1, h);
    final cropped = img.copyCrop(image, x: x, y: y, width: cw, height: ch);
    return Uint8List.fromList(img.encodeJpg(cropped));
  }
}

class _CropInput {
  final Uint8List bytes;
  final double marginFraction;
  _CropInput(this.bytes, this.marginFraction);
}
