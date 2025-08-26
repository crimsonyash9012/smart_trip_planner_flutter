
import 'dart:async';
import 'package:flutter/material.dart';

import 'error_utils.dart';

bool isInternationalRoute(String? origin, String? dest) {
  if (origin == null || dest == null) return false;

  final internationalCities = {
    'dubai', 'singapore', 'london', 'paris', 'tokyo', 'bangkok', 'kuala lumpur',
    'hong kong', 'new york', 'los angeles', 'sydney', 'melbourne', 'toronto',
    'vancouver', 'amsterdam', 'frankfurt', 'zurich', 'istanbul', 'doha', 'abu dhabi'
  };

  final originLower = origin.toLowerCase();
  final destLower = dest.toLowerCase();

  return internationalCities.contains(originLower) || internationalCities.contains(destLower);
}

void snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: const TextStyle(color: Colors.white, fontSize: 15),
      ),
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.black87,
      margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      duration: const Duration(seconds: 3),
    ),
  );
}


String? extractJson(String text) {
  final start = text.indexOf("{");
  final end = text.lastIndexOf("}");
  if (start != -1 && end != -1 && end > start) {
    return text.substring(start, end + 1);
  }
  return null;
}

String repairJson(String jsonStr) {
  return jsonStr
      .replaceAllMapped(RegExp(r'"(\w+)"\s*,\s*'), (m) => '"${m[1]}": ')
      .replaceAll(",}", "}")
      .replaceAll(",]", "]");
}

Future<void> openRouteInMaps(BuildContext context, {String? originCity, String? destCity, double? originLat, double? originLng, double? destLat, double? destLng}) async {
  String searchQuery;

  if (originCity != null && destCity != null) {
    searchQuery = '$originCity to $destCity route';
  } else {
    final origin = (originLat != null && originLng != null) ? '$originLat,$originLng' : 'current location';
    final dest = (destLat != null && destLng != null) ? '$destLat,$destLng' : 'destination';
    searchQuery = '$origin to $dest route';
  }

  final uri = Uri.https('www.google.com', '/search', {'q': searchQuery});
  await ErrorUtils.openUrlOrSnack(context, uri);
}

List<double>? parseLatLng(String? s) {
  if (s == null) return null;
  final parts = s.split(',');
  if (parts.length != 2) return null;
  final lat = double.tryParse(parts[0].trim());
  final lng = double.tryParse(parts[1].trim());
  if (lat == null || lng == null) return null;
  return [lat, lng];
}

List<double>? findOrigin(Map<String, dynamic> it) {
  try {
    if (it['hotels'] is List && (it['hotels'] as List).isNotEmpty) {
      final s = (it['hotels'] as List).first['location']?.toString();
      final p = parseLatLng(s);
      if (p != null) return p;
    }
    if (it['days'] is List && (it['days'] as List).isNotEmpty) {
      final items = ((it['days'] as List).first)['items'] as List?;
      if (items != null && items.isNotEmpty) {
        final s = items.first['location']?.toString();
        final p = parseLatLng(s);
        if (p != null) return p;
      }
    }
    if (it['touristSpots'] is List && (it['touristSpots'] as List).isNotEmpty) {
      final s = (it['touristSpots'] as List).first['location']?.toString();
      final p = parseLatLng(s);
      if (p != null) return p;
    }
  } catch (_) {}
  return null;
}

List<double>? findDestination(Map<String, dynamic> it) {
  try {
    if (it['touristSpots'] is List && (it['touristSpots'] as List).isNotEmpty) {
      final s = (it['touristSpots'] as List).last['location']?.toString();
      final p = parseLatLng(s);
      if (p != null) return p;
    }
    if (it['days'] is List && (it['days'] as List).isNotEmpty) {
      final lastDay = (it['days'] as List).last as Map;
      final items = lastDay['items'] as List?;
      if (items != null && items.isNotEmpty) {
        final s = items.last['location']?.toString();
        final p = parseLatLng(s);
        if (p != null) return p;
      }
    }
  } catch (_) {}
  return null;
}

List<String>? extractCitiesFromTitle(String title) {
  final lowerTitle = title.toLowerCase();
  final patterns = [
    RegExp(r'(\w+)\s+to\s+(\w+)', caseSensitive: false),
    RegExp(r'from\s+(\w+)\s+to\s+(\w+)', caseSensitive: false),
    RegExp(r'(\w+)\s*-\s*(\w+)', caseSensitive: false),
  ];

  for (final pattern in patterns) {
    final match = pattern.firstMatch(title);
    if (match != null && match.groupCount >= 2) {
      return [match.group(1)!, match.group(2)!];
    }
  }
  return null;
}
