/// Known reference object types with fixed dimensions (mm).
/// Used for Mode A: reference object calibration.
enum ReferenceType {
  creditCard(85.60, 53.98),
  a4Sheet(210, 297),
  /// Ruler uses user-defined segment length (mm).
  ruler(0, 0);

  const ReferenceType(this.widthMm, this.heightMm);
  final double widthMm;
  final double heightMm;

  String get displayName {
    switch (this) {
      case ReferenceType.creditCard:
        return 'Credit Card (85.6 × 54 mm)';
      case ReferenceType.a4Sheet:
        return 'A4 Sheet (210 × 297 mm)';
      case ReferenceType.ruler:
        return 'Ruler (define segment)';
    }
  }
}
