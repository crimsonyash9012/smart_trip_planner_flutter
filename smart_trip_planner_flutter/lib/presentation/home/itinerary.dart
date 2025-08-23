import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class ItineraryScreen extends StatefulWidget {
  const ItineraryScreen({super.key});

  @override
  State<ItineraryScreen> createState() => _ItineraryScreenState();
}

class _ItineraryScreenState extends State<ItineraryScreen> {
  final TextEditingController _tripController = TextEditingController();
  final TextEditingController _followUpController = TextEditingController();

  List<Map<String, String>> _messages = []; // stores conversation with AI
  String? _response;
  bool _isLoading = false;
  bool _showFollowUpBox = false;

  Future<void> _getTripPlan({String? followUp}) async {
    setState(() {
      _isLoading = true;
      if (followUp == null) _response = null; // fresh start if new request
    });

    const apiKey = "api_key";
    const url = "https://api.groq.com/openai/v1/chat/completions";

    // Add user message to conversation
    if (followUp == null) {
      _messages = [
        {"role": "system", "content": "You are a smart trip planner assistant. "
            "Give all the details in headings. Important places and details must be in bold letters."},
        {"role": "user", "content": _tripController.text.trim()},
      ];
    } else {
      _messages.add({"role": "user", "content": followUp});
    }

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          "Authorization": "Bearer $apiKey",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "model": "llama3-8b-8192",
          "messages": _messages,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final reply = data["choices"][0]["message"]["content"];

        setState(() {
          _response = reply;
          _messages.add({"role": "assistant", "content": reply});
        });
      } else {
        setState(() {
          _response = "Error: ${response.body}";
        });
      }
    } catch (e) {
      setState(() {
        _response = "Error: $e";
      });
    }

    setState(() => _isLoading = false);
  }

  Future<void> _openMaps(String destination) async {
    final encodedDestination = Uri.encodeComponent(destination);

    final url = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$encodedDestination');

    if (!await launchUrl(
      url,
      mode: LaunchMode.externalApplication, // 👈 ensures it opens outside app
    )) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F6F6),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: "Hey Shubham ",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2E6D4D),
                          ),
                        ),
                        TextSpan(text: "👋"),
                      ],
                    ),
                  ),
                  const CircleAvatar(
                    radius: 18,
                    backgroundColor: Color(0xFF2E6D4D),
                    child: Text("S", style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // UI Flow
              Expanded(
                child: Center(
                  child: _isLoading
                      ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      CircularProgressIndicator(color: Color(0xFF2E6D4D)),
                      SizedBox(height: 16),
                      Text(
                        "Creating Itinerary...\nCurating a perfect plan for you...",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.black87),
                      ),
                    ],
                  )
                      : _response != null
                      ? SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Itinerary Created 🌴",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 🔹 Open in Maps option
                        GestureDetector(
                          onTap: () => _openMaps(_tripController.text.trim()),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              children: const [
                                Icon(Icons.place, color: Colors.redAccent),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    "Open in Maps",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Icon(Icons.arrow_forward_ios, size: 16),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // 🔹 AI Itinerary Output
                        MarkdownBody(
                          data: _response!,
                          styleSheet: MarkdownStyleSheet(
                            h1: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87),
                            h2: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87),
                            p: const TextStyle(
                                fontSize: 16, color: Colors.black87),
                            strong: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.black),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // 🔹 Refine button
                        ElevatedButton(
                          onPressed: () {
                            setState(() => _showFollowUpBox = !_showFollowUpBox);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2E6D4D),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            _showFollowUpBox
                                ? "Cancel Follow-Up"
                                : "Refine Itinerary ✨",
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),

                        // 🔹 Follow-up box
                        if (_showFollowUpBox) ...[
                          const SizedBox(height: 16),
                          TextField(
                            controller: _followUpController,
                            minLines: 2,
                            maxLines: 4,
                            decoration: InputDecoration(
                              hintText:
                              "Add details or refinements (e.g. make it budget-friendly, add hiking)...",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () {
                              final followUp = _followUpController.text.trim();
                              if (followUp.isNotEmpty) {
                                _followUpController.clear();
                                _getTripPlan(followUp: followUp);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2E6D4D),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text("Send Follow-Up",
                                style: TextStyle(color: Colors.white)),
                          ),
                        ]
                      ],
                    ),
                  )
                      : Column(
                    children: [
                      const Text(
                        "What’s your vision\nfor this trip?",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Input box
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFF2E6D4D)),
                          borderRadius: BorderRadius.circular(14),
                          color: Colors.white,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _tripController,
                                maxLines: 5,
                                minLines: 3,
                                decoration: const InputDecoration(
                                  hintText:
                                  "Describe your trip (e.g. 7 days in Bali, 3 people, mid-range budget...)",
                                  border: InputBorder.none,
                                ),
                                style: const TextStyle(
                                    fontSize: 15, color: Colors.black87),
                              ),
                            ),
                            const SizedBox(width: 12),
                            IconButton(
                              onPressed: () {
                                // Future: speech-to-text
                              },
                              icon: const Icon(Icons.mic,
                                  color: Color(0xFF2E6D4D)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _getTripPlan,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2E6D4D),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            "Create My Itinerary",
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
