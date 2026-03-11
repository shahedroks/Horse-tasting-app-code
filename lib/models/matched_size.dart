import 'size_chart_entry.dart';

/// One size match from the chart with distance score and difference.
class MatchedSize {
  final SizeChartEntry entry;
  final double score;
  final double widthDiffMm;
  final double heelToeDiffMm;

  const MatchedSize({
    required this.entry,
    required this.score,
    required this.widthDiffMm,
    required this.heelToeDiffMm,
  });
}
