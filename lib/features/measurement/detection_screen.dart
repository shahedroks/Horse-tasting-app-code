import 'dart:typed_data';
import 'dart:ui' show Offset;

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:provider/provider.dart';

import '../../constants/measurement_display.dart';
import '../../models/models.dart';
import '../../models/detection_result.dart';
import '../../models/detection_method.dart';
import '../../providers/measurement_flow_provider.dart';

/// Detection and measurement: overlay on image, manual adjustment, show px and mm.
class DetectionScreen extends StatefulWidget {
  const DetectionScreen({super.key});

  @override
  State<DetectionScreen> createState() => _DetectionScreenState();
}

class _DetectionScreenState extends State<DetectionScreen> {
  bool _loading = true;
  String? _error;
  ObjectBounds? _bounds;
  int _imageWidth = 0;
  int _imageHeight = 0;
  double? _scalePxPerMm;
  ReferenceCorners? _refCorners;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runDetection());
  }

  Future<void> _runDetection() async {
    final flow = context.read<MeasurementFlowProvider>();
    final bytes = flow.capturedImageBytes;
    if (bytes == null) {
      setState(() {
        _loading = false;
        _error = 'No image';
      });
      return;
    }
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      setState(() {
        _loading = false;
        _error = 'Failed to decode image';
      });
      return;
    }
    final w = decoded.width;
    final h = decoded.height;
    flow.setCapturedImageSize(w, h);

    ObjectBounds? bounds = await flow.measurementService.detectObject(bytes);
    if (bounds == null) {
      bounds = ObjectBounds(
        center: Offset(w / 2.0, h / 2.0),
        halfWidth: w * 0.2,
        halfHeight: h * 0.2,
      );
    }
    double? scale = flow.scalePxPerMm;
    if (scale == null && flow.calibrationMode == CalibrationMode.referenceObject && flow.referenceType != null) {
      _refCorners = flow.referenceCorners;
      if (_refCorners == null) {
        const margin = 0.15;
        final iw = w.toDouble();
        final ih = h.toDouble();
        _refCorners = ReferenceCorners(
          topLeft: Offset(iw * margin, ih * margin),
          topRight: Offset(iw * (1 - margin), ih * margin),
          bottomRight: Offset(iw * (1 - margin), ih * (1 - margin)),
          bottomLeft: Offset(iw * margin, ih * (1 - margin)),
        );
      }
      if (_refCorners != null) {
        final ref = flow.referenceType!;
        final refW = ref == ReferenceType.ruler && flow.rulerSegmentMm != null ? flow.rulerSegmentMm! : ref.widthMm;
        final refH = ref == ReferenceType.ruler && flow.rulerSegmentMm != null ? flow.rulerSegmentMm! : ref.heightMm;
        scale = flow.calibrationService.computeScaleFromReference(
          referenceCorners: _refCorners!,
          referenceWidthMm: refW,
          referenceHeightMm: refH,
        );
      }
    }
    if (scale == null) {
      scale = flow.calibrationService.current?.pixelsPerMm;
    }

    if (!mounted) return;
    setState(() {
      _imageWidth = w;
      _imageHeight = h;
      _bounds = bounds;
      _scalePxPerMm = scale;
      _loading = false;
    });
  }

  void _updateBounds(ObjectBounds b) {
    setState(() => _bounds = b);
  }

  void _onConfirm() {
    final flow = context.read<MeasurementFlowProvider>();
    if (_bounds == null) return;
    flow.objectBounds = _bounds;
    flow.scalePxPerMm = _scalePxPerMm;
    flow.referenceCorners = _refCorners;

    final hasCal = hasRealCalibration(_scalePxPerMm);
    final widthMm = displayMmFromPx(_bounds!.widthPx, scalePxPerMm: _scalePxPerMm);
    final heightMm = displayMmFromPx(_bounds!.heightPx, scalePxPerMm: _scalePxPerMm);

    final result = flow.measurementService.toMeasurementResult(
          objectBounds: _bounds!,
          scalePxPerMm: _scalePxPerMm,
          quality: flow.measurementService.evaluateQuality(_bounds!, _imageWidth, _imageHeight),
        ) ??
        MeasurementResult(
          widthMm: widthMm,
          heightMm: heightMm,
          widthPx: _bounds!.widthPx,
          heightPx: _bounds!.heightPx,
          quality: flow.measurementService.evaluateQuality(_bounds!, _imageWidth, _imageHeight),
        );
    flow.measurementResult = result;

    flow.detectionResult = DetectionResult(
      widthPx: _bounds!.widthPx,
      heightPx: _bounds!.heightPx,
      widthMm: widthMm,
      heightMm: heightMm,
      centerX: _bounds!.center.dx,
      centerY: _bounds!.center.dy,
      angle: _bounds!.angle,
      confidence: 0.5,
      detectionMethod: DetectionMethod.manual,
      hasCalibration: hasCal,
      warningMessage: null,
    );

    final category = flow.selectedCategory;
    final chart = flow.sizeChartService.chart;
    if (category != null && chart != null) {
      final entries = chart.entriesFor(category);
      if (entries != null && entries.isNotEmpty) {
        flow.matchedSizes = flow.sizeMatchingService.findNearest(
          entries: entries,
          widthMm: result.widthMm,
          heelToeMm: result.heightMm,
          topN: 3,
        );
      } else {
        flow.matchedSizes = [];
      }
    } else {
      flow.matchedSizes = [];
    }
    Navigator.of(context).pushReplacementNamed('/result');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detection')),
        body: Center(child: Text(_error!)),
      );
    }
    final flow = context.read<MeasurementFlowProvider>();
    final bytes = flow.capturedImageBytes!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Adjust Measurement'),
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
                return _MeasurementOverlay(
                  imageBytes: bytes,
                  imageWidth: _imageWidth,
                  imageHeight: _imageHeight,
                  bounds: _bounds!,
                  onBoundsChanged: _updateBounds,
                  referenceCorners: _refCorners,
                );
              },
            ),
          ),
          _InfoPanel(
            bounds: _bounds!,
            scalePxPerMm: _scalePxPerMm,
            onConfirm: _onConfirm,
          ),
        ],
      ),
    );
  }
}

class _MeasurementOverlay extends StatefulWidget {
  final Uint8List imageBytes;
  final int imageWidth;
  final int imageHeight;
  final ObjectBounds bounds;
  final ValueChanged<ObjectBounds> onBoundsChanged;
  final ReferenceCorners? referenceCorners;

  const _MeasurementOverlay({
    required this.imageBytes,
    required this.imageWidth,
    required this.imageHeight,
    required this.bounds,
    required this.onBoundsChanged,
    this.referenceCorners,
  });

  @override
  State<_MeasurementOverlay> createState() => _MeasurementOverlayState();
}

class _MeasurementOverlayState extends State<_MeasurementOverlay> {
  late ObjectBounds _bounds;
  int _dragHandle = -1;

  @override
  void initState() {
    super.initState();
    _bounds = widget.bounds;
  }

  @override
  void didUpdateWidget(covariant _MeasurementOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bounds != widget.bounds) _bounds = widget.bounds;
  }

  void _onPanStart(DragStartDetails d, int handle) {
    setState(() => _dragHandle = handle);
  }

  void _onPanUpdate(DragUpdateDetails d) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(d.globalPosition);
    double dx = local.dx, dy = local.dy;
    final scale = _scaleToLayout();
    dx = dx / scale.dx;
    dy = dy / scale.dy;
    setState(() {
      switch (_dragHandle) {
        case 0:
          _bounds = _bounds.copyWith(halfWidth: (_bounds.center.dx - dx).clamp(5.0, double.infinity));
          break;
        case 1:
          _bounds = _bounds.copyWith(halfHeight: (_bounds.center.dy - dy).clamp(5.0, double.infinity));
          break;
        case 2:
          _bounds = _bounds.copyWith(halfWidth: (dx - _bounds.center.dx).clamp(5.0, double.infinity));
          break;
        case 3:
          _bounds = _bounds.copyWith(halfHeight: (dy - _bounds.center.dy).clamp(5.0, double.infinity));
          break;
        case 4:
          _bounds = _bounds.copyWith(center: Offset(dx, dy));
          break;
      }
      widget.onBoundsChanged(_bounds);
    });
  }

  void _onPanEnd(DragEndDetails d) {
    setState(() => _dragHandle = -1);
  }

  Offset _scaleToLayout() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return const Offset(1, 1);
    final w = box.size.width;
    final h = box.size.height;
    if (widget.imageWidth <= 0 || widget.imageHeight <= 0) return const Offset(1, 1);
    return Offset(w / widget.imageWidth, h / widget.imageHeight);
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 4,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scale = (widget.imageWidth > 0 && widget.imageHeight > 0)
              ? _scaleForFit(constraints.biggest, widget.imageWidth, widget.imageHeight)
              : 1.0;
          final displayW = widget.imageWidth * scale;
          final displayH = widget.imageHeight * scale;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              SizedBox(
                width: displayW,
                height: displayH,
                child: Image.memory(
                  widget.imageBytes,
                  fit: BoxFit.contain,
                  width: displayW,
                  height: displayH,
                ),
              ),
              Positioned(
                left: 0,
                top: 0,
                width: displayW,
                height: displayH,
                child: CustomPaint(
                  painter: _OverlayPainter(
                    bounds: _bounds,
                    scale: scale,
                    referenceCorners: widget.referenceCorners,
                  ),
                  size: Size(displayW, displayH),
                ),
              ),
              _buildHandles(scale, displayW, displayH),
            ],
          );
        },
      ),
    );
  }

  double _scaleForFit(Size layout, int iw, int ih) {
    final scaleW = layout.width / iw;
    final scaleH = layout.height / ih;
    return scaleW < scaleH ? scaleW : scaleH;
  }

  Widget _buildHandles(double scale, double displayW, double displayH) {
    final c = Offset(_bounds.center.dx * scale, _bounds.center.dy * scale);
    final hw = _bounds.halfWidth * scale;
    final hh = _bounds.halfHeight * scale;
    const size = 24.0;
    return Stack(
      children: [
        Positioned(left: c.dx - size / 2, top: c.dy - size / 2, child: _handle(4, c.dx, c.dy)),
        Positioned(left: c.dx - hw - size / 2, top: c.dy - size / 2, child: _handle(0, c.dx - hw, c.dy)),
        Positioned(left: c.dx - size / 2, top: c.dy - hh - size / 2, child: _handle(1, c.dx, c.dy - hh)),
        Positioned(left: c.dx + hw - size / 2, top: c.dy - size / 2, child: _handle(2, c.dx + hw, c.dy)),
        Positioned(left: c.dx - size / 2, top: c.dy + hh - size / 2, child: _handle(3, c.dx, c.dy + hh)),
      ],
    );
  }

  Widget _handle(int id, double x, double y) {
    return GestureDetector(
      onPanStart: (d) => _onPanStart(d, id),
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.8),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
      ),
    );
  }
}

class _OverlayPainter extends CustomPainter {
  final ObjectBounds bounds;
  final double scale;
  final ReferenceCorners? referenceCorners;

  _OverlayPainter({
    required this.bounds,
    required this.scale,
    this.referenceCorners,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(bounds.center.dx * scale, bounds.center.dy * scale);
    final hw = bounds.halfWidth * scale;
    final hh = bounds.halfHeight * scale;
    final paint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(Rect.fromCenter(center: c, width: hw * 2, height: hh * 2), paint);
    if (referenceCorners != null) {
      final refPaint = Paint()
        ..color = Colors.orange
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      final list = referenceCorners!.list;
      for (int i = 0; i < list.length; i++) {
        final p = list[i];
        final next = list[(i + 1) % list.length];
        canvas.drawLine(
          Offset(p.dx * scale, p.dy * scale),
          Offset(next.dx * scale, next.dy * scale),
          refPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _OverlayPainter oldDelegate) =>
      oldDelegate.bounds != bounds || oldDelegate.referenceCorners != referenceCorners;
}

class _InfoPanel extends StatelessWidget {
  final ObjectBounds bounds;
  final double? scalePxPerMm;
  final VoidCallback onConfirm;

  const _InfoPanel({
    required this.bounds,
    required this.scalePxPerMm,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final widthMm = displayMmFromPx(bounds.widthPx, scalePxPerMm: scalePxPerMm);
    final heightMm = displayMmFromPx(bounds.heightPx, scalePxPerMm: scalePxPerMm);
    final calibrated = hasRealCalibration(scalePxPerMm);
    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Width: ${widthMm.toStringAsFixed(1)} mm',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Text(
            'Height: ${heightMm.toStringAsFixed(1)} mm',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          if (calibrated)
            Text(
              '(${bounds.widthPx.toStringAsFixed(0)} × ${bounds.heightPx.toStringAsFixed(0)} px)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor),
            ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: onConfirm,
            child: const Text('Confirm & Get Size'),
          ),
        ],
      ),
    );
  }
}
