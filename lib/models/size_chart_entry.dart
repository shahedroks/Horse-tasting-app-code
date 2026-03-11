/// One row in the size chart: size label, width in mm, heel-to-toe in mm.
class SizeChartEntry {
  final String size;
  final double widthMm;
  final double heelToeMm;

  const SizeChartEntry({
    required this.size,
    required this.widthMm,
    required this.heelToeMm,
  });

  factory SizeChartEntry.fromJson(Map<String, dynamic> json) {
    return SizeChartEntry(
      size: json['size'] as String,
      widthMm: (json['widthMm'] as num).toDouble(),
      heelToeMm: (json['heelToeMm'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'size': size,
        'widthMm': widthMm,
        'heelToeMm': heelToeMm,
      };
}
