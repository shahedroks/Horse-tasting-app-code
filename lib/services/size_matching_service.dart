import 'dart:math' as math;

import '../models/models.dart';

/// Picks chart rows so the shoe is large enough for the measured foot, then tightest fit.
///
/// Pure Euclidean distance in (width, heel-to-toe) often recommends sizes that are
/// too small in one dimension (e.g. square 3x0 vs a longer hoof) because the centroid
/// is "close" in 2D. Instead we prefer the smallest chart entry that still covers both
/// measured dimensions within [fitToleranceMm], minimizing total overshoot (mm).
class SizeMatchingService {
  /// Allowed undershoot per dimension when treating a row as still "fitting".
  static const double fitToleranceMm = 3.0;

  /// Scores at or above this value mean no chart row was large enough on both axes (ranking key, not mm).
  static const double nonFitScoreBase = 2000.0;

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
      final deficitW = math.max(0.0, dw);
      final deficitH = math.max(0.0, dh);
      final fits =
          deficitW <= fitToleranceMm && deficitH <= fitToleranceMm;
      final excessW = math.max(0.0, -dw);
      final excessH = math.max(0.0, -dh);
      final overshootSum = excessW + excessH;
      final score = fits
          ? overshootSum
          : nonFitScoreBase +
              deficitW * 200 +
              deficitH * 200 +
              math.sqrt(dw * dw + dh * dh);
      return MatchedSize(
        entry: e,
        score: score,
        widthDiffMm: dw,
        heelToeDiffMm: dh,
      );
    }).toList();
    withScore.sort((a, b) {
      final byScore = a.score.compareTo(b.score);
      if (byScore != 0) return byScore;
      final ae = math.sqrt(
        a.widthDiffMm * a.widthDiffMm + a.heelToeDiffMm * a.heelToeDiffMm,
      );
      final be = math.sqrt(
        b.widthDiffMm * b.widthDiffMm + b.heelToeDiffMm * b.heelToeDiffMm,
      );
      return ae.compareTo(be);
    });
    return withScore.take(topN).toList();
  }

  /// Check if measurement sits between two sizes (warning case).
  String? betweenSizesWarning(List<MatchedSize> nearest) {
    if (nearest.length < 2) return null;
    final best = nearest.first;
    final second = nearest[1];
    final bestFits = _entryFits(best.widthDiffMm, best.heelToeDiffMm);
    final secondFits = _entryFits(second.widthDiffMm, second.heelToeDiffMm);
    if (bestFits && secondFits && (second.score - best.score).abs() < 8) {
      return 'This measurement is between Size ${best.entry.size} and Size ${second.entry.size}';
    }
    if (!bestFits &&
        !secondFits &&
        best.score >= nonFitScoreBase &&
        second.score >= nonFitScoreBase &&
        (second.score - best.score).abs() < 150) {
      return 'This measurement is between Size ${best.entry.size} and Size ${second.entry.size}';
    }
    return null;
  }

  bool _entryFits(double widthDiffMm, double heelToeDiffMm) {
    return widthDiffMm <= fitToleranceMm && heelToeDiffMm <= fitToleranceMm;
  }
}
