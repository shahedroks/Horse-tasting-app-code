import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:provider/provider.dart';

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

    final output = await flow.borderDetectionService.detect(cropped);
    if (!mounted) return;

    if (output != null) {
      flow.objectBounds = output.bounds;
      final scalePxPerMm = flow.scalePxPerMm ?? flow.calibrationService.current?.pixelsPerMm;
      final hasCalibration = scalePxPerMm != null && scalePxPerMm > 0;
      final widthMm = hasCalibration ? output.bounds.widthPx / scalePxPerMm : null;
      final heightMm = hasCalibration ? output.bounds.heightPx / scalePxPerMm : null;
      flow.detectionResult = DetectionResult(
        widthPx: output.bounds.widthPx,
        heightPx: output.bounds.heightPx,
        widthMm: widthMm,
        heightMm: heightMm,
        centerX: output.bounds.center.dx,
        centerY: output.bounds.center.dy,
        angle: output.bounds.angle,
        confidence: output.confidence,
        detectionMethod: DetectionMethod.auto,
        hasCalibration: hasCalibration,
        warningMessage: hasCalibration ? null : DetectionResult.noCalibrationWarning,
      );
    } else {
      final w = flow.capturedImageWidth > 0 ? flow.capturedImageWidth : 1;
      final h = flow.capturedImageHeight > 0 ? flow.capturedImageHeight : 1;
      flow.objectBounds = ObjectBounds(
        center: Offset(w / 2.0, h / 2.0),
        halfWidth: w * 0.2,
        halfHeight: h * 0.2,
      );
      flow.detectionResult = DetectionResult(
        widthPx: w * 0.4,
        heightPx: h * 0.4,
        centerX: w / 2.0,
        centerY: h / 2.0,
        confidence: 0,
        detectionMethod: DetectionMethod.auto,
        hasCalibration: flow.calibrationService.current?.pixelsPerMm != null,
        warningMessage: DetectionResult.noCalibrationWarning,
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
