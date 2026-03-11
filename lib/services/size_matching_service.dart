import 'dart:math' as math;

import '../models/models.dart';

/// Finds closest size(s) from the chart using Euclidean distance in (width, heel-to-toe) space.
class SizeMatchingService {
  /// score = sqrt((measuredWidthMm - row.widthMm)^2 + (measuredHeightMm - row.heelToeMm)^2)
  /// Returns best match and optionally 2nd and 3rd nearest.
  List<MatchedSize> findNearest({
    required List<SizeChartEntry> entries,
    required double widthMm,
    required double heelToeMm,
    int topN = 3,
  }) {
    if (entries.isEmpty) return [];
    final withScore = entries.map((e) {
      final dw = widthMm - e.widthMm;
      final dh = heelToeMm - e.heelToeMm;
      final score = math.sqrt(dw * dw + dh * dh);
      return MatchedSize(
        entry: e,
        score: score,
        widthDiffMm: dw,
        heelToeDiffMm: dh,
      );
    }).toList();
    withScore.sort((a, b) => a.score.compareTo(b.score));
    return withScore.take(topN).toList();
  }

  /// Check if measurement sits between two sizes (warning case).
  String? betweenSizesWarning(List<MatchedSize> nearest) {
    if (nearest.length < 2) return null;
    final best = nearest.first;
    final second = nearest[1];
    if (best.score < 2 && second.score < 8) {
      return 'This measurement is between Size ${best.entry.size} and Size ${second.entry.size}';
    }
    return null;
  }
}
