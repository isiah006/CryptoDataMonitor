import 'dart:convert';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/cryptoquant_model.dart';

class CryptoQuantApiService {
  static String? _customBaseUrl;
  static String? _deviceId;

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
      String url = _customBaseUrl!.trim();
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        url = 'https://$url';
      }
      return url;
    }
    return defaultBaseUrl;
  }

  static Future<String> getOrCreateDeviceId() async {
    if (_deviceId != null && _deviceId!.isNotEmpty) return _deviceId!;
    try {
      final prefs = await SharedPreferences.getInstance();
      var id = prefs.getString('device_unique_id');
      if (id == null || id.isEmpty) {
        id = 'dev_${DateTime.now().millisecondsSinceEpoch}_${(1000 + (DateTime.now().microsecondsSinceEpoch % 8999))}';
        await prefs.setString('device_unique_id', id);
      }
      _deviceId = id;
      return id;
    } catch (_) {
      _deviceId = 'default_device';
      return _deviceId!;
    }
  }

  static Future<Map<String, String>> get _headers async {
    final devId = await getOrCreateDeviceId();
    return {
      'X-Device-ID': devId,
      'Accept': 'application/json',
    };
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
      String trimmed = newUrl.trim();
      if (trimmed.isNotEmpty && !trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
        trimmed = 'https://$trimmed';
      }
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
        headers: await _headers,
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode != 200) {
        throw Exception(
          'Server error: ${response.statusCode}. Check if backend is running at $baseUrl',
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
      if (e.toString().contains('Connection refused') || e.toString().contains('SocketException') || e.toString().contains('TimeoutException')) {
        throw Exception('Server unreachable or waking up at $baseUrl. Check URL in Settings or try again.');
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
        headers: await _headers,
      ).timeout(const Duration(seconds: 15));

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
        headers: await _headers,
      ).timeout(const Duration(seconds: 15));
    } catch (_) {}
  }
}
