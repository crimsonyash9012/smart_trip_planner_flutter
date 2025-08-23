import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class TripPlannerScreen extends StatefulWidget {
  const TripPlannerScreen({super.key});

  @override
  State<TripPlannerScreen> createState() => _TripPlannerScreenState();
}

class _TripPlannerScreenState extends State<TripPlannerScreen> {
  final TextEditingController _tripController = TextEditingController();
  String? _response;
  bool _isLoading = false;

  Future<void> _getTripPlan() async {
    final tripDetails = _tripController.text.trim();
    if (tripDetails.isEmpty) return;

    setState(() {
      _isLoading = true;
      _response = null;
    });

    const apiKey = "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";
    const url = "https://api.groq.com/openai/v1/chat/completions";

    final response = await http.post(
      Uri.parse(url),
      headers: {
        "Authorization": "Bearer $apiKey",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "model": "llama3-8b-8192", // Groq’s recommended chat model
        "messages": [
          {"role": "system", "content": "You are a smart trip planner assistant."},
          {"role": "user", "content": tripDetails}
        ],
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        _response = data["choices"][0]["message"]["content"];
      });
    } else {
      setState(() {
        _response = "Error: ${response.body}";
      });
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Smart Trip Planner")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: TextField(
                controller: _tripController,
                maxLines: 5,
                minLines: 3,
                decoration: const InputDecoration(
                  hintText: "Describe your trip (e.g. 7 days in Bali, 3 people, mid-range budget...)",
                  border: OutlineInputBorder(),
                ),
                style: const TextStyle(fontSize: 15, color: Colors.black87),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _getTripPlan,
              child: const Text("Get Trip Plan"),
            ),
            const SizedBox(height: 20),
            if (_isLoading)
              const CircularProgressIndicator()
            else if (_response != null)
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    _response!,
                    style: const TextStyle(fontSize: 16, color: Colors.black87),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
