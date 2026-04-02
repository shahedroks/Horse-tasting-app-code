import '../services/ar_pinhole_geometry.dart';

/// Order: **calibration** (px/mm) → **AR distance** + pinhole → **1 px = 1 mm** display fallback.
double displayMmFromPx(
  double px, {
  double? scalePxPerMm,
  double? arCameraToSubjectMeters,
  int? imageWidth,
  double arHorizontalFovDeg = 63,
}) {
  if (scalePxPerMm != null && scalePxPerMm > 0) {
    return px / scalePxPerMm;
  }
  if (arCameraToSubjectMeters != null &&
      arCameraToSubjectMeters > 0 &&
      imageWidth != null &&
      imageWidth > 0) {
    return ArPinholeGeometry.pxToMm(
      px: px,
      distanceMeters: arCameraToSubjectMeters,
      imageWidth: imageWidth,
      horizontalFovDeg: arHorizontalFovDeg,
    );
  }
  return px;
}

bool hasRealCalibration(double? scalePxPerMm) =>
    scalePxPerMm != null && scalePxPerMm > 0;

bool hasArDistance(double? arCameraToSubjectMeters) =>
    arCameraToSubjectMeters != null && arCameraToSubjectMeters > 0;

/// True when mm is not the raw 1:1 px fallback.
bool hasMetricScale(
  double? scalePxPerMm,
  double? arCameraToSubjectMeters,
) =>
    hasRealCalibration(scalePxPerMm) || hasArDistance(arCameraToSubjectMeters);
