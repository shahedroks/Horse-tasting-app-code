import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Offset;

import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../models/object_bounds.dart';

class MlObjectDetector {
  // Prefer `detect.tflite` if you rename it, but also support the raw TF filename.
  static const List<String> _assetCandidates = [
    'assets/models/detect.tflite',
    'assets/models/lite-model_ssd_mobilenet_v1_1_metadata_2.tflite',
  ];

  static Interpreter? _interpreter;
  static int _inputW = 0;
  static int _inputH = 0;
  static TensorType? _inputType;

  static Future<void> init() async {
    if (_interpreter != null) return;
    ByteData? bytes;
    for (final path in _assetCandidates) {
      try {
        bytes = await rootBundle.load(path);
        break;
      } catch (_) {
        // try next
      }
    }
    if (bytes == null) {
      throw StateError('No TFLite model found in assets/models/.');
    }
    final buffer = bytes.buffer.asUint8List();
    _interpreter = Interpreter.fromBuffer(buffer);

    final input = _interpreter!.getInputTensor(0);
    final shape = input.shape; // e.g. [1, 320, 320, 3]
    _inputType = input.type;
    if (shape.length >= 4) {
      _inputH = shape[1];
      _inputW = shape[2];
    } else {
      throw StateError('Unsupported model input shape: $shape');
    }
  }

  static Future<ObjectBounds?> detect(
    Uint8List imageBytes,
    int imageWidth,
    int imageHeight, {
    double minScore = 0.40,
  }) async {
    try {
      await init();
    } catch (_) {
      return null;
    }
    final interpreter = _interpreter!;

    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) return null;

    final resized = img.copyResize(
      decoded,
      width: _inputW,
      height: _inputH,
      interpolation: img.Interpolation.average,
    );

    // Build input tensor [1, H, W, 3]
    final input = _buildInput(resized, _inputType!);

    // Outputs: most TF Lite detection models provide
    // boxes [1,N,4], classes [1,N], scores [1,N], numDetections [1]
    final out0 = _tensorAsList(interpreter.getOutputTensor(0).shape);
    final out1 = _tensorAsList(interpreter.getOutputTensor(1).shape);
    final out2 = _tensorAsList(interpreter.getOutputTensor(2).shape);
    final out3 = _tensorAsList(interpreter.getOutputTensor(3).shape);

    final outputs = <int, Object>{
      0: out0,
      1: out1,
      2: out2,
      3: out3,
    };

    interpreter.runForMultipleInputs([input], outputs);

    final boxes = out0 as List<List<List<double>>>;
    final scores = out2 as List<List<double>>;

    final n = boxes.first.length;
    int bestIdx = -1;
    double bestScore = minScore;
    for (int i = 0; i < n; i++) {
      final s = scores[0][i];
      if (s > bestScore) {
        bestScore = s;
        bestIdx = i;
      }
    }
    if (bestIdx < 0) return null;

    final b = boxes[0][bestIdx]; // [ymin, xmin, ymax, xmax] usually normalized
    if (b.length < 4) return null;

    double ymin = b[0];
    double xmin = b[1];
    double ymax = b[2];
    double xmax = b[3];

    // If normalized (0..1), scale to pixels.
    final bool looksNormalized =
        ymin >= 0 && xmin >= 0 && ymax <= 1.5 && xmax <= 1.5;
    if (looksNormalized) {
      xmin *= imageWidth;
      xmax *= imageWidth;
      ymin *= imageHeight;
      ymax *= imageHeight;
    }

    xmin = xmin.clamp(0.0, imageWidth.toDouble());
    xmax = xmax.clamp(0.0, imageWidth.toDouble());
    ymin = ymin.clamp(0.0, imageHeight.toDouble());
    ymax = ymax.clamp(0.0, imageHeight.toDouble());

    final w = math.max(1.0, xmax - xmin);
    final h = math.max(1.0, ymax - ymin);
    final cx = xmin + w / 2.0;
    final cy = ymin + h / 2.0;

    return ObjectBounds(
      center: Offset(cx, cy),
      halfWidth: w / 2.0,
      halfHeight: h / 2.0,
    );
  }

  static Object _buildInput(img.Image resized, TensorType inputType) {
    if (inputType == TensorType.uint8) {
      final data = Uint8List(_inputW * _inputH * 3);
      int o = 0;
      for (int y = 0; y < _inputH; y++) {
        for (int x = 0; x < _inputW; x++) {
          final p = resized.getPixel(x, y);
          data[o++] = p.r.toInt();
          data[o++] = p.g.toInt();
          data[o++] = p.b.toInt();
        }
      }
      return data.reshape([1, _inputH, _inputW, 3]);
    }

    // Default float32: normalize to 0..1
    final data = Float32List(_inputW * _inputH * 3);
    int o = 0;
    for (int y = 0; y < _inputH; y++) {
      for (int x = 0; x < _inputW; x++) {
        final p = resized.getPixel(x, y);
        data[o++] = p.r / 255.0;
        data[o++] = p.g / 255.0;
        data[o++] = p.b / 255.0;
      }
    }
    return data.reshape([1, _inputH, _inputW, 3]);
  }

  static Object _tensorAsList(List<int> shape) {
    // Supports common detection shapes.
    // boxes: [1,N,4], classes/scores: [1,N], numDetections: [1]
    if (shape.length == 3) {
      final a = shape[0], b = shape[1], c = shape[2];
      return List.generate(
        a,
        (_) => List.generate(b, (_) => List.filled(c, 0.0)),
      );
    }
    if (shape.length == 2) {
      final a = shape[0], b = shape[1];
      return List.generate(a, (_) => List.filled(b, 0.0));
    }
    if (shape.length == 1) {
      return List.filled(shape[0], 0.0);
    }
    // Fallback: scalar
    return 0.0;
  }
}

