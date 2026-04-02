import 'package:ar_flutter_plugin/datatypes/config_planedetection.dart';
import 'package:ar_flutter_plugin/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin/widgets/ar_view.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/measurement_flow_provider.dart';

/// One tap on a tracked plane: saves [ARHitTestResult.distance] (camera → hit, meters)
/// into [MeasurementFlowProvider.arCameraToSubjectMeters] for mm conversion on the photo.
class ArDistanceCaptureScreen extends StatefulWidget {
  const ArDistanceCaptureScreen({super.key});

  @override
  State<ArDistanceCaptureScreen> createState() => _ArDistanceCaptureScreenState();
}

class _ArDistanceCaptureScreenState extends State<ArDistanceCaptureScreen> {
  ARSessionManager? _sessionManager;

  Future<void> _onARViewCreated(
    ARSessionManager sessionManager,
    ARObjectManager objectManager,
    ARAnchorManager anchorManager,
    ARLocationManager locationManager,
  ) async {
    _sessionManager = sessionManager;
    sessionManager.onInitialize(
      showPlanes: true,
      showFeaturePoints: false,
      handleTaps: true,
    );
    objectManager.onInitialize();

    sessionManager.onPlaneOrPointTap = (hits) {
      if (!mounted || hits.isEmpty) return;
      final d = hits.first.distance;
      if (d > 0 && d < 80) {
        context.read<MeasurementFlowProvider>().arCameraToSubjectMeters = d;
        Navigator.of(context).pop(true);
      }
    };
  }

  @override
  void dispose() {
    _sessionManager?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AR distance'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          ARView(
            planeDetectionConfig: PlaneDetectionConfig.horizontalAndVertical,
            onARViewCreated: _onARViewCreated,
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Material(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.92),
                elevation: 6,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Stand like when you took the photo. Tap the floor/surface under the object.',
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Uses camera→surface distance + pinhole math for mm (approximate).',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).hintColor,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
