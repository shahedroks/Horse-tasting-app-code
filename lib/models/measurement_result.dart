import 'measurement_quality.dart';

/// Result of measuring the object: dimensions in mm and quality.
class MeasurementResult {
  final double widthMm;
  final double heightMm;
  final double widthPx;
  final double heightPx;
  final MeasurementQuality quality;
  /// Optional warning message (e.g. "between sizes", "low accuracy").
  final String? warning;

  const MeasurementResult({
    required this.widthMm,
    required this.heightMm,
    required this.widthPx,
    required this.heightPx,
    this.quality = MeasurementQuality.medium,
    this.warning,
  });
}
