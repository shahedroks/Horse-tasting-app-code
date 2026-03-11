import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/measurement_flow_provider.dart';

/// Calibration settings: mode (reference vs fixed), reference type, fixed px/mm.
class CalibrationScreen extends StatefulWidget {
  const CalibrationScreen({super.key});

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen> {
  final _fixedPxPerMmController = TextEditingController();
  final _rulerSegmentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCurrent());
  }

  void _loadCurrent() {
    final flow = context.read<MeasurementFlowProvider>();
    final cal = flow.calibrationService.current;
    if (cal != null) {
      if (cal.pixelsPerMm != null) {
        _fixedPxPerMmController.text = cal.pixelsPerMm!.toStringAsFixed(2);
      }
      if (cal.rulerSegmentMm != null) {
        _rulerSegmentController.text = cal.rulerSegmentMm!.toStringAsFixed(1);
      }
    }
  }

  @override
  void dispose() {
    _fixedPxPerMmController.dispose();
    _rulerSegmentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final flow = context.watch<MeasurementFlowProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calibration Settings'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Measurement mode',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            RadioListTile<CalibrationMode>(
              title: const Text('Reference object (recommended)'),
              subtitle: const Text('Place a known-size object (e.g. credit card) in the same image'),
              value: CalibrationMode.referenceObject,
              groupValue: flow.calibrationMode,
              onChanged: (v) {
                if (v != null) flow.calibrationMode = v;
              },
            ),
            RadioListTile<CalibrationMode>(
              title: const Text('Fixed calibration'),
              subtitle: const Text('One-time calibration at fixed distance. Less accurate if distance changes.'),
              value: CalibrationMode.fixedCalibration,
              groupValue: flow.calibrationMode,
              onChanged: (v) {
                if (v != null) flow.calibrationMode = v;
              },
            ),
            const SizedBox(height: 24),
            if (flow.calibrationMode == CalibrationMode.referenceObject) ...[
              const Text('Reference type', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...ReferenceType.values.map((ref) => RadioListTile<ReferenceType>(
                    title: Text(ref.displayName),
                    value: ref,
                    groupValue: flow.referenceType ?? ReferenceType.creditCard,
                    onChanged: (v) {
                      if (v != null) flow.referenceType = v;
                    },
                  )),
              if (flow.referenceType == ReferenceType.ruler) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _rulerSegmentController,
                  decoration: const InputDecoration(
                    labelText: 'Ruler segment length (mm)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) {
                    flow.rulerSegmentMm = double.tryParse(v);
                  },
                ),
              ],
            ],
            if (flow.calibrationMode == CalibrationMode.fixedCalibration) ...[
              const Text(
                'Fixed calibration is less accurate. Use a reference object in the image when possible.',
                style: TextStyle(color: Colors.orange, fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _fixedPxPerMmController,
                decoration: const InputDecoration(
                  labelText: 'Pixels per mm (from previous calibration)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (v) {},
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  final pxPerMm = double.tryParse(_fixedPxPerMmController.text);
                  if (pxPerMm == null || pxPerMm <= 0) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Enter a valid pixels-per-mm value')),
                      );
                    }
                    return;
                  }
                  final cal = CalibrationData(
                    mode: CalibrationMode.fixedCalibration,
                    pixelsPerMm: pxPerMm,
                  );
                  await flow.calibrationService.save(cal);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Calibration saved')),
                    );
                  }
                },
                child: const Text('Save fixed calibration'),
              ),
            ],
            const SizedBox(height: 32),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Back'),
            ),
          ],
        ),
      ),
    );
  }
}
