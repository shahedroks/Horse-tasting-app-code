import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/measurement_flow_provider.dart';
import '../../services/size_chart_service.dart';

/// Category selection: MINI, FRONTS, DRAFT, SPORTSHU, HINDS.
class CategoryScreen extends StatelessWidget {
  const CategoryScreen({super.key});

  static const List<String> categories = SizeChartService.categoryOrder;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Category'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final name = categories[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              title: Text(name),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                context.read<MeasurementFlowProvider>().selectedCategory = name;
                Navigator.of(context).pushReplacementNamed('/instructions');
              },
            ),
          );
        },
      ),
    );
  }
}
