import 'package:flutter/foundation.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

/// High-level measurement states for the AR flow.
enum ArMeasurePhase {
  initializing,
  scanning,
  waitingFirstPoint,
  waitingSecondPoint,
  measured,
}

class ArMeasureProvider extends ChangeNotifier {
  ArMeasurePhase _phase = ArMeasurePhase.initializing;
  vm.Vector3? _firstPoint;
  vm.Vector3? _secondPoint;
  double? _distanceMeters;

  ArMeasurePhase get phase => _phase;
  vm.Vector3? get firstPoint => _firstPoint;
  vm.Vector3? get secondPoint => _secondPoint;
  double? get distanceMeters => _distanceMeters;

  double? get distanceCm =>
      _distanceMeters != null ? _distanceMeters! * 100.0 : null;

  double? get distanceInches =>
      _distanceMeters != null ? _distanceMeters! * 39.3701 : null;

  void setPhase(ArMeasurePhase value) {
    if (_phase == value) return;
    _phase = value;
    notifyListeners();
  }

  void setFirstPoint(vm.Vector3 p) {
    _firstPoint = p;
    _secondPoint = null;
    _distanceMeters = null;
    _phase = ArMeasurePhase.waitingSecondPoint;
    notifyListeners();
  }

  void setSecondPointAndDistance(vm.Vector3 p2, double meters) {
    _secondPoint = p2;
    _distanceMeters = meters;
    _phase = ArMeasurePhase.measured;
    notifyListeners();
  }

  void reset() {
    _phase = ArMeasurePhase.scanning;
    _firstPoint = null;
    _secondPoint = null;
    _distanceMeters = null;
    notifyListeners();
  }
}

