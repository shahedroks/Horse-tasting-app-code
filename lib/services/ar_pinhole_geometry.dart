import 'dart:math' as math;

/// Pinhole camera model: convert pixel extent to mm using distance from camera
/// to the subject plane (from ARCore/ARKit hit-test [ARHitTestResult.distance]).
///
/// [horizontalFovDeg] is the full horizontal field of view of the **captured image**
/// (typical phone wide ~60–70°). Tune if results are systematically off.
class ArPinholeGeometry {
  ArPinholeGeometry._();

  /// Focal length in pixels from horizontal FOV and image width.
  static double focalLengthPixels(int imageWidth, double horizontalFovDeg) {
    if (imageWidth <= 0 || horizontalFovDeg <= 0 || horizontalFovDeg >= 179) {
      return 0;
    }
    final halfFovRad = horizontalFovDeg * math.pi / 360;
    final t = math.tan(halfFovRad);
    if (t <= 1e-9) return 0;
    return (imageWidth / 2) / t;
  }

  /// Physical extent in mm for [px] pixels at [distanceMeters] along optical axis.
  static double pxToMm({
    required double px,
    required double distanceMeters,
    required int imageWidth,
    double horizontalFovDeg = 63,
  }) {
    if (px <= 0 || distanceMeters <= 0) return 0;
    final fx = focalLengthPixels(imageWidth, horizontalFovDeg);
    if (fx <= 0) return 0;
    return 1000.0 * px * distanceMeters / fx;
  }
}
