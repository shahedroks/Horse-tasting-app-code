import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:provider/provider.dart';

import '../../constants/measurement_display.dart';
import '../../models/detection_result.dart';
import '../../models/detection_method.dart';
import '../../models/object_bounds.dart';
import '../../providers/measurement_flow_provider.dart';
import '../../services/image_processing_service.dart';

/// Processing: "Detecting object border..." then crop + detect and navigate to review.
class ProcessingScreen extends StatefulWidget {
  const ProcessingScreen({super.key});

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runDetection());
  }

  Future<void> _runDetection() async {
    final flow = context.read<MeasurementFlowProvider>();
    final bytes = flow.capturedImageBytes;
    if (bytes == null) {
      if (mounted) Navigator.of(context).pop();
      return;
    }

    final cropped = await ImageProcessingService.cropToGuide(bytes, marginFraction: 0.1);
    if (cropped == null || !mounted) {
      if (mounted) Navigator.of(context).pushReplacementNamed('/review');
      return;
    }

    flow.capturedImageBytes = cropped;
    final decoded = img.decodeImage(cropped);
    if (decoded != null && mounted) {
      flow.setCapturedImageSize(decoded.width, decoded.height);
    }

    final detailed = await flow.measurementService.detectObjectDetailed(cropped);
    if (!mounted) return;

    if (detailed != null) {
      flow.objectBounds = detailed.bounds;
      final scalePxPerMm = flow.scalePxPerMm ?? flow.calibrationService.current?.pixelsPerMm;
      final iw = flow.capturedImageWidth;
      final ar = flow.arCameraToSubjectMeters;
      final hasCalibration = hasMetricScale(scalePxPerMm, ar);
      final widthMm = displayMmFromPx(
        detailed.bounds.widthPx,
        scalePxPerMm: scalePxPerMm,
        arCameraToSubjectMeters: ar,
        imageWidth: iw > 0 ? iw : null,
        arHorizontalFovDeg: flow.arHorizontalFovDeg,
      );
      final heightMm = displayMmFromPx(
        detailed.bounds.heightPx,
        scalePxPerMm: scalePxPerMm,
        arCameraToSubjectMeters: ar,
        imageWidth: iw > 0 ? iw : null,
        arHorizontalFovDeg: flow.arHorizontalFovDeg,
      );
      flow.detectionResult = DetectionResult(
        widthPx: detailed.bounds.widthPx,
        heightPx: detailed.bounds.heightPx,
        widthMm: widthMm,
        heightMm: heightMm,
        centerX: detailed.bounds.center.dx,
        centerY: detailed.bounds.center.dy,
        angle: detailed.bounds.angle,
        confidence: detailed.confidence,
        detectionMethod: detailed.method,
        hasCalibration: hasCalibration,
        warningMessage: null,
      );
    } else {
      final w = flow.capturedImageWidth > 0 ? flow.capturedImageWidth : 1;
      final h = flow.capturedImageHeight > 0 ? flow.capturedImageHeight : 1;
      flow.objectBounds = ObjectBounds(
        center: Offset(w / 2.0, h / 2.0),
        halfWidth: w * 0.2,
        halfHeight: h * 0.2,
      );
      final scalePxPerMmFallback =
          flow.scalePxPerMm ?? flow.calibrationService.current?.pixelsPerMm;
      final arFb = flow.arCameraToSubjectMeters;
      final hasCalibrationFallback = hasMetricScale(scalePxPerMmFallback, arFb);
      final bw = w * 0.4;
      final bh = h * 0.4;
      flow.detectionResult = DetectionResult(
        widthPx: bw,
        heightPx: bh,
        widthMm: displayMmFromPx(
          bw,
          scalePxPerMm: scalePxPerMmFallback,
          arCameraToSubjectMeters: arFb,
          imageWidth: w > 0 ? w : null,
          arHorizontalFovDeg: flow.arHorizontalFovDeg,
        ),
        heightMm: displayMmFromPx(
          bh,
          scalePxPerMm: scalePxPerMmFallback,
          arCameraToSubjectMeters: arFb,
          imageWidth: w > 0 ? w : null,
          arHorizontalFovDeg: flow.arHorizontalFovDeg,
        ),
        centerX: w / 2.0,
        centerY: h / 2.0,
        confidence: 0,
        detectionMethod: DetectionMethod.manual,
        hasCalibration: hasCalibrationFallback,
        warningMessage: null,
      );
    }

    if (mounted) Navigator.of(context).pushReplacementNamed('/review');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Processing'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 24),
            Text('Detecting object border...'),
          ],
        ),
      ),
    );
  }
}
