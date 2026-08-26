import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/alert.dart';
import 'token_storage.dart';

/// BioGuard — WebSocket Service
/// Connects to the backend's /ws/alerts endpoint and exposes a stream of Alerts.
///
/// NOTE: base URL mirrors api_service.dart — 10.0.2.2 for the Android emulator.
class WebSocketService {
  static const String _wsBaseUrl = 'ws://10.0.2.2:8000/ws/alerts';

  WebSocketService({required TokenStorage tokenStorage})
      : _tokenStorage = tokenStorage;

  final TokenStorage _tokenStorage;

  WebSocketChannel? _channel;
  final StreamController<Alert> _alertController =
      StreamController<Alert>.broadcast();

  Stream<Alert> get alerts => _alertController.stream;

  Future<void> connect() async {
    final token = await _tokenStorage.getToken();
    final uri = Uri.parse(_wsBaseUrl).replace(
      queryParameters: token != null ? {'token': token} : null,
    );

    _channel = WebSocketChannel.connect(uri);
    _channel!.stream.listen(
      (data) {
        final json = jsonDecode(data as String) as Map<String, dynamic>;
        _alertController.add(Alert.fromJson(json));
      },
      onError: (error) => print('[BioGuard] WebSocket error: $error'),
      onDone: () => print('[BioGuard] WebSocket closed'),
    );
  }

  void disconnect() {
    _channel?.sink.close();
  }

  void dispose() {
    disconnect();
    _alertController.close();
  }
}
