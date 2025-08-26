import 'dart:async';
import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:smart_trip_planner_flutter/presentation/home/HomeScreen.dart';
import 'package:smart_trip_planner_flutter/presentation/home/itineraryScreen.dart';

import 'data/model/itinerary.dart';


late Isar isar;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('[Init] Starting app initialization...');
  try {
    final dir = await getApplicationDocumentsDirectory();
    debugPrint('[Init] App documents directory: ${dir.path}');
    isar = await Isar.open([ItinerarySchema], directory: dir.path)
        .timeout(const Duration(seconds: 10));
    debugPrint('[Init] Isar database opened successfully.');
    runApp(const MyApp());
  } on TimeoutException {
    debugPrint('[Init][ERROR] Isar.open timed out.');
    runApp(const InitErrorApp(
      message: 'Initializing local database timed out. Please close and reopen the app.',
    ));
  } catch (e, st) {
    debugPrint('[Init][ERROR] Failed to initialize Isar: $e');
    debugPrintStack(stackTrace: st);
    runApp(InitErrorApp(
      message: 'Failed to initialize local database: $e',
    ));
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: HomeScreen(),
    );
  }
}

class InitErrorApp extends StatelessWidget {
  final String message;
  const InitErrorApp({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Initialization Error',
      home: Scaffold(
        appBar: AppBar(title: const Text('Smart Trip Planner')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 12),
                const Text(
                  'App failed to start',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Tip: Ensure storage permission is granted and try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

