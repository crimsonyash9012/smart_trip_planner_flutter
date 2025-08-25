import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:smart_trip_planner_flutter/data/model/itinerary.dart';
import 'package:smart_trip_planner_flutter/main.dart';

import 'itineraryScreen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Itinerary> itineraries = [];

  Future<void> _loadItineraries() async {
    final allTrips = await isar.itinerarys.where().findAll();
    setState(() => itineraries = allTrips);
  }

  @override
  void initState() {
    super.initState();
    _loadItineraries();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Trips",
        style: TextStyle(
          color: Colors.white
        ),),
        backgroundColor: const Color(0xFF2E6D4D),
      ),
      body: itineraries.isEmpty
          ? const Center(
        child: Text(
          "No trips saved yet.\nCreate your first itinerary!",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16),
        ),
      )
          : ListView.builder(
        itemCount: itineraries.length,
        itemBuilder: (context, index) {
          final trip = itineraries[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: ListTile(
              title: Text(trip.title),
              subtitle: Text(
                trip.createdAt.toLocal().toString().split('.')[0],
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ItineraryScreen(itinerary: trip),
                  ),
                ).then((_) => _loadItineraries());
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF2E6D4D),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ItineraryScreen(),
            ),
          ).then((_) => _loadItineraries());
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
