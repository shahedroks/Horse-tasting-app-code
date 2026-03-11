import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/measurement_flow_provider.dart';
import '../../services/size_chart_service.dart';

/// View size chart by category.
class SizeChartScreen extends StatelessWidget {
  const SizeChartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final flow = context.watch<MeasurementFlowProvider>();
    final chart = flow.sizeChartService.chart;
    if (chart == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Size Chart')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final categories = SizeChartService.categoryOrder;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Size Chart'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final name = categories[index];
          final entries = chart.entriesFor(name) ?? [];
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(name, style: Theme.of(context).textTheme.titleLarge),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Size')),
                      DataColumn(label: Text('Width (mm)')),
                      DataColumn(label: Text('Heel-Toe (mm)')),
                    ],
                    rows: entries
                        .map((e) => DataRow(
                              cells: [
                                DataCell(Text(e.size)),
                                DataCell(Text(e.widthMm.toStringAsFixed(0))),
                                DataCell(Text(e.heelToeMm.toStringAsFixed(0))),
                              ],
                            ))
                        .toList(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
