import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ErrorUtils {
  static Future<bool> hasConnectivity() async {
    try {
      final result = await Connectivity().checkConnectivity();
      return result != ConnectivityResult.none;
    } catch (_) {
      return false;
    }
  }

  static Future<T> withTimeout<T>(Future<T> future, {Duration timeout = const Duration(seconds: 15)}) async {
    return future.timeout(timeout);
  }

  static String httpStatusMessage(int status, {String? provider}) {
    switch (status) {
      case 401:
      case 403:
        return provider == 'google' ? 'Invalid or unauthorized API key for Google.' : 'Unauthorized/Forbidden. Check API key or access.';
      case 429:
        return 'Rate limit reached. Please try again later.';
      case 500:
      case 502:
      case 503:
      case 504:
        return 'Server error. Please try again later.';
      default:
        return 'Unexpected server response ($status).';
    }
  }

  static String googlePlacesStatusMessage(String status) {
    switch (status) {
      // case 'REQUEST_DENIED':
      //   return 'Google Places request denied. Check API key and quotas.';
      case 'OVER_QUERY_LIMIT':
        return 'Google Places daily limit reached.';
      case 'INVALID_REQUEST':
        return 'Google Places invalid request.';
      case 'ZERO_RESULTS':
        return 'No live results found.';
      default:
        return '';
    }
  }

  static Future<void> openUrlOrSnack(BuildContext context, Uri uri) async {
    try {
      var ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) {
        ok = await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
      if (!ok) {
        _snack(context, 'Unable to open the link.');
      }
    } catch (_) {
      _snack(context, 'Failed to launch the link.');
    }
  }

  static void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }
}
