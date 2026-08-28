import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/alert.dart';
import '../providers/auth_provider.dart';
import '../services/api_exceptions.dart';
import '../services/websocket_service.dart';
import '../utils/alarm_player.dart';
import '../widgets/alert_banner.dart';

/// BioGuard — Alerts Screen
/// Loads alert history via REST on open, then live-updates over WebSocket.
/// Alerts already in history get their state updated in place (e.g. a
/// warning flipping to resolved) rather than duplicated.
class AlertsScreen extends ConsumerStatefulWidget {
  const AlertsScreen({super.key});

  @override
  ConsumerState<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends ConsumerState<AlertsScreen> {
  WebSocketService? _wsService;
  final AlarmPlayer _alarmPlayer = AlarmPlayer();
  final List<Alert> _alerts = [];
  Alert? _bannerAlert;
  bool _connected = false;
  bool _loadingHistory = true;
  String? _historyError;

  @override
  void initState() {
    super.initState();
    _loadHistory();

    _wsService = WebSocketService(
      tokenStorage: ref.read(tokenStorageProvider),
      onUnauthorized: () => ref.read(authProvider.notifier).logout(),
    );
    _wsService!.connect();
    _wsService!.connectionState.listen((connected) {
      if (!mounted) return;
      setState(() => _connected = connected);
    });
    _wsService!.alerts.listen((alert) {
      if (!mounted) return;
      setState(() {
        _upsertAlert(alert);
        _bannerAlert = alert;
      });
      if (alert.severity == 'critical' && !alert.resolved) {
        _alarmPlayer.play();
      }
    });
  }

  Future<void> _loadHistory() async {
    setState(() {
      _loadingHistory = true;
      _historyError = null;
    });

    try {
      final history = await ref.read(apiServiceProvider).fetchAlerts();
      if (!mounted) return;
      setState(() {
        // History comes most-recent-first from the backend already.
        for (final alert in history) {
          _upsertAlert(alert);
        }
        _loadingHistory = false;
      });
    } on UnauthorizedException {
      if (!mounted) return;
      await ref.read(authProvider.notifier).logout();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _historyError = e.toString();
        _loadingHistory = false;
      });
    }
  }

  /// Inserts a new alert, or replaces an existing one with the same id
  /// (e.g. a live update flipping resolved: false -> true) in place,
  /// keeping the list sorted most-recent-first by createdAt.
  void _upsertAlert(Alert alert) {
    final existingIndex = _alerts.indexWhere((a) => a.id == alert.id);
    if (existingIndex != -1) {
      _alerts[existingIndex] = alert;
    } else {
      _alerts.add(alert);
    }
    _alerts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  void dispose() {
    _wsService?.dispose();
    _alarmPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6A11CB), Color(0xFF2575FC), Color(0xFF00C9A7)],
          ),
        ),
        child: Stack(
          children: [
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Alerts',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (!_connected)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orangeAccent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.orangeAccent.withValues(alpha: 0.5),
                        ),
                      ),
                      child: const Row(
                        children: [
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.orangeAccent,
                            ),
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Reconnecting to live alerts…',
                            style: TextStyle(
                              color: Colors.orangeAccent,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  Expanded(child: _buildList()),
                ],
              ),
            ),
            if (_bannerAlert != null)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: AlertBanner(
                  key: ValueKey(
                    '${_bannerAlert!.id}-${_bannerAlert!.resolved}',
                  ),
                  alert: _bannerAlert!,
                  onDismiss: () => setState(() => _bannerAlert = null),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_loadingHistory && _alerts.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    if (_historyError != null && _alerts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Failed to load alert history:\n$_historyError',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadHistory,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (_alerts.isEmpty) {
      return Center(
        child: Text(
          _connected ? 'No alerts yet.' : 'Waiting to reconnect…',
          style: const TextStyle(color: Colors.white70),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadHistory,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _alerts.length,
        itemBuilder: (context, index) => _buildAlertTile(_alerts[index]),
      ),
    );
  }

  Widget _buildAlertTile(Alert alert) {
    final isCritical = alert.severity == 'critical';
    final color = alert.resolved
        ? Colors.greenAccent
        : (isCritical ? Colors.redAccent : Colors.orangeAccent);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Icon(
                  alert.resolved
                      ? Icons.check_circle
                      : Icons.warning_amber_rounded,
                  color: color,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alert.deviceId,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        alert.message,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        alert.resolved
                            ? 'Resolved'
                            : alert.severity.toUpperCase(),
                        style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
