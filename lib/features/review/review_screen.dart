import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/measurement_display.dart';
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
  bool _ovalBorder = false;

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
                          drawAsOval: _ovalBorder,
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
            scalePxPerMm: flow.scalePxPerMm ?? flow.calibrationService.current?.pixelsPerMm,
            arCameraToSubjectMeters: flow.arCameraToSubjectMeters,
            arHorizontalFovDeg: flow.arHorizontalFovDeg,
            ovalBorder: _ovalBorder,
            onToggleOvalBorder: (v) => setState(() => _ovalBorder = v),
            onManualAdjust: () => Navigator.of(context).pushNamed('/detection').then((_) => setState(() {})),
            onRecalculate: () => Navigator.of(context).pushReplacementNamed('/processing'),
            onArDistance: w > 0
                ? () async {
                    await Navigator.of(context).pushNamed('/ar_distance');
                    if (context.mounted) setState(() {});
                  }
                : null,
            onConfirm: () => _confirm(flow),
          ),
        ],
      ),
    );
  }

  void _confirm(MeasurementFlowProvider flow) {
    final bounds = flow.objectBounds!;
    final scalePxPerMm = flow.scalePxPerMm ?? flow.calibrationService.current?.pixelsPerMm;
    final iw = flow.capturedImageWidth;
    final ar = flow.arCameraToSubjectMeters;
    final fov = flow.arHorizontalFovDeg;
    final hasPhysical = hasMetricScale(scalePxPerMm, ar);
    final widthMm = displayMmFromPx(
      bounds.widthPx,
      scalePxPerMm: scalePxPerMm,
      arCameraToSubjectMeters: ar,
      imageWidth: iw > 0 ? iw : null,
      arHorizontalFovDeg: fov,
    );
    final heightMm = displayMmFromPx(
      bounds.heightPx,
      scalePxPerMm: scalePxPerMm,
      arCameraToSubjectMeters: ar,
      imageWidth: iw > 0 ? iw : null,
      arHorizontalFovDeg: fov,
    );

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
      hasCalibration: hasPhysical,
      warningMessage: null,
    );

    flow.measurementResult = MeasurementResult(
      widthMm: widthMm,
      heightMm: heightMm,
      widthPx: bounds.widthPx,
      heightPx: bounds.heightPx,
      quality: _confidenceToQuality(flow.detectionResult?.confidence ?? 0.5),
    );
    if (hasPhysical) {
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
        } else {
          flow.matchedSizes = [];
        }
      } else {
        flow.matchedSizes = [];
      }
    } else {
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
  /// Live scale from flow + saved calibration so mm updates after manual adjust.
  final double? scalePxPerMm;
  final double? arCameraToSubjectMeters;
  final double arHorizontalFovDeg;
  final bool ovalBorder;
  final ValueChanged<bool> onToggleOvalBorder;
  final VoidCallback onManualAdjust;
  final VoidCallback onRecalculate;
  final VoidCallback? onArDistance;
  final VoidCallback onConfirm;

  const _ReviewPanel({
    required this.result,
    required this.bounds,
    required this.imageWidth,
    required this.scalePxPerMm,
    required this.arCameraToSubjectMeters,
    required this.arHorizontalFovDeg,
    required this.ovalBorder,
    required this.onToggleOvalBorder,
    required this.onManualAdjust,
    required this.onRecalculate,
    required this.onArDistance,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final widthPx = bounds.widthPx;
    final heightPx = bounds.heightPx;
    final widthMm = displayMmFromPx(
      widthPx,
      scalePxPerMm: scalePxPerMm,
      arCameraToSubjectMeters: arCameraToSubjectMeters,
      imageWidth: imageWidth > 0 ? imageWidth : null,
      arHorizontalFovDeg: arHorizontalFovDeg,
    );
    final heightMm = displayMmFromPx(
      heightPx,
      scalePxPerMm: scalePxPerMm,
      arCameraToSubjectMeters: arCameraToSubjectMeters,
      imageWidth: imageWidth > 0 ? imageWidth : null,
      arHorizontalFovDeg: arHorizontalFovDeg,
    );
    final showMetricCaption =
        hasMetricScale(scalePxPerMm, arCameraToSubjectMeters);
    final captionStyle = Theme.of(context).textTheme.bodySmall;

    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (result != null) ...[
            Text('Detection: ${result!.detectionMethod.displayName}'),
            const SizedBox(height: 4),
          ],
          Row(
            children: [
              const Text('Oval border'),
              const Spacer(),
              Switch(
                value: ovalBorder,
                onChanged: onToggleOvalBorder,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Object width: ${widthMm.toStringAsFixed(1)} mm',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          Text(
            'Object height: ${heightMm.toStringAsFixed(1)} mm',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          if (arCameraToSubjectMeters != null && arCameraToSubjectMeters! > 0)
            Text(
              'AR distance ≈ ${(arCameraToSubjectMeters! * 100).toStringAsFixed(0)} cm',
              style: captionStyle?.copyWith(color: Theme.of(context).hintColor),
            ),
          if (showMetricCaption)
            Text(
              '${widthPx.toStringAsFixed(0)} × ${heightPx.toStringAsFixed(0)} px on image',
              style: captionStyle?.copyWith(color: Theme.of(context).hintColor),
            ),
          const SizedBox(height: 12),
          if (onArDistance != null)
            OutlinedButton.icon(
              onPressed: onArDistance,
              icon: const Icon(Icons.view_in_ar),
              label: const Text('AR distance (for mm)'),
            ),
          if (onArDistance != null) const SizedBox(height: 8),
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
