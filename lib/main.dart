import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/measurement_flow_provider.dart';
import 'services/calibration_service.dart';
import 'services/measurement_service.dart';
import 'services/size_chart_service.dart';
import 'services/size_matching_service.dart';

import 'features/home/home_screen.dart';
import 'features/category/category_screen.dart';
import 'features/instructions/instructions_screen.dart';
import 'features/camera_capture/camera_capture_screen.dart';
import 'features/measurement/detection_screen.dart';
import 'features/result/result_screen.dart';
import 'features/size_chart/size_chart_screen.dart';
import 'features/calibration/calibration_screen.dart';
import 'features/processing/processing_screen.dart';
import 'features/review/review_screen.dart';
import 'features/ar_measurement/ar_measure_screen.dart';
import 'features/ar_measurement/ar_measure_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final sizeChartService = SizeChartService();
  final calibrationService = CalibrationService();
  await sizeChartService.load();
  await calibrationService.loadSaved();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => MeasurementFlowProvider(
            sizeChartService: sizeChartService,
            calibrationService: calibrationService,
            measurementService: MeasurementService(calibrationService),
            sizeMatchingService: SizeMatchingService(),
          ),
        ),
        ChangeNotifierProvider(create: (_) => ArMeasureProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Size Measure',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
        '/category': (context) => const CategoryScreen(),
        '/instructions': (context) => const InstructionsScreen(),
        '/camera': (context) => const CameraCaptureScreen(),
        '/processing': (context) => const ProcessingScreen(),
        '/review': (context) => const ReviewScreen(),
        '/detection': (context) => const DetectionScreen(),
        '/result': (context) => const ResultScreen(),
        '/size_chart': (context) => const SizeChartScreen(),
        '/calibration': (context) => const CalibrationScreen(),
        '/ar_measure': (context) => const ArMeasureScreen(),
      },
    );
  }
}
