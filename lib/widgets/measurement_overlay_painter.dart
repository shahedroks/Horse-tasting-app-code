import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:flutter/material.dart';

import '../models/object_bounds.dart';

/// Draws detected border and width/height measurement lines over the image.
class MeasurementOverlayPainter extends CustomPainter {
  final ObjectBounds bounds;
  final double scale;
  final bool showWidthHeightLines;
  final bool drawAsOval;

  const MeasurementOverlayPainter({
    required this.bounds,
    required this.scale,
    this.showWidthHeightLines = true,
    this.drawAsOval = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(bounds.center.dx * scale, bounds.center.dy * scale);
    final hw = bounds.halfWidth * scale;
    final hh = bounds.halfHeight * scale;
    final rect = Rect.fromCenter(center: c, width: hw * 2, height: hh * 2);
    final radius = Radius.circular((math.min(rect.width, rect.height) * 0.12).clamp(6.0, 28.0));

    final borderPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    if (drawAsOval) {
      canvas.drawOval(rect, borderPaint);
    } else {
      canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), borderPaint);
    }

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
      oldDelegate.bounds != bounds ||
      oldDelegate.scale != scale ||
      oldDelegate.drawAsOval != drawAsOval;
}
