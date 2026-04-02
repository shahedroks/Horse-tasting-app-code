/// Uncalibrated UI: pixel lengths are labeled as mm using **1 px ≡ 1 display mm**.
/// This is **not** real-world millimetres; use calibration for physical size.
double displayMmFromPx(double px, {double? scalePxPerMm}) {
  if (scalePxPerMm != null && scalePxPerMm > 0) {
    return px / scalePxPerMm;
  }
  return px;
}

bool hasRealCalibration(double? scalePxPerMm) =>
    scalePxPerMm != null && scalePxPerMm > 0;
