import 'dart:ui' show Offset;

import 'package:flutter/material.dart';

import '../models/object_bounds.dart';

/// Draws detected border and width/height measurement lines over the image.
class MeasurementOverlayPainter extends CustomPainter {
  final ObjectBounds bounds;
  final double scale;
  final bool showWidthHeightLines;

  const MeasurementOverlayPainter({
    required this.bounds,
    required this.scale,
    this.showWidthHeightLines = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(bounds.center.dx * scale, bounds.center.dy * scale);
    final hw = bounds.halfWidth * scale;
    final hh = bounds.halfHeight * scale;

    final borderPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(
      Rect.fromCenter(center: c, width: hw * 2, height: hh * 2),
      borderPaint,
    );

    if (showWidthHeightLines) {
      final linePaint = Paint()
        ..color = Colors.blue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawLine(
        Offset(c.dx - hw, c.dy),
        Offset(c.dx + hw, c.dy),
        linePaint,
      );
      canvas.drawLine(
        Offset(c.dx, c.dy - hh),
        Offset(c.dx, c.dy + hh),
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant MeasurementOverlayPainter oldDelegate) =>
      oldDelegate.bounds != bounds || oldDelegate.scale != scale;
}
