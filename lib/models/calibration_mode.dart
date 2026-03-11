/// Measurement mode: reference object in image vs fixed calibration.
enum CalibrationMode {
  /// Use a known-size reference object in the same image (recommended).
  referenceObject,
  /// One-time calibration at fixed distance; less accurate if distance changes.
  fixedCalibration,
}
