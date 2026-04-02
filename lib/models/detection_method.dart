/// How the object border was determined (auto vs manual).
enum DetectionMethod {
  autoNative,
  autoClassic,
  autoMl,
  autoForeground,
  manual,
}

extension DetectionMethodX on DetectionMethod {
  String get displayName {
    switch (this) {
      case DetectionMethod.autoNative:
        return 'Auto (Native)';
      case DetectionMethod.autoClassic:
        return 'Auto (Classic)';
      case DetectionMethod.autoMl:
        return 'Auto (ML)';
      case DetectionMethod.autoForeground:
        return 'Auto (Foreground)';
      case DetectionMethod.manual:
        return 'Manual';
    }
  }
}
