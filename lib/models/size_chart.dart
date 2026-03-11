import 'size_chart_entry.dart';

/// Full size chart: category name -> list of size entries.
class SizeChart {
  final Map<String, List<SizeChartEntry>> categories;

  const SizeChart({required this.categories});

  List<String> get categoryNames => categories.keys.toList();

  List<SizeChartEntry>? entriesFor(String category) => categories[category];
}
