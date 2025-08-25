import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../data/model/itinerary.dart';
import '../../main.dart';

const String _systemPrompt = """
You are a smart trip planner assistant.

Rules:
1. Your ONLY output must be valid JSON following this schema:

{
  "title": "Trip Title",
  "startDate": "YYYY-MM-DD",
  "endDate": "YYYY-MM-DD",
  "days": [
    {
      "date": "YYYY-MM-DD",
      "summary": "Day summary",
      "items": [
        { "time": "HH:MM", "activity": "Activity description", "location": "lat,lng" }
      ]
    }
  ],
  "hotels": [
    { "name": "Hotel name", "pricePerNight": 100, "location": "lat,lng" }
  ],
  "touristSpots": [
    { "name": "Spot name", "location": "lat,lng", "description": "Short description" }
  ],
  "food": [
    { "name": "Restaurant or street food", "cuisine": "Indian/Italian/etc", "avgCost": 15, "location": "lat,lng" }
  ],
  "transportOptions": [
    { "mode": "flight/train/bus/cab", "provider": "Airline/Bus/Taxi/etc", "approxCost": 50, "duration": "2h 30m" }
  ],
  "estimatedBudget": {
    "currency": "INR",
    "accommodation": 0,
    "food": 0,
    "transport": 0,
    "activities": 0,
    "total": 0
  }
}

2. Do NOT include Markdown, explanations, or extra text. Only return valid JSON.
3. Every `location` must be in "lat,lng" format.
4. All budget numbers must be realistic estimates in Indian Rupees (not all zeros).
5. "hotels", "touristSpots", "food", "transportOptions", and "estimatedBudget" are required but can be empty arrays/objects if not applicable.
""";

String? _extractJson(String text) {
  final start = text.indexOf("{");
  final end = text.lastIndexOf("}");
  if (start != -1 && end != -1 && end > start) {
    return text.substring(start, end + 1);
  }
  return null;
}

String _repairJson(String jsonStr) {
  return jsonStr
      .replaceAllMapped(RegExp(r'"(\w+)"\s*,\s*'), (m) => '"${m[1]}": ')
      .replaceAll(",}", "}")
      .replaceAll(",]", "]");
}

/// Helper to open coordinates in Maps
/// Try to launch a Uri; returns true if something opened.
Future<bool> _launch(Uri uri) async {
  if (await canLaunchUrl(uri)) {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
  return false;
}

/// Open coordinates in Maps (native first, then web)
Future<void> _openInMaps(String latLng, {String? label}) async {
  final clean = latLng.replaceAll(' ', '');
  final q = label == null ? clean : '$clean($label)';

  final attempts = <Uri>[
    if (Platform.isIOS) Uri.parse('maps://?q=$q'), // Apple Maps (app)
    if (Platform.isAndroid) Uri.parse('geo:$clean?q=$q'), // Any maps app
    Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': q}),
    Uri.https('maps.apple.com', '/', {'q': q}),
  ];

  for (final u in attempts) {
    if (await _launch(u)) return;
  }
}

/// Open route from current location → destination
Future<void> _openRouteInMaps(String destinationLatLng) async {
  final dest = destinationLatLng.replaceAll(' ', '');

  final attempts = <Uri>[
    if (Platform.isIOS)
      Uri.parse('maps://?daddr=$dest&dirflg=d'), // Apple Maps driving
    if (Platform.isAndroid)
      Uri.parse('google.navigation:q=$dest&mode=d'), // Google Maps nav
    Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': dest,
    }),
    Uri.https('maps.apple.com', '/', {'daddr': dest, 'dirflg': 'd'}),
  ];

  for (final u in attempts) {
    if (await _launch(u)) return;
  }
}

class ItineraryScreen extends StatefulWidget {
  final Itinerary? itinerary;
  const ItineraryScreen({super.key, this.itinerary});

  @override
  State<ItineraryScreen> createState() => _ItineraryScreenState();
}

class _ItineraryScreenState extends State<ItineraryScreen> {
  final TextEditingController _tripController = TextEditingController();
  final TextEditingController _followUpController = TextEditingController();

  List<Map<String, String>> _messages = [];
  String? _response;
  bool _isLoading = false;
  // Live suggestions picked by Groq from Google top 5 results
  Map<String, Map<String, dynamic>> _livePicks = {};

  // Google API Key (provided by user)
  static const String _googleApiKey =
      '';

  Future<void> _deleteCurrentItinerary() async {
    final it = widget.itinerary;
    if (it == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this itinerary?'),
        content: Text('"${it.title}" will be permanently deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await isar.writeTxn(() async {
        await isar.itinerarys.delete(it.id);
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Itinerary deleted')),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  void initState() {
    super.initState();
    _messages = [
      {"role": "system", "content": _systemPrompt},
    ];
    if (widget.itinerary != null) {
      _response = widget.itinerary!.content;
      _tripController.text = widget.itinerary!.title;
      _messages.addAll([
        {"role": "user", "content": widget.itinerary!.title},
        {"role": "assistant", "content": _response!},
      ]);
      // Kick off live searches for saved itinerary
      try {
        final itJson = jsonDecode(_response!);
        _runLiveSearches(itJson);
      } catch (_) {}
    }
  }

  Future<void> _getTripPlan({String? followUp}) async {
    setState(() => _isLoading = true);

    const apiKey =
        ""; // <-- replace
    const url = "https://api.groq.com/openai/v1/chat/completions";

    if (followUp == null) {
      _messages.add({"role": "user", "content": _tripController.text.trim()});
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
          "model": "llama-3.3-70b-versatile",
          "messages": _messages,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data.containsKey("error")) {
          setState(() {
            _response = "API Error: ${data["error"]["message"]}";
          });
          return;
        }

        final reply = data["choices"][0]["message"]["content"];
        final jsonStr = _extractJson(reply);

        if (jsonStr != null) {
          try {
            final itineraryJson = jsonDecode(jsonStr);
            setState(() {
              _response = jsonEncode(itineraryJson);
              _messages.add({"role": "assistant", "content": _response!});
            });
            // Run live searches based on the freshly generated itinerary
            _runLiveSearches(itineraryJson);
          } catch (_) {
            try {
              final repaired = _repairJson(jsonStr);
              final itineraryJson = jsonDecode(repaired);
              setState(() {
                _response = jsonEncode(itineraryJson);
                _messages.add({"role": "assistant", "content": _response!});
              });
              _runLiveSearches(itineraryJson);
            } catch (_) {
              setState(() {
                _response = reply;
                _messages.add({"role": "assistant", "content": reply});
              });
            }
          }
        } else {
          setState(() {
            _response = reply;
            _messages.add({"role": "assistant", "content": reply});
          });
        }
      } else {
        setState(() => _response = "Error: ${response.body}");
      }
    } catch (e) {
      setState(() => _response = "Error: $e");
    }

    setState(() => _isLoading = false);
  }

  // ===== Live search integration =====
  Future<void> _runLiveSearches(Map<String, dynamic> itinerary) async {
    // Derive base location text from title or first tourist spot
    final String title = (itinerary['title'] ?? '').toString();
    String base = title;
    if ((base.isEmpty || base.length < 3) &&
        itinerary['touristSpots'] is List &&
        (itinerary['touristSpots'] as List).isNotEmpty) {
      base = ((itinerary['touristSpots'] as List).first['name'] ?? '').toString();
    }

    final queries = <String, String>{
      'hotel': 'best hotels in $base',
      'restaurant': 'best restaurants in $base',
      'spot': 'top attractions in $base',
    };

    for (final entry in queries.entries) {
      final key = entry.key;
      final q = entry.value;
      try {
        final candidates = await _googleTextSearch(q, limit: 5);
        if (candidates.isEmpty) continue;
        final pick = await _groqPickOne(q, candidates);
        if (pick != null && mounted) {
          setState(() {
            _livePicks[key] = pick;
          });
        }
      } catch (_) {
        // ignore individual query failures
      }
    }
  }

  Future<List<Map<String, dynamic>>> _googleTextSearch(String query, {int limit = 5}) async {
    final uri = Uri.https('maps.googleapis.com', '/maps/api/place/textsearch/json', {
      'query': query,
      'key': _googleApiKey,
    });
    final resp = await http.get(uri);
    if (resp.statusCode != 200) return [];
    final data = jsonDecode(resp.body);
    if (data['status'] != 'OK' && data['status'] != 'ZERO_RESULTS') return [];
    final results = (data['results'] as List? ?? []).cast<dynamic>();
    return results.take(limit).map<Map<String, dynamic>>((r) => {
          'name': r['name'],
          'rating': (r['rating'] is num) ? (r['rating'] as num).toDouble() : null,
          'user_ratings_total': r['user_ratings_total'],
          'address': r['formatted_address'] ?? r['vicinity'],
          'place_id': r['place_id'],
          'lat': r['geometry']?['location']?['lat'],
          'lng': r['geometry']?['location']?['lng'],
        }).toList();
  }

  Future<Map<String, dynamic>?> _groqPickOne(String query, List<Map<String, dynamic>> candidates) async {
    try {
      final prompt = {
        'role': 'system',
        'content': 'You are a concise ranking assistant. Choose the single best candidate strictly based on relevance to the user query and overall quality (rating and number of reviews). Output only valid JSON: {"name":"","place_id":"","reason":"","rating":0,"user_ratings_total":0,"address":"","lat":0,"lng":0}',
      };
      final user = {
        'role': 'user',
        'content': jsonEncode({
          'query': query,
          'candidates': candidates,
        }),
      };
      const apiKey =
          ""; // same Groq key used above
      const url = "https://api.groq.com/openai/v1/chat/completions";
      final response = await http.post(
        Uri.parse(url),
        headers: {
          "Authorization": "Bearer $apiKey",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "model": "llama-3.3-70b-versatile",
          "messages": [prompt, user],
        }),
      );
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body);
      final reply = data["choices"][0]["message"]["content"];
      final jsonStr = _extractJson(reply) ?? reply;
      final parsed = jsonDecode(_repairJson(jsonStr));
      // Ensure required fields
      if (parsed is Map && parsed['name'] != null && parsed['place_id'] != null) {
        return parsed.cast<String, dynamic>();
      }
    } catch (_) {}
    return null;
  }

  Future<void> _saveItinerary() async {
    if (_response == null) return;
    try {
      final itineraryJson = jsonDecode(_response!);
      final itinerary = Itinerary()
        ..title = itineraryJson["title"] ?? "Untitled Trip"
        ..content = _response!
        ..createdAt = DateTime.now();
      await isar.writeTxn(() async {
        await isar.itinerarys.put(itinerary);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Itinerary saved successfully!")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to save itinerary: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.itinerary?.title ?? 'Plan Trip'),
        backgroundColor: const Color(0xFF2E6D4D),
        actions: [
          if (widget.itinerary != null)
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete),
              onPressed: _deleteCurrentItinerary,
            ),
        ],
      ),
      backgroundColor: const Color(0xFFF9F6F6),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _response != null
                  ? SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: _buildItineraryView(_response!),
                    )
                  : const Center(
                      child: Text(
                        "What’s your vision for this trip?",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _tripController,
                    decoration: const InputDecoration(
                      hintText: "Describe your trip...",
                      contentPadding: EdgeInsets.all(12),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () => _getTripPlan(),
                ),
                IconButton(
                  icon: const Icon(Icons.save),
                  onPressed: _saveItinerary,
                ),
              ],
            ),
            if (_response != null)
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _followUpController,
                      decoration: const InputDecoration(
                        hintText: "Ask follow-up...",
                        contentPadding: EdgeInsets.all(12),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: () {
                      final text = _followUpController.text.trim();
                      if (text.isNotEmpty) {
                        _getTripPlan(followUp: text);
                        _followUpController.clear();
                      }
                    },
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildItineraryView(String jsonStr) {
    final itinerary = jsonDecode(jsonStr);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          itinerary["title"],
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Text(
          "${itinerary["startDate"]} → ${itinerary["endDate"]}",
          style: const TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 12),

        // Live suggestions section
        if (_livePicks.isNotEmpty) ...[
          const Text(
            'Live suggestions',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          ...['hotel', 'restaurant', 'spot'].where((k) => _livePicks[k] != null).map((k) {
            final p = _livePicks[k]!;
            final mapsUrl = 'https://www.google.com/maps/place/?q=place_id:${p['place_id']}';
            return Card(
              child: ListTile(
                leading: Icon(k == 'hotel' ? Icons.hotel : k == 'restaurant' ? Icons.restaurant : Icons.place),
                title: Text(p['name'] ?? ''),
                subtitle: Text([
                  if (p['rating'] != null) 'Rating: ${p['rating']} (${p['user_ratings_total'] ?? 0})',
                  if (p['address'] != null) p['address'],
                ].whereType<String>().join('\n')),
                trailing: IconButton(
                  icon: const Icon(Icons.map),
                  onPressed: () => _launch(Uri.parse(mapsUrl)),
                ),
              ),
            );
          }),
          const SizedBox(height: 12),
        ],

        ...List.generate(itinerary["days"].length, (i) {
          final day = itinerary["days"][i];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Day ${i + 1}: ${day["summary"]}",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              ...day["items"].map<Widget>((item) {
                final loc = item["location"];
                final label = item["activity"];
                return ListTile(
                  onTap: () => _openInMaps(loc, label: label),
                  leading: Text(item["time"]),
                  title: Text(item["activity"]),
                  subtitle: Text(
                    loc,
                    style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.map),
                    onPressed: () => _openInMaps(loc, label: label),
                  ),
                );
              }),

              const Divider(),
            ],
          );
        }),

        if (itinerary["hotels"] != null && itinerary["hotels"].isNotEmpty) ...[
          const Text(
            "Hotels",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          ...itinerary["hotels"].map<Widget>((h) => ListTile(
            onTap: () => _openInMaps(h["location"], label: h["name"]),
            title: Text(h["name"]),
            subtitle: Text("₹${h["pricePerNight"]} • ${h["location"]}",
                style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline)),
            trailing: IconButton(
              icon: const Icon(Icons.map),
              onPressed: () => _openInMaps(h["location"], label: h["name"]),
            ),
          )),
        ],

        if (itinerary["touristSpots"] != null &&
            itinerary["touristSpots"].isNotEmpty) ...[
          const Text(
            "Tourist Spots",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          ...itinerary["touristSpots"].map<Widget>((s) => ListTile(
            onTap: () => _openInMaps(s["location"], label: s["name"]),
            title: Text(s["name"]),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s["description"]),
                Text(s["location"],
                    style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline)),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.map),
              onPressed: () => _openInMaps(s["location"], label: s["name"]),
            ),
          )),
        ],

        if (itinerary["food"] != null && itinerary["food"].isNotEmpty) ...[
          const Text(
            "Food",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          ...itinerary["food"].map<Widget>((f) => ListTile(
            onTap: () => _openInMaps(f["location"], label: f["name"]),
            title: Text(f["name"]),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("${f["cuisine"]} • ₹${f["avgCost"]}"),
                Text(f["location"],
                    style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline)),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.map),
              onPressed: () => _openInMaps(f["location"], label: f["name"]),
            ),
          )),
        ],

        if (itinerary["transportOptions"] != null &&
            itinerary["transportOptions"].isNotEmpty) ...[
          const Text(
            "Transport",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          ...itinerary["transportOptions"].map<Widget>(
            (t) => ListTile(
              title: Text("${t["mode"]} • ${t["provider"]}"),
              subtitle: Text("₹${t["approxCost"]} • ${t["duration"]}"),
            ),
          ),
        ],

        if (itinerary["estimatedBudget"] != null) ...[
          const Text(
            "Estimated Budget",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Text(
            "Accommodation: ₹${itinerary["estimatedBudget"]["accommodation"]}",
          ),
          Text("Food: ₹${itinerary["estimatedBudget"]["food"]}"),
          Text("Transport: ₹${itinerary["estimatedBudget"]["transport"]}"),
          Text("Activities: ₹${itinerary["estimatedBudget"]["activities"]}"),
          Text("Total: ₹${itinerary["estimatedBudget"]["total"]}"),
        ],

        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: () {
            String? destination;
            if (itinerary["touristSpots"] != null &&
                itinerary["touristSpots"].isNotEmpty) {
              destination = itinerary["touristSpots"].last["location"];
            } else if (itinerary["days"].isNotEmpty &&
                itinerary["days"].last["items"].isNotEmpty) {
              destination = itinerary["days"].last["items"].last["location"];
            }
            if (destination != null) {
              _openRouteInMaps(destination); // starts from current location
            }
          },
          icon: const Icon(Icons.directions),
          label: const Text("Open Route in Maps"),
        ),
      ],
    );
  }
}
