import 'dart:ui' show Offset, Rect;

/// Bounds of the target round object in image pixel coordinates.
/// Can be represented as rectangle (width/height) or ellipse (center + radii).
class ObjectBounds {
  /// Center of the object.
  final Offset center;
  /// Half of horizontal extent (radius or half-width).
  final double halfWidth;
  /// Half of vertical extent (radius or half-height).
  final double halfHeight;

  /// Rotation angle in radians (0 = axis-aligned).
  final double angle;

  const ObjectBounds({
    required this.center,
    required this.halfWidth,
    required this.halfHeight,
    this.angle = 0,
  });

  double get widthPx => halfWidth * 2;
  double get heightPx => halfHeight * 2;

  Rect get rect => Rect.fromLTRB(
        center.dx - halfWidth,
        center.dy - halfHeight,
        center.dx + halfWidth,
        center.dy + halfHeight,
      );

  ObjectBounds copyWith({
    Offset? center,
    double? halfWidth,
    double? halfHeight,
    double? angle,
  }) {
    return ObjectBounds(
      center: center ?? this.center,
      halfWidth: halfWidth ?? this.halfWidth,
      halfHeight: halfHeight ?? this.halfHeight,
      angle: angle ?? this.angle,
    );
  }
}
