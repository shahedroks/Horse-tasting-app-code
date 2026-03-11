import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/models.dart';

/// Loads and parses the local size chart from assets.
class SizeChartService {
  static const String _assetPath = 'assets/size_chart.json';

  SizeChart? _chart;

  /// Loads the size chart from JSON asset. Call once at app start.
  Future<SizeChart> load() async {
    if (_chart != null) return _chart!;
    final String jsonString =
        await rootBundle.loadString(_assetPath);
    final Map<String, dynamic> map =
        jsonDecode(jsonString) as Map<String, dynamic>;
    final Map<String, List<SizeChartEntry>> categories = {};
    for (final entry in map.entries) {
      final list = (entry.value as List<dynamic>)
          .map((e) => SizeChartEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      categories[entry.key] = list;
    }
    _chart = SizeChart(categories: categories);
    return _chart!;
  }

  SizeChart? get chart => _chart;

  /// Returns category names in display order.
  static const List<String> categoryOrder = [
    'MINI',
    'FRONTS',
    'DRAFT',
    'SPORTSHU',
    'HINDS',
  ];
}
