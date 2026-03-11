import 'dart:ui' show Offset;

import 'reference_type.dart';
import 'calibration_mode.dart';

/// Stored calibration: either reference-based scale or fixed pixels-per-mm.
class CalibrationData {
  final CalibrationMode mode;
  /// For fixed mode: pixels per mm (single scale; assumes top-down view).
  final double? pixelsPerMm;
  /// For reference mode: reference type (credit card, A4, ruler).
  final ReferenceType? referenceType;
  /// For ruler: user-defined segment length in mm.
  final double? rulerSegmentMm;
  /// When this calibration was created (for showing warnings).
  final DateTime createdAt;

  CalibrationData({
    required this.mode,
    this.pixelsPerMm,
    this.referenceType,
    this.rulerSegmentMm,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isValid {
    if (mode == CalibrationMode.fixedCalibration) {
      return pixelsPerMm != null && pixelsPerMm! > 0;
    }
    return referenceType != null;
  }

  /// Reference width in mm for scale calculation (horizontal dimension).
  double get referenceWidthMm {
    if (referenceType == ReferenceType.ruler && rulerSegmentMm != null) {
      return rulerSegmentMm!;
    }
    return referenceType?.widthMm ?? 0;
  }

  /// Reference height in mm (vertical dimension).
  double get referenceHeightMm {
    if (referenceType == ReferenceType.ruler && rulerSegmentMm != null) {
      return rulerSegmentMm!;
    }
    return referenceType?.heightMm ?? 0;
  }

  Map<String, dynamic> toJson() => {
        'mode': mode.name,
        'pixelsPerMm': pixelsPerMm,
        'referenceType': referenceType?.name,
        'rulerSegmentMm': rulerSegmentMm,
        'createdAt': createdAt.toIso8601String(),
      };

  factory CalibrationData.fromJson(Map<String, dynamic> json) {
    return CalibrationData(
      mode: CalibrationMode.values.byName(json['mode'] as String),
      pixelsPerMm: (json['pixelsPerMm'] as num?)?.toDouble(),
      referenceType: json['referenceType'] != null
          ? ReferenceType.values.byName(json['referenceType'] as String)
          : null,
      rulerSegmentMm: (json['rulerSegmentMm'] as num?)?.toDouble(),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
    );
  }
}

/// Four corners of the reference object in image coordinates (for perspective).
class ReferenceCorners {
  final Offset topLeft;
  final Offset topRight;
  final Offset bottomRight;
  final Offset bottomLeft;

  const ReferenceCorners({
    required this.topLeft,
    required this.topRight,
    required this.bottomRight,
    required this.bottomLeft,
  });

  List<Offset> get list => [topLeft, topRight, bottomRight, bottomLeft];
}
