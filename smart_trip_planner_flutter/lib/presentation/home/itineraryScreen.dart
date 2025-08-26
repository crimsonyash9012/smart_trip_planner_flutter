import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../core/constants.dart';
import '../../core/error_utils.dart';
import '../../core/utils.dart';
import '../../data/model/itinerary.dart';
import '../../main.dart';




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
  Map<String, Map<String, dynamic>> _livePicks = {};

  bool _offline = false;
  StreamSubscription<List<ConnectivityResult>>? _connSub;

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
      try {
        await isar.writeTxn(() async {
          await isar.itinerarys.delete(it.id);
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Itinerary deleted')),
        );
        Navigator.of(context).pop();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete itinerary: $e')),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _messages = [
      {"role": "system", "content": systemPrompt},
    ];
    ErrorUtils.hasConnectivity().then((has) {
      if (mounted) setState(() => _offline = !has);
    });
    _connSub = Connectivity().onConnectivityChanged.listen((results) {
      // results
      final off = results.contains(ConnectivityResult.none);
      if (mounted) setState(() => _offline = off);
    });
    if (widget.itinerary != null) {
      _response = widget.itinerary!.content;
      _tripController.text = widget.itinerary!.title;
      _messages.addAll([
        {"role": "user", "content": widget.itinerary!.title},
        {"role": "assistant", "content": _response!},
      ]);
      try {
        final itJson = jsonDecode(_response!);
        _runLiveSearches(itJson);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _connSub?.cancel();
    super.dispose();
  }

  Future<void> _getTripPlan({String? followUp}) async {
    if (followUp == null && _tripController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please describe your trip first.')),
      );
      return;
    }

    if (!await ErrorUtils.hasConnectivity()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No internet connection.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    const apiKey = groqApiKey;
    const url = groqUrl;

    if (followUp == null) {
      _messages.add({"role": "user", "content": _tripController.text.trim()});
    } else {
      _messages.add({"role": "user", "content": followUp});
    }

    try {
      final response = await ErrorUtils.withTimeout(http.post(
        Uri.parse(url),
        headers: {
          "Authorization": "Bearer $apiKey",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "model": "llama-3.3-70b-versatile",
          "messages": _messages,
        }),
      ));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data.containsKey("error")) {
          setState(() {
            _response = "API Error: ${data["error"]["message"]}";
          });
          return;
        }

        final reply = data["choices"][0]["message"]["content"];
        final jsonStr = extractJson(reply);

        if (jsonStr != null) {
          try {
            final itineraryJson = jsonDecode(jsonStr);
            setState(() {
              _response = jsonEncode(itineraryJson);
              _messages.add({"role": "assistant", "content": _response!});
            });
            _runLiveSearches(itineraryJson);
          } catch (_) {
            try {
              final repaired = repairJson(jsonStr);
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
        final msg = ErrorUtils.httpStatusMessage(response.statusCode);
        setState(() => _response = "Error: $msg\n${response.body}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } on TimeoutException {
      setState(() => _response = "Error: Request timed out.");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request timed out. Please try again.')),
      );
    } catch (e) {
      setState(() => _response = "Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to get trip plan.')),
      );
    }

    setState(() => _isLoading = false);
  }

  Future<void> _runLiveSearches(Map<String, dynamic> itinerary) async {
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
      }
    }
  }

  Future<List<Map<String, dynamic>>> _googleTextSearch(String query, {int limit = 5}) async {
    if (!await ErrorUtils.hasConnectivity()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No internet connection.')),
      );
      return [];
    }
    final uri = Uri.https('maps.googleapis.com', '/maps/api/place/textsearch/json', {
      'query': query,
      'key': googleApiKey,
    });
    final resp = await ErrorUtils.withTimeout(http.get(uri));
    if (resp.statusCode != 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorUtils.httpStatusMessage(resp.statusCode, provider: 'google'))),
      );
      return [];
    }
    final data = jsonDecode(resp.body);
    if (data['status'] != 'OK' && data['status'] != 'ZERO_RESULTS') {

        String status = ErrorUtils.googlePlacesStatusMessage(data['status']);
        if(status == null || status == ''){
          // ScaffoldMessenger.of(context).showSnackBar(
          // SnackBar(content: Text(ErrorUtils.googlePlacesStatusMessage(data['status'].toString()))));
        }
        else{
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(ErrorUtils.googlePlacesStatusMessage(data['status'].toString()))),
          );
        }
      return [];
    }
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
      const apiKey = groqApiKey;
      const url = groqUrl;
      if (!await ErrorUtils.hasConnectivity()) return null;

      final response = await ErrorUtils.withTimeout(http.post(
        Uri.parse(url),
        headers: {
          "Authorization": "Bearer $apiKey",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "model": "llama-3.3-70b-versatile",
          "messages": [prompt, user],
        }),
      ));
      if (response.statusCode != 200) {
        return null;
      }
      final data = jsonDecode(response.body);
      final reply = data["choices"][0]["message"]["content"];
      final jsonStr = extractJson(reply) ?? reply;
      Map<String, dynamic> parsed;
      try {
        parsed = jsonDecode(repairJson(jsonStr));
      } catch (_) {
        return null;
      }
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

      final existing = widget.itinerary;

      final itinerary = existing ?? Itinerary()
        ..createdAt = DateTime.now();

      itinerary
        ..title = itineraryJson["title"] ?? "Untitled Trip"
        ..content = _response!;

      await isar.writeTxn(() async {
        await isar.itinerarys.put(itinerary);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(existing == null
                ? "Itinerary saved successfully!"
                : "Itinerary updated successfully!"),
          ),
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
        title: Text(widget.itinerary?.title ?? 'Plan Trip', style: TextStyle(color: Colors.white),),
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
            if (_offline)
              Container(
                width: double.infinity,
                color: Colors.red.shade600,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: const Text(
                  'You are offline. Some features are unavailable.',
                  style: TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
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
            if (_response == null)
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
                    onPressed: _offline
                        ? () => ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('You are offline. Please reconnect.')),
                            )
                        : () => _getTripPlan(),
                  ),
                ],
              )
            else
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
                    onPressed: _offline
                        ? () => ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('You are offline. Please reconnect.')),
                            )
                        : () {
                            final text = _followUpController.text.trim();
                            if (text.isNotEmpty) {
                              _getTripPlan(followUp: text);
                              _followUpController.clear();
                            }
                          },
                  ),
                  IconButton(
                    icon: const Icon(Icons.save),
                    onPressed: _saveItinerary,
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

        if (_livePicks.isNotEmpty) ...[
          const Text(
            'Live suggestions',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          ...['hotel', 'restaurant', 'spot'].where((k) => _livePicks[k] != null).map((k) {
            final p = _livePicks[k]!;
            return Card(
              child: ListTile(
                leading: Icon(k == 'hotel' ? Icons.hotel : k == 'restaurant' ? Icons.restaurant : Icons.place),
                title: Text(p['name'] ?? ''),
                subtitle: Text([
                  if (p['rating'] != null) 'Rating: ${p['rating']} (${p['user_ratings_total'] ?? 0})',
                  if (p['address'] != null) p['address'],
                ].whereType<String>().join('\n')),
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
                  leading: Text(item["time"]),
                  title: Text(item["activity"]),
                  subtitle: Text(
                    loc,
                    style: const TextStyle(color: Colors.black87),
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
            title: Text(h["name"]),
            subtitle: Text("₹${h["pricePerNight"]} • ${h["location"]}",
                style: const TextStyle(color: Colors.black87)),
          )),
        ],

        if (itinerary["touristSpots"] != null &&
            itinerary["touristSpots"].isNotEmpty) ...[
          const Text(
            "Tourist Spots",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          ...itinerary["touristSpots"].map<Widget>((s) => ListTile(
            title: Text(s["name"]),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s["description"]),
                Text(s["location"],
                    style: const TextStyle(color: Colors.black87)),
              ],
            ),
          )),
        ],

        if (itinerary["food"] != null && itinerary["food"].isNotEmpty) ...[
          const Text(
            "Food",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          ...itinerary["food"].map<Widget>((f) => ListTile(
            title: Text(f["name"]),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("${f["cuisine"]} • ₹${f["avgCost"]}"),
                Text(f["location"],
                    style: const TextStyle(color: Colors.black87)),
              ],
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
            final title = itinerary['title']?.toString() ?? '';
            final cities = extractCitiesFromTitle(title);
            
            final origin = findOrigin(itinerary);
            final dest = findDestination(itinerary);
            
            openRouteInMaps(
              context,
              originCity: cities?.first,
              destCity: cities?.last,
              originLat: origin?.elementAt(0),
              originLng: origin?.elementAt(1),
              destLat: dest?.elementAt(0),
              destLng: dest?.elementAt(1),
            );
          },
          icon: const Icon(Icons.directions),
          label: const Text("Open Route in Maps"),
        ),
      ],
    );
  }
}
