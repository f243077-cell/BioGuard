import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/alert.dart';

/// BioGuard — WebSocket Service
/// Connects to the backend's /ws/alerts endpoint and exposes a stream of Alerts.
///
/// NOTE: base URL mirrors api_service.dart — 10.0.2.2 for the Android emulator.
class WebSocketService {
  static const String _wsUrl = 'ws://10.0.2.2:8000/ws/alerts';

  WebSocketChannel? _channel;
  final StreamController<Alert> _alertController =
      StreamController<Alert>.broadcast();

  Stream<Alert> get alerts => _alertController.stream;

  void connect() {
    _channel = WebSocketChannel.connect(Uri.parse(_wsUrl));
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
