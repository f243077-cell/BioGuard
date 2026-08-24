import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/device.dart';
import '../models/reading.dart';

/// BioGuard — API Service
/// REST calls to the backend's device endpoints.
///
/// NOTE: base URL is inlined here for now — this moves into
/// config/constants.dart once WebSocket + FCM configs join it in later phases.
/// Android emulator -> host machine is 10.0.2.2, NOT localhost.
/// Physical device / iOS simulator: replace with your machine's LAN IP.
class ApiService {
  static const String apiBaseUrl = 'http://10.0.2.2:8000';

  Future<List<Device>> fetchDevices() async {
    final response = await http.get(Uri.parse('$apiBaseUrl/devices'));

    if (response.statusCode != 200) {
      throw Exception('Failed to load devices (${response.statusCode})');
    }

    final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
    return data.map((json) => Device.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<List<Reading>> fetchDeviceHistory(
    String deviceId, {
    String? readingType,
    int limit = 100,
  }) async {
    final query = {
      'limit': limit.toString(),
      if (readingType != null) 'reading_type': readingType,
    };
    final uri = Uri.parse('$apiBaseUrl/devices/$deviceId/history')
        .replace(queryParameters: query);
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Failed to load history (${response.statusCode})');
    }

    final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
    return data.map((json) => Reading.fromJson(json as Map<String, dynamic>)).toList();
  }
}