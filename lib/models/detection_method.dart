/// How the object border was determined (auto vs manual).
enum DetectionMethod {
  auto,
  manual,
}

extension DetectionMethodX on DetectionMethod {
  String get displayName {
    switch (this) {
      case DetectionMethod.auto:
        return 'Auto';
      case DetectionMethod.manual:
        return 'Manual';
    }
  }
}
