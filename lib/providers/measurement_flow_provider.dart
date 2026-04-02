import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../models/detection_result.dart';
import '../services/calibration_service.dart';
import '../services/measurement_service.dart';
import '../services/size_chart_service.dart';
import '../services/size_matching_service.dart';
import '../services/border_detection_service.dart';

/// Holds the full measurement flow state and services.
class MeasurementFlowProvider extends ChangeNotifier {
  MeasurementFlowProvider({
    required SizeChartService sizeChartService,
    required CalibrationService calibrationService,
    required MeasurementService measurementService,
    required SizeMatchingService sizeMatchingService,
    BorderDetectionService? borderDetectionService,
  }) : _sizeChartService = sizeChartService,
       _calibrationService = calibrationService,
       _measurementService = measurementService,
       _sizeMatchingService = sizeMatchingService,
       _borderDetectionService =
           borderDetectionService ?? BorderDetectionService();

  final SizeChartService _sizeChartService;
  final CalibrationService _calibrationService;
  final MeasurementService _measurementService;
  final SizeMatchingService _sizeMatchingService;
  final BorderDetectionService _borderDetectionService;

  SizeChartService get sizeChartService => _sizeChartService;
  CalibrationService get calibrationService => _calibrationService;
  MeasurementService get measurementService => _measurementService;
  SizeMatchingService get sizeMatchingService => _sizeMatchingService;
  BorderDetectionService get borderDetectionService => _borderDetectionService;

  String? _selectedCategory;
  String? get selectedCategory => _selectedCategory;
  set selectedCategory(String? v) {
    _selectedCategory = v;
    notifyListeners();
  }

  ReferenceType? _referenceType = ReferenceType.creditCard;
  ReferenceType? get referenceType => _referenceType;
  set referenceType(ReferenceType? v) {
    _referenceType = v;
    notifyListeners();
  }

  CalibrationMode _calibrationMode = CalibrationMode.referenceObject;
  CalibrationMode get calibrationMode => _calibrationMode;
  set calibrationMode(CalibrationMode v) {
    _calibrationMode = v;
    notifyListeners();
  }

  double? _rulerSegmentMm;
  double? get rulerSegmentMm => _rulerSegmentMm;
  set rulerSegmentMm(double? v) {
    _rulerSegmentMm = v;
    notifyListeners();
  }

  Uint8List? _capturedImageBytes;
  Uint8List? get capturedImageBytes => _capturedImageBytes;
  set capturedImageBytes(Uint8List? v) {
    _capturedImageBytes = v;
    notifyListeners();
  }

  int _capturedImageWidth = 0;
  int _capturedImageHeight = 0;
  int get capturedImageWidth => _capturedImageWidth;
  int get capturedImageHeight => _capturedImageHeight;
  void setCapturedImageSize(int w, int h) {
    _capturedImageWidth = w;
    _capturedImageHeight = h;
    notifyListeners();
  }

  ObjectBounds? _objectBounds;
  ObjectBounds? get objectBounds => _objectBounds;
  set objectBounds(ObjectBounds? v) {
    _objectBounds = v;
    notifyListeners();
  }

  ReferenceCorners? _referenceCorners;
  ReferenceCorners? get referenceCorners => _referenceCorners;
  set referenceCorners(ReferenceCorners? v) {
    _referenceCorners = v;
    notifyListeners();
  }

  double? _scalePxPerMm;
  double? get scalePxPerMm => _scalePxPerMm;
  set scalePxPerMm(double? v) {
    _scalePxPerMm = v;
    notifyListeners();
  }

  /// Camera → tapped surface distance (m) from [ArDistanceCaptureScreen]; used with pinhole mm.
  double? _arCameraToSubjectMeters;
  double? get arCameraToSubjectMeters => _arCameraToSubjectMeters;
  set arCameraToSubjectMeters(double? v) {
    _arCameraToSubjectMeters = v;
    notifyListeners();
  }

  /// Horizontal FOV (degrees) of the **still capture**; tweak if mm are systematically off.
  double _arHorizontalFovDeg = 63;
  double get arHorizontalFovDeg => _arHorizontalFovDeg;
  set arHorizontalFovDeg(double v) {
    if (v <= 10 || v >= 170) return;
    _arHorizontalFovDeg = v;
    notifyListeners();
  }

  MeasurementResult? _measurementResult;
  MeasurementResult? get measurementResult => _measurementResult;
  set measurementResult(MeasurementResult? v) {
    _measurementResult = v;
    notifyListeners();
  }

  List<MatchedSize> _matchedSizes = [];
  List<MatchedSize> get matchedSizes => _matchedSizes;
  set matchedSizes(List<MatchedSize> v) {
    _matchedSizes = v;
    notifyListeners();
  }

  DetectionResult? _detectionResult;
  DetectionResult? get detectionResult => _detectionResult;
  set detectionResult(DetectionResult? v) {
    _detectionResult = v;
    notifyListeners();
  }

  /// Reset flow for a new measurement (keeps category/calibration mode).
  void resetCapture() {
    _capturedImageBytes = null;
    _capturedImageWidth = 0;
    _capturedImageHeight = 0;
    _objectBounds = null;
    _referenceCorners = null;
    _scalePxPerMm = null;
    _arCameraToSubjectMeters = null;
    _measurementResult = null;
    _matchedSizes = [];
    _detectionResult = null;
    notifyListeners();
  }

  /// Full reset including category.
  void resetAll() {
    _selectedCategory = null;
    _referenceType = null;
    _capturedImageBytes = null;
    _capturedImageWidth = 0;
    _capturedImageHeight = 0;
    _objectBounds = null;
    _referenceCorners = null;
    _scalePxPerMm = null;
    _arCameraToSubjectMeters = null;
    _measurementResult = null;
    _matchedSizes = [];
    _detectionResult = null;
    notifyListeners();
  }
}
