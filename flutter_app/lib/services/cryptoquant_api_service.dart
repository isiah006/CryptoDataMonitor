import 'dart:convert';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/cryptoquant_model.dart';

class CryptoQuantApiService {
  static String? _customBaseUrl;

  static String get defaultBaseUrl {
    if (kIsWeb) {
      return 'http://localhost:3000';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://192.168.100.36:3000';
    }
    return 'http://localhost:3000';
  }

  static String get baseUrl {
    if (_customBaseUrl != null && _customBaseUrl!.trim().isNotEmpty) {
      return _customBaseUrl!.trim();
    }
    return defaultBaseUrl;
  }

  static Future<void> loadCustomBaseUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _customBaseUrl = prefs.getString('custom_server_url');
    } catch (_) {}
  }

  static Future<void> setCustomBaseUrl(String newUrl) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final trimmed = newUrl.trim();
      if (trimmed.isEmpty || trimmed == defaultBaseUrl) {
        _customBaseUrl = null;
        await prefs.remove('custom_server_url');
      } else {
        _customBaseUrl = trimmed;
        await prefs.setString('custom_server_url', trimmed);
      }
    } catch (_) {}
  }

  static Future<CryptoQuantModel> getBTCData() async {
    await loadCustomBaseUrl();
    try {
      final cleanBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
      final response = await http.get(
        Uri.parse('$cleanBase/cryptoquant/btc'),
      ).timeout(const Duration(seconds: 25));

      if (response.statusCode != 200) {
        throw Exception(
          'Server error: ${response.statusCode}. Check if backend is reachable at $baseUrl',
        );
      }

      final json = jsonDecode(response.body);

      if (json['success'] != true) {
        throw Exception(
          json['message'] ?? 'Failed to fetch BTC data',
        );
      }

      return CryptoQuantModel.fromJson(json);
    } catch (e) {
      if (e.toString().contains('Connection refused') || e.toString().contains('SocketException')) {
        throw Exception('Server unreachable at $baseUrl. Check server status or settings.');
      }
      rethrow;
    }
  }

  static Future<CryptoQuantModel?> getCachedBTCData() async {
    await loadCustomBaseUrl();
    try {
      final cleanBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
      final response = await http.get(
        Uri.parse('$cleanBase/cryptoquant/cached-btc'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return null;
      }

      final json = jsonDecode(response.body);
      if (json['success'] != true) return null;

      return CryptoQuantModel.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearBackendStorage() async {
    await loadCustomBaseUrl();
    try {
      final cleanBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
      await http.delete(
        Uri.parse('$cleanBase/cryptoquant/clear-storage'),
      ).timeout(const Duration(seconds: 10));
    } catch (_) {}
  }
}
