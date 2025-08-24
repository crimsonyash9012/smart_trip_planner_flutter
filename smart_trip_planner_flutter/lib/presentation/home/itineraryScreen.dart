import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../data/model/itinerary.dart';
import '../../main.dart';

class ItineraryScreen extends StatefulWidget {
  const ItineraryScreen({super.key});

  @override
  State<ItineraryScreen> createState() => _ItineraryScreenState();
}

String _fixMapLinks(String text) {
  var t = text;

  // 0) Normalize http(s)://maps:// -> maps://
  t = t.replaceAll(RegExp(r'https?:\/\/maps:\/\/', caseSensitive: false), 'maps://');

  // 1) Turn: "Hotel Hans Plaza (maps://Hotel Hans Plaza)" -> "[Hotel Hans Plaza](maps://Hotel Hans Plaza)"
  t = t.replaceAllMapped(
    RegExp(r'(?<!\])\b([^\[\]\(]+?)\s*\(\s*maps:\/\/([^)]+)\s*\)'),
        (m) {
      final label = m.group(1)!.trim().replaceAll(RegExp(r'[\s\.,;:]+$'), '');
      final href  = m.group(2)!.trim();
      return '[$label](maps://$href)';
    },
  );

  // 2) Normalize already-linked forms like: "[Place] (maps://Place)" -> "[Place](maps://Place)"
  t = t.replaceAllMapped(
    RegExp(r'\[([^\]]+)\]\s*\(\s*maps:\/\/([^)]+)\s*\)'),
        (m) => '[${m.group(1)!.trim()}](maps://${m.group(2)!.trim()})',
  );

  // 3) Unwrap stray parentheses around a proper link: "([Place](maps://...))" -> "[Place](maps://...)"
  t = t.replaceAllMapped(
    RegExp(r'\(\s*(\[[^\]]+\]\(maps:\/\/[^)]+\))\s*\)'),
        (m) => m.group(1)!,
  );

  // 4) Remove accidental duplicated “(maps://...)” after a link
  t = t.replaceAll(RegExp(r'\)\(maps:\/\/[^\)]+\)'), ')');

  // 5) Remove leftover “$1”, “$2”… (but keep real money amounts)
  t = t.replaceAll(RegExp(r'(?<=\]\(maps:\/\/[^)]+\))\s*\$[0-9]+\b'), '');

  // 6) Remove duplicate plain text before links:
  //    "Tokyo Station [Tokyo Station](maps://Tokyo Station)" -> "[Tokyo Station](maps://Tokyo Station)"
  t = t.replaceAllMapped(
    RegExp(r'(\b([^\[]+?)\s*)\[\2\]\(maps:\/\/([^)]+)\)'),
        (m) => '[${m.group(2)!.trim()}](maps://${m.group(3)!.trim()})',
  );

  return t;
}

String _autoLinkKnownPlaces(String text) {
  // Find all linked place names
  final linkedPlaceRegex = RegExp(r'\[([^\]]+)\]\(maps:\/\/[^\)]+\)');
  final linkedPlaces = linkedPlaceRegex.allMatches(text).map((m) => m.group(1)!).toSet();

  // For each place, replace plain text occurrences with Markdown links if not already linked
  for (final place in linkedPlaces) {
    // Match place not inside link: (?<!\[)Place Name(?!\]\(maps://)
    // Only replace if not inside square brackets (already linked)
    text = text.replaceAllMapped(
      RegExp(r'(?<![\]\)])\b' + RegExp.escape(place) + r'\b(?![\(\]])'),
          (m) => '[${m.group(0)}](maps://${m.group(0)})',
    );
  }
  return text;
}


class _ItineraryScreenState extends State<ItineraryScreen> {
  final TextEditingController _tripController = TextEditingController();
  final TextEditingController _followUpController = TextEditingController();

  List<Map<String, String>> _messages = [];
  String? _response;
  bool _isLoading = false;
  bool _showFollowUpBox = false;

  String? _origin;
  String? _destination;
  List<String> _waypoints = [];

  Future<void> _getTripPlan({String? followUp}) async {
    setState(() {
      _isLoading = true;
      if (followUp == null) {
        _response = null;
        _origin = null;
        _destination = null;
        _waypoints.clear();
      }
    });

    const apiKey = "";
    const url = "https://api.groq.com/openai/v1/chat/completions";

    if (followUp == null) {
      _messages = [
        {
          "role": "system",
          "content": """
            You are a smart trip planner assistant.
            
            Rules:
            1. All section titles must be in Markdown headings (#, ##, ###).
            2. All important details (dates, times, costs, names) must be in **bold**.
            3. Every place (restaurant, airport, hotel, tourist attraction) MUST be wrapped as a Markdown hyperlink like this:
               [Place Name](maps://Place Name)
               Example: Visit [Eiffel Tower](maps://Eiffel Tower).
            4. At the end, clearly write:
               Start: <starting location>
               End: <ending location>
            5. Every place MUST be written as exactly one Markdown link:
                [Place Name](maps://Place Name)
                
            6. Do not write duplicate (maps://...) after the link.
            7. Do not wrap links in extra parentheses.   
            
            When generating itineraries:
            1. Identify where real-time info is needed (e.g., "best restaurants in Kyoto", "top hotels near Shinjuku").
            2. Instead of guessing, return a JSON request like: SEARCH: {"query": "best restaurants in Kyoto"}
            3. The app will execute the search (via Google Places API, Yelp, or Groq Web Search), then feed results back to you.
            4. After receiving results, include them in the itinerary.
            5. Final output must follow Markdown formatting rules with [Place](maps://Place).
        
            """,
        },
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
        body: jsonEncode({"model": "llama3-8b-8192", "messages": _messages}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final reply = data["choices"][0]["message"]["content"];

        final cleanedReply = _fixMapLinks(reply);
        // final fullyLinkedReply = _autoLinkKnownPlaces(cleanedReply);

        // _extractRouteDetails(fullyLinkedReply);

        setState(() {
          _response = cleanedReply;
          _messages.add({"role": "assistant", "content": cleanedReply});
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

  void _extractRouteDetails(String text) {
    final startRegex = RegExp(r"Start:\s*(.*)", caseSensitive: false);
    final endRegex = RegExp(r"End:\s*(.*)", caseSensitive: false);

    final startMatch = startRegex.firstMatch(text);
    final endMatch = endRegex.firstMatch(text);

    _origin = startMatch != null ? startMatch.group(1)?.trim() : null;
    _destination = endMatch != null ? endMatch.group(1)?.trim() : null;

    final waypointsRegex = RegExp(r"\[([^\]]+)\]\(maps://[^\)]+\)");
    _waypoints = waypointsRegex
        .allMatches(text)
        .map((m) => m.group(1)!)
        .where((p) => p != _origin && p != _destination)
        .toList();
  }

  Future<void> _openMaps(String destination) async {
    final encoded = Uri.encodeComponent(destination);

    final googleUrl = Uri.parse(
      "https://www.google.com/maps/search/?api=1&query=$encoded",
    );
    final appleUrl = Uri.parse("http://maps.apple.com/?q=$encoded");

    final url = Platform.isIOS ? appleUrl : googleUrl;

    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception("Could not launch $url");
    }
  }

  Future<void> _openRoute() async {
    if (_origin == null || _destination == null) return;

    final waypointsStr = _waypoints.map(Uri.encodeComponent).join("|");

    final googleUrl = Uri.parse(
      "https://www.google.com/maps/dir/?api=1"
      "&origin=${Uri.encodeComponent(_origin!)}"
      "&destination=${Uri.encodeComponent(_destination!)}"
      "&waypoints=$waypointsStr"
      "&travelmode=driving",
    );

    final appleUrl = Uri.parse(
      "http://maps.apple.com/?saddr=${Uri.encodeComponent(_origin!)}&daddr=${Uri.encodeComponent(_destination!)}",
    );

    final url = Platform.isIOS ? appleUrl : googleUrl;

    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception("Could not launch $url");
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
              // HEADER
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
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.black87,
                              ),
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

                              // Open in Maps (generic query)
                              GestureDetector(
                                onTap: () =>
                                    _openMaps(_tripController.text.trim()),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  child: Row(
                                    children: const [
                                      Icon(
                                        Icons.place,
                                        color: Colors.redAccent,
                                      ),
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
                              const SizedBox(height: 16),

                              // Open full route if available
                              if (_origin != null && _destination != null)
                                ElevatedButton.icon(
                                  onPressed: _openRoute,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2E6D4D),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.map,
                                    color: Colors.white,
                                  ),
                                  label: const Text(
                                    "Open Full Route in Maps",
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),

                              const SizedBox(height: 20),

                              // AI Itinerary Output
                              MarkdownBody(
                                data: _fixMapLinks(_response!),
                                onTapLink: (text, href, title) {
                                  if (href != null && href.startsWith('maps://')) {
                                    _openMaps(href.substring('maps://'.length));
                                  }
                                },
                                styleSheet: MarkdownStyleSheet(
                                  h1: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                  h2: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                  p: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.black87,
                                  ),
                                  strong: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                  a: const TextStyle(
                                    color: Colors.blue,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  if (_response != null) {
                                    final trip = Itinerary()
                                      ..title = _tripController.text.trim().isNotEmpty
                                          ? _tripController.text.trim()
                                          : "Untitled Trip"
                                      ..content = _response!
                                      ..createdAt = DateTime.now();

                                    await isar.writeTxn(() async {
                                      await isar.itinerarys.put(trip);
                                    });

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text("Itinerary saved ✅")),
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                icon: const Icon(Icons.save, color: Colors.white),
                                label: const Text("Save", style: TextStyle(color: Colors.white)),
                              ),
                              const SizedBox(height: 24),

                              // Refine button & follow-up
                              ElevatedButton(
                                onPressed: () {
                                  setState(
                                    () => _showFollowUpBox = !_showFollowUpBox,
                                  );
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
                              if (_showFollowUpBox) ...[
                                const SizedBox(height: 16),
                                TextField(
                                  controller: _followUpController,
                                  minLines: 2,
                                  maxLines: 4,
                                  decoration: InputDecoration(
                                    hintText:
                                        "Add details or refinements (e.g. budget-friendly, hiking)...",
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton(
                                  onPressed: () {
                                    final followUp = _followUpController.text
                                        .trim();
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
                                  child: const Text(
                                    "Send Follow-Up",
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              ],
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
                                border: Border.all(
                                  color: const Color(0xFF2E6D4D),
                                ),
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
                                        fontSize: 15,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  IconButton(
                                    onPressed: () {
                                      // Speech-to-text placeholder
                                    },
                                    icon: const Icon(
                                      Icons.mic,
                                      color: Color(0xFF2E6D4D),
                                    ),
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
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
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
