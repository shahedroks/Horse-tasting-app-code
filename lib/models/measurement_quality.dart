/// Quality of the measurement (detection + calibration reliability).
enum MeasurementQuality {
  good,
  medium,
  poor,
}

extension MeasurementQualityX on MeasurementQuality {
  String get displayName {
    switch (this) {
      case MeasurementQuality.good:
        return 'Good';
      case MeasurementQuality.medium:
        return 'Medium';
      case MeasurementQuality.poor:
        return 'Poor';
    }
  }
}
