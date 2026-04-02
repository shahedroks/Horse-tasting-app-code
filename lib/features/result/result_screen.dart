import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/measurement_display.dart';
import '../../models/models.dart';
import '../../providers/measurement_flow_provider.dart';

/// Result: measured mm, best size, category, alternatives, quality warning.
class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final flow = context.watch<MeasurementFlowProvider>();
    final result = flow.measurementResult;
    final detectionResult = flow.detectionResult;
    final matched = flow.matchedSizes;
    final category = flow.selectedCategory ?? '';

    if (result == null && detectionResult == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Result')),
        body: const Center(child: Text('No measurement result')),
      );
    }

    final best = matched.isNotEmpty ? matched.first : null;
    final warning = flow.sizeMatchingService.betweenSizesWarning(matched);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Result'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Measurement', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    if (detectionResult != null) ...[
                      Builder(
                        builder: (context) {
                          final scale =
                              flow.scalePxPerMm ?? flow.calibrationService.current?.pixelsPerMm;
                          final wMm = displayMmFromPx(
                            detectionResult.widthPx,
                            scalePxPerMm: scale,
                          );
                          final hMm = displayMmFromPx(
                            detectionResult.heightPx,
                            scalePxPerMm: scale,
                          );
                          final calibrated = hasRealCalibration(scale);
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Width: ${wMm.toStringAsFixed(1)} mm',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              Text(
                                'Height: ${hMm.toStringAsFixed(1)} mm',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              if (calibrated)
                                Text(
                                  '(${detectionResult.widthPx.toStringAsFixed(0)} × ${detectionResult.heightPx.toStringAsFixed(0)} px)',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Theme.of(context).hintColor,
                                      ),
                                ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text('Confidence: '),
                          _ConfidenceChip(confidence: detectionResult.confidence),
                        ],
                      ),
                      if (result != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Text('Quality: '),
                            _QualityChip(quality: result.quality),
                          ],
                        ),
                      ],
                      if (detectionResult.warningMessage != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          detectionResult.warningMessage!,
                          style: TextStyle(color: Colors.orange.shade800, fontSize: 12),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Category', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(category),
                  ],
                ),
              ),
            ),
            if (best != null) ...[
              const SizedBox(height: 16),
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Best match', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('Size: ${best.entry.size}', style: Theme.of(context).textTheme.titleLarge),
                      Text('Chart: W ${best.entry.widthMm.toStringAsFixed(0)} mm, H-T ${best.entry.heelToeMm.toStringAsFixed(0)} mm'),
                      Text('Difference: W ${best.widthDiffMm.toStringAsFixed(1)} mm, H-T ${best.heelToeDiffMm.toStringAsFixed(1)} mm'),
                    ],
                  ),
                ),
              ),
            ],
            if (matched.length > 1) ...[
              const SizedBox(height: 16),
              const Text('Other nearest sizes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...matched.skip(1).take(2).map((m) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('Size ${m.entry.size}: W ${m.entry.widthMm.toStringAsFixed(0)} mm, H-T ${m.entry.heelToeMm.toStringAsFixed(0)} mm (Δ ${m.score.toStringAsFixed(1)})'),
              )),
            ],
            if (warning != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(warning, style: const TextStyle(color: Colors.black87)),
              ),
            ],
            if (result?.quality == MeasurementQuality.poor) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Measurement quality is poor. Consider retaking with better lighting and a clear reference in frame.',
                  style: TextStyle(color: Colors.black87),
                ),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                flow.resetCapture();
                Navigator.of(context).pushNamedAndRemoveUntil('/category', (r) => false);
              },
              child: const Text('New Measurement'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false),
              child: const Text('Back to Home'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfidenceChip extends StatelessWidget {
  final double confidence;

  const _ConfidenceChip({required this.confidence});

  @override
  Widget build(BuildContext context) {
    String label;
    Color color;
    if (confidence >= 0.7) {
      label = 'Good';
      color = Colors.green;
    } else if (confidence >= 0.4) {
      label = 'Medium';
      color = Colors.orange;
    } else {
      label = 'Poor';
      color = Colors.red;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
    );
  }
}

class _QualityChip extends StatelessWidget {
  final MeasurementQuality quality;

  const _QualityChip({required this.quality});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (quality) {
      case MeasurementQuality.good:
        color = Colors.green;
        break;
      case MeasurementQuality.medium:
        color = Colors.orange;
        break;
      case MeasurementQuality.poor:
        color = Colors.red;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(quality.displayName, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
    );
  }
}
