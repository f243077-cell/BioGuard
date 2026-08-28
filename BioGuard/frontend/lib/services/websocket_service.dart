import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/alert.dart';
import 'token_storage.dart';

/// BioGuard — WebSocket Service
/// Connects to the backend's /ws/alerts endpoint and exposes a stream of Alerts.
/// Reconnects automatically with backoff on drops/errors. A server-sent close
/// code of 4401 means the token was rejected outright — that calls
/// onUnauthorized instead of retrying, since retrying against a token that
/// will never become valid is pointless.
class WebSocketService {
  static const String _wsBaseUrl = 'ws://10.0.2.2:8000/ws/alerts';
  static const int _unauthorizedCloseCode = 4401;
  static const List<Duration> _backoffSchedule = [
    Duration(seconds: 2),
    Duration(seconds: 4),
    Duration(seconds: 8),
    Duration(seconds: 16),
    Duration(seconds: 30),
  ];

  WebSocketService({required TokenStorage tokenStorage, this.onUnauthorized})
    : _tokenStorage = tokenStorage;

  final TokenStorage _tokenStorage;

  /// Called when there's no token locally, or the server rejected it
  /// (close code 4401) — caller should log the user out.
  final void Function()? onUnauthorized;

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  final StreamController<Alert> _alertController =
      StreamController<Alert>.broadcast();
  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();

  int _retryCount = 0;
  bool _manuallyDisconnected = false;

  Stream<Alert> get alerts => _alertController.stream;

  /// Emits true once connected, false while disconnected/reconnecting.
  Stream<bool> get connectionState => _connectionController.stream;

  Future<void> connect() async {
    _manuallyDisconnected = false;
    await _attemptConnect();
  }

  Future<void> _attemptConnect() async {
    final token = await _tokenStorage.getToken();
    if (token == null) {
      onUnauthorized?.call();
      return;
    }

    final uri = Uri.parse(
      _wsBaseUrl,
    ).replace(queryParameters: {'token': token});

    try {
      final channel = WebSocketChannel.connect(uri);
      await channel.ready; // throws if the handshake itself fails
      _channel = channel;
      _retryCount = 0;
      _connectionController.add(true);

      _subscription = channel.stream.listen(
        (data) {
          final json = jsonDecode(data as String) as Map<String, dynamic>;
          _alertController.add(Alert.fromJson(json));
        },
        onError: (_) => _handleDisconnect(),
        onDone: () {
          if (_channel?.closeCode == _unauthorizedCloseCode) {
            _connectionController.add(false);
            onUnauthorized?.call();
          } else {
            _handleDisconnect();
          }
        },
      );
    } catch (_) {
      _handleDisconnect();
    }
  }

  void _handleDisconnect() {
    _connectionController.add(false);
    if (_manuallyDisconnected) return;

    final delay =
        _backoffSchedule[_retryCount.clamp(0, _backoffSchedule.length - 1)];
    _retryCount++;
    Future.delayed(delay, () {
      if (!_manuallyDisconnected) _attemptConnect();
    });
  }

  void disconnect() {
    _manuallyDisconnected = true;
    _subscription?.cancel();
    _channel?.sink.close();
  }

  void dispose() {
    disconnect();
    _alertController.close();
    _connectionController.close();
  }
}
