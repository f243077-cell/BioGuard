import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/constants.dart';
import '../models/device.dart';
import '../models/reading.dart';
import 'token_storage.dart';
import 'api_exceptions.dart';
import '../models/alert.dart';

/// BioGuard — API Service
/// REST calls to the backend's device endpoints. See AppConfig.apiBaseUrl
/// for how to point this at a real backend instead of the Android
/// emulator's loopback address.
class ApiService {
  static const String apiBaseUrl = AppConfig.apiBaseUrl;

  ApiService({required TokenStorage tokenStorage})
    : _tokenStorage = tokenStorage;

  final TokenStorage _tokenStorage;

  Future<Map<String, String>> _authHeaders() async {
    final token = await _tokenStorage.getToken();
    if (token == null) return {};
    return {'Authorization': 'Bearer $token'};
  }

  Future<List<Device>> fetchDevices() async {
    final response = await http.get(
      Uri.parse('$apiBaseUrl/devices'),
      headers: await _authHeaders(),
    );

    if (response.statusCode == 401) {
      throw UnauthorizedException();
    }
    if (response.statusCode != 200) {
      throw ApiException(
        'Failed to load devices',
        statusCode: response.statusCode,
      );
    }

    final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((json) => Device.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<List<Alert>> fetchAlerts({
    String? deviceId,
    bool? resolved,
    int limit = 100,
  }) async {
    final query = {
      'limit': limit.toString(),
      if (deviceId != null) 'device_id': deviceId,
      if (resolved != null) 'resolved': resolved.toString(),
    };
    final uri = Uri.parse('$apiBaseUrl/alerts').replace(queryParameters: query);
    final response = await http.get(uri, headers: await _authHeaders());

    if (response.statusCode == 401) {
      throw UnauthorizedException();
    }
    if (response.statusCode != 200) {
      throw ApiException(
        'Failed to load alerts',
        statusCode: response.statusCode,
      );
    }

    final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((json) => Alert.fromJson(json as Map<String, dynamic>))
        .toList();
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
    final uri = Uri.parse(
      '$apiBaseUrl/devices/$deviceId/history',
    ).replace(queryParameters: query);
    final response = await http.get(uri, headers: await _authHeaders());

    if (response.statusCode == 401) {
      throw UnauthorizedException();
    }
    if (response.statusCode != 200) {
      throw ApiException(
        'Failed to load history',
        statusCode: response.statusCode,
      );
    }

    final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((json) => Reading.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}
