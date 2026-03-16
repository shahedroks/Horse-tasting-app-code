import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/detection_result.dart';
import '../../models/detection_method.dart';
import '../../models/object_bounds.dart';
import '../../models/measurement_quality.dart';
import '../../models/measurement_result.dart';
import '../../providers/measurement_flow_provider.dart';
import '../../widgets/measurement_overlay_painter.dart';

/// Review: show image, border overlay, width/height (px and mm if calibration), manual adjust, recalculate, confirm.
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    final flow = context.watch<MeasurementFlowProvider>();
    final bytes = flow.capturedImageBytes;
    final bounds = flow.objectBounds;
    final result = flow.detectionResult;
    final w = flow.capturedImageWidth;
    final h = flow.capturedImageHeight;

    if (bytes == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Review')),
        body: const Center(child: Text('No image')),
      );
    }

    if (bounds == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Review')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pushReplacementNamed('/camera'),
            child: const Text('Retake'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (w <= 0 || h <= 0) return const SizedBox();
                _scale = (constraints.biggest.width / w).clamp(0.1, 5.0);
                if (constraints.biggest.height / h < _scale) {
                  _scale = constraints.biggest.height / h;
                }
                final displayW = w * _scale;
                final displayH = h * _scale;
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    Center(
                      child: SizedBox(
                        width: displayW,
                        height: displayH,
                        child: Image.memory(
                          bytes,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    Positioned(
                      width: displayW,
                      height: displayH,
                      child: CustomPaint(
                        painter: MeasurementOverlayPainter(
                          bounds: bounds,
                          scale: _scale,
                          showWidthHeightLines: true,
                        ),
                        size: Size(displayW, displayH),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          _ReviewPanel(
            result: result,
            bounds: bounds,
            imageWidth: w,
            imageHeight: h,
            onManualAdjust: () => Navigator.of(context).pushNamed('/detection').then((_) => setState(() {})),
            onRecalculate: () => Navigator.of(context).pushReplacementNamed('/processing'),
            onConfirm: () => _confirm(flow),
          ),
        ],
      ),
    );
  }

  void _confirm(MeasurementFlowProvider flow) {
    final bounds = flow.objectBounds!;
    final scalePxPerMm = flow.scalePxPerMm ?? flow.calibrationService.current?.pixelsPerMm;
    final hasCalibration = scalePxPerMm != null && scalePxPerMm > 0;
    final widthMm = hasCalibration ? bounds.widthPx / scalePxPerMm : null;
    final heightMm = hasCalibration ? bounds.heightPx / scalePxPerMm : null;

    flow.detectionResult = DetectionResult(
      widthPx: bounds.widthPx,
      heightPx: bounds.heightPx,
      widthMm: widthMm,
      heightMm: heightMm,
      centerX: bounds.center.dx,
      centerY: bounds.center.dy,
      angle: bounds.angle,
      confidence: flow.detectionResult?.confidence ?? 0.5,
      detectionMethod: flow.detectionResult?.detectionMethod ?? DetectionMethod.manual,
      hasCalibration: hasCalibration,
      warningMessage: hasCalibration ? null : DetectionResult.noCalibrationWarning,
    );

    if (hasCalibration && widthMm != null && heightMm != null) {
      flow.measurementResult = MeasurementResult(
        widthMm: widthMm,
        heightMm: heightMm,
        widthPx: bounds.widthPx,
        heightPx: bounds.heightPx,
        quality: _confidenceToQuality(flow.detectionResult?.confidence ?? 0.5),
      );
      final category = flow.selectedCategory;
      final chart = flow.sizeChartService.chart;
      if (category != null && chart != null) {
        final entries = chart.entriesFor(category);
        if (entries != null && entries.isNotEmpty) {
          flow.matchedSizes = flow.sizeMatchingService.findNearest(
            entries: entries,
            widthMm: widthMm,
            heelToeMm: heightMm,
            topN: 3,
          );
        }
      }
    } else {
      flow.measurementResult = null;
      flow.matchedSizes = [];
    }

    Navigator.of(context).pushReplacementNamed('/result');
  }

  MeasurementQuality _confidenceToQuality(double c) {
    if (c >= 0.7) return MeasurementQuality.good;
    if (c >= 0.4) return MeasurementQuality.medium;
    return MeasurementQuality.poor;
  }
}

class _ReviewPanel extends StatelessWidget {
  final DetectionResult? result;
  final ObjectBounds bounds;
  final int imageWidth;
  final int imageHeight;
  final VoidCallback onManualAdjust;
  final VoidCallback onRecalculate;
  final VoidCallback onConfirm;

  const _ReviewPanel({
    required this.result,
    required this.bounds,
    required this.imageWidth,
    required this.imageHeight,
    required this.onManualAdjust,
    required this.onRecalculate,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final widthPx = bounds.widthPx;
    final heightPx = bounds.heightPx;
    final widthMm = result?.widthMm;
    final heightMm = result?.heightMm;
    final hasCalibration = result?.hasCalibration ?? false;
    final widthCm = widthMm != null ? widthMm / 10.0 : null;
    final heightCm = heightMm != null ? heightMm / 10.0 : null;

    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Image Size: ${imageWidth} × ${imageHeight} px'),
          const SizedBox(height: 4),
          Text('Object Width: ${widthPx.toStringAsFixed(0)} px'),
          Text('Object Height: ${heightPx.toStringAsFixed(0)} px'),
          if (hasCalibration && widthMm != null && heightMm != null) ...[
            const SizedBox(height: 4),
            Text('Converted Width: ${widthCm!.toStringAsFixed(2)} cm (${widthMm.toStringAsFixed(1)} mm)'),
            Text('Converted Height: ${heightCm!.toStringAsFixed(2)} cm (${heightMm.toStringAsFixed(1)} mm)'),
          ] else ...[
            const SizedBox(height: 4),
            Text(
              DetectionResult.noCalibrationWarning,
              style: TextStyle(color: Colors.orange.shade800, fontSize: 12),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton(
                onPressed: onManualAdjust,
                child: const Text('Manual adjust'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: onRecalculate,
                child: const Text('Recalculate'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: onConfirm,
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}
