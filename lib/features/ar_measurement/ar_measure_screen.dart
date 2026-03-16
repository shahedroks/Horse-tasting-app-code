import 'package:ar_flutter_plugin/datatypes/config_planedetection.dart';
import 'package:ar_flutter_plugin/widgets/ar_view.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'ar_measure_controller.dart';
import 'ar_measure_overlay.dart';
import 'ar_measure_provider.dart';

class ArMeasureScreen extends StatefulWidget {
  const ArMeasureScreen({super.key});

  @override
  State<ArMeasureScreen> createState() => _ArMeasureScreenState();
}

class _ArMeasureScreenState extends State<ArMeasureScreen> {
  late ArMeasureController _controller;

  @override
  void initState() {
    super.initState();
    final provider = context.read<ArMeasureProvider>();
    _controller = ArMeasureController(provider);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AR Measure'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          ARView(
            planeDetectionConfig: PlaneDetectionConfig.horizontalAndVertical,
            onARViewCreated: (arSessionManager, arObjectManager,
                arAnchorManager, arLocationManager) {
              _controller.onARViewCreated(
                arSessionManager,
                arObjectManager,
                arAnchorManager,
                arLocationManager,
              );
            },
          ),
          const ArMeasureOverlay(),
        ],
      ),
    );
  }
}

