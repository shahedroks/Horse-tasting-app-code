import 'dart:convert';
import 'dart:math' as math;
import 'dart:io';
import 'dart:ui' show Offset;

import 'package:path_provider/path_provider.dart';

import '../models/models.dart';

/// Handles calibration: reference-object scale and fixed pixels-per-mm.
/// Persists fixed calibration to local storage.
class CalibrationService {
  CalibrationService();

  static const String _calibrationKey = 'calibration_data';
  CalibrationData? _current;

  CalibrationData? get current => _current;

  /// Load saved calibration (fixed mode) from disk.
  Future<void> loadSaved() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_calibrationKey.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        final map = jsonDecode(content) as Map<String, dynamic>;
        _current = CalibrationData.fromJson(map);
      }
    } catch (_) {
      _current = null;
    }
  }

  /// Save calibration (for fixed mode).
  Future<void> save(CalibrationData data) async {
    _current = data;
    if (data.mode != CalibrationMode.fixedCalibration) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_calibrationKey.json');
      await file.writeAsString(jsonEncode(data.toJson()));
    } catch (_) {}
  }

  /// Set current calibration (e.g. after reference detection).
  void setCurrent(CalibrationData? data) {
    _current = data;
  }

  /// Compute pixels-per-mm from reference object in image.
  /// [referenceCorners] in image coordinates; [referenceWidthMm] and [referenceHeightMm] in mm.
  /// Returns average scale (px/mm).
  double computeScaleFromReference({
    required ReferenceCorners referenceCorners,
    required double referenceWidthMm,
    required double referenceHeightMm,
  }) {
    final tl = referenceCorners.topLeft;
    final tr = referenceCorners.topRight;
    final br = referenceCorners.bottomRight;
    final bl = referenceCorners.bottomLeft;

    final widthPx = _distance(tl, tr) + _distance(bl, br);
    final heightPx = _distance(tl, bl) + _distance(tr, br);
    final scaleW = referenceWidthMm > 0 ? (widthPx / 2) / referenceWidthMm : 0.0;
    final scaleH = referenceHeightMm > 0 ? (heightPx / 2) / referenceHeightMm : 0.0;
    if (scaleW <= 0 && scaleH <= 0) return 0;
    if (scaleW <= 0) return scaleH;
    if (scaleH <= 0) return scaleW;
    return (scaleW + scaleH) / 2;
  }

  double _distance(Offset a, Offset b) {
    return math.sqrt(math.pow(a.dx - b.dx, 2) + math.pow(a.dy - b.dy, 2));
  }

  /// Convert pixel dimensions to mm using current calibration.
  /// Returns null if calibration is missing or invalid (honesty rule).
  ({double widthMm, double heightMm})? pixelsToMm({
    required double widthPx,
    required double heightPx,
    double? scalePxPerMm,
  }) {
    final scale = scalePxPerMm ?? _current?.pixelsPerMm;
    if (scale == null || scale <= 0) return null;
    return (widthMm: widthPx / scale, heightMm: heightPx / scale);
  }

  /// Check if we can measure (have reference or fixed calibration).
  bool get canMeasure {
    if (_current == null) return false;
    return _current!.isValid;
  }

  /// Message when measurement is not possible (no reference/calibration).
  static const String noCalibrationMessage =
      'Accurate real-world measurement is not possible without a reference or calibration.';
}
