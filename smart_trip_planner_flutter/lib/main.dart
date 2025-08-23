import 'package:flutter/material.dart';
import 'package:smart_trip_planner_flutter/presentation/auth/login.dart';
import 'package:smart_trip_planner_flutter/presentation/auth/signUp.dart';
import 'package:smart_trip_planner_flutter/presentation/home/TripPlannerScreen.dart';
import 'package:smart_trip_planner_flutter/presentation/home/itinerary.dart';

void main() {
  runApp(const MyApp());
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
      home: ItineraryScreen(),
    );
  }
}

