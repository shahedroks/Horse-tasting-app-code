import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/measurement_flow_provider.dart';

/// Camera capture: live preview, guide overlay, capture and retake.
class CameraCaptureScreen extends StatefulWidget {
  const CameraCaptureScreen({super.key});

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen> {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _initialized = false;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() => _error = 'No camera found');
        return;
      }
      final back = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );
      _controller = CameraController(
        back,
        ResolutionPreset.medium,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await _controller!.initialize();
      if (!mounted) return;
      setState(() => _initialized = true);
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    if (_busy) return;
    if (_controller == null || !_controller!.value.isInitialized) return;
    try {
      setState(() => _busy = true);
      final XFile file = await _controller!.takePicture();
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      final flow = context.read<MeasurementFlowProvider>();
      flow.capturedImageBytes = bytes;
      flow.setCapturedImageSize(0, 0);
      Navigator.of(context).pushReplacementNamed('/processing');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Capture failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Camera')),
        body: Center(child: Text(_error!)),
      );
    }
    if (!_initialized || _controller == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Capture Photo'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildPreview(),
          _buildGuideOverlay(),
          Positioned(
            left: 0,
            right: 0,
            bottom: 32,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _busy ? null : _capture,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Capture'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    final controller = _controller!;
    final size = controller.value.previewSize;
    if (size == null) return CameraPreview(controller);

    // Always preserve aspect ratio to avoid "stretched / long" objects.
    // Use a cover-fit so the preview fills the screen while keeping geometry correct.
    return Center(
      child: ClipRect(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: size.height,
            height: size.width,
            child: CameraPreview(controller),
          ),
        ),
      ),
    );
  }

  Widget _buildGuideOverlay() {
    return IgnorePointer(
      child: CustomPaint(
        painter: _GuideFramePainter(),
        size: Size.infinite,
      ),
    );
  }
}

/// Simple rectangular guide frame overlay.
class _GuideFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const margin = 40.0;
    final rect = Rect.fromLTRB(margin, margin, size.width - margin, size.height - margin);
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
