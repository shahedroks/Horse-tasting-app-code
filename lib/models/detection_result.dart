import 'detection_method.dart';

/// Result of border detection and measurement (prompt2 spec).
/// Pixel dimensions always; mm only when calibration/reference exists.
class DetectionResult {
  final double widthPx;
  final double heightPx;
  final double? widthMm;
  final double? heightMm;
  final double centerX;
  final double centerY;
  final double angle;
  final double confidence;
  final DetectionMethod detectionMethod;
  final bool hasCalibration;
  final String? warningMessage;

  const DetectionResult({
    required this.widthPx,
    required this.heightPx,
    this.widthMm,
    this.heightMm,
    required this.centerX,
    required this.centerY,
    this.angle = 0,
    this.confidence = 1,
    this.detectionMethod = DetectionMethod.auto,
    this.hasCalibration = false,
    this.warningMessage,
  });

  /// Warning when no calibration: do not show fake mm.
  static const String noCalibrationWarning =
      'Real-world measurement requires calibration or a known-size reference';
}
