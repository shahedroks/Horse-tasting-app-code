import 'package:ar_flutter_plugin/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin/models/ar_anchor.dart';
import 'package:ar_flutter_plugin/models/ar_hittest_result.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

import 'ar_measure_provider.dart';

/// Controller that owns AR session objects and measurement logic.
///
/// This implementation targets the official ar_flutter_plugin 0.7.x API, which
/// does not support primitive shapes or materials. It uses plane anchors only
/// and shows the measured distance in the Flutter overlay.
class ArMeasureController {
  final ArMeasureProvider provider;

  ARSessionManager? _sessionManager;
  ARObjectManager? _objectManager;
  ARAnchorManager? _anchorManager;

  ARAnchor? _firstAnchor;
  ARAnchor? _secondAnchor;

  ArMeasureController(this.provider);

  /// Called from ARView's onARViewCreated.
  Future<void> onARViewCreated(
    ARSessionManager sessionManager,
    ARObjectManager objectManager,
    ARAnchorManager anchorManager,
    ARLocationManager locationManager,
  ) async {
    _sessionManager = sessionManager;
    _objectManager = objectManager;
    _anchorManager = anchorManager;

    // Initialize the AR session and enable plane detection & tap handling.
    _sessionManager?.onInitialize(
      showPlanes: true,
      showFeaturePoints: false,
      handleTaps: true,
    );

    // Initialize object manager (needed for future node operations, if any).
    _objectManager?.onInitialize();

    provider.setPhase(ArMeasurePhase.scanning);

    _sessionManager?.onPlaneOrPointTap = _handleTapOnPlane;
  }

  Future<void> dispose() async {
    await clearAnchors();
    await _sessionManager?.dispose();
  }

  Future<void> _handleTapOnPlane(List<ARHitTestResult> hits) async {
    if (hits.isEmpty) return;
    final hit = hits.first;
    final position = hit.worldTransform.getColumn(3);
    final vm.Vector3 point = vm.Vector3(
      position.x,
      position.y,
      position.z,
    );

    if (provider.firstPoint == null) {
      await _placeFirstAnchor(hit);
      provider.setFirstPoint(point);
    } else if (provider.secondPoint == null) {
      await _placeSecondAnchor(hit);
      await _updateMeasurement();
    } else {
      // If already two points, treat as reset-then-first.
      await clearAnchors();
      provider.reset();
      await _placeFirstAnchor(hit);
      provider.setFirstPoint(point);
    }
  }

  Future<void> _placeFirstAnchor(ARHitTestResult hit) async {
    final anchor = ARPlaneAnchor(
      transformation: hit.worldTransform,
    );
    final added = await _anchorManager?.addAnchor(anchor);
    if (added != true) return;
    _firstAnchor = anchor;
  }

  Future<void> _placeSecondAnchor(ARHitTestResult hit) async {
    final anchor = ARPlaneAnchor(
      transformation: hit.worldTransform,
    );
    final added = await _anchorManager?.addAnchor(anchor);
    if (added != true) return;
    _secondAnchor = anchor;
  }

  Future<void> _updateMeasurement() async {
    if (_firstAnchor == null || _secondAnchor == null) return;

    // Use the anchor transforms to compute points in world space.
    final p1Col = _firstAnchor!.transformation.getColumn(3);
    final p2Col = _secondAnchor!.transformation.getColumn(3);
    final p1 = vm.Vector3(p1Col.x, p1Col.y, p1Col.z);
    final p2 = vm.Vector3(p2Col.x, p2Col.y, p2Col.z);

    final distanceMeters = p1.distanceTo(p2);

    provider.setSecondPointAndDistance(p2, distanceMeters);
  }

  Future<void> clearAnchors() async {
    if (_firstAnchor != null) {
      await _anchorManager?.removeAnchor(_firstAnchor!);
      _firstAnchor = null;
    }
    if (_secondAnchor != null) {
      await _anchorManager?.removeAnchor(_secondAnchor!);
      _secondAnchor = null;
    }
  }
}
