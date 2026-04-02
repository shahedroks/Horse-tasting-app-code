/// Millimetres per pixel at **96 PPI** (CSS / typical “screen” convention):
/// `25.4 mm/inch ÷ 96 px/inch`.
const double kMmPerPixel96Ppi = 25.4 / 96;

/// Order: **calibration** (px/mm) → **96 PPI** (`1 px ≈ 0.264583 mm`).
double displayMmFromPx(
  double px, {
  double? scalePxPerMm,
}) {
  if (scalePxPerMm != null && scalePxPerMm > 0) {
    return px / scalePxPerMm;
  }
  return px * kMmPerPixel96Ppi;
}

bool hasRealCalibration(double? scalePxPerMm) =>
    scalePxPerMm != null && scalePxPerMm > 0;
