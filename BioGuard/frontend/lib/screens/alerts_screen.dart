import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/alert.dart';
import '../providers/auth_provider.dart';
import '../services/websocket_service.dart';
import '../utils/alarm_player.dart';
import '../widgets/alert_banner.dart';

/// BioGuard — Alerts Screen
/// Live-updating list of alerts received over the WebSocket connection.
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

  @override
  void initState() {
    super.initState();
    _wsService = WebSocketService(
      tokenStorage: ref.read(tokenStorageProvider),
    );
    _wsService!.connect();
    _wsService!.alerts.listen((alert) {
      if (!mounted) return;
      setState(() {
        _alerts.insert(0, alert);
        _bannerAlert = alert;
      });
      if (alert.severity == 'critical' && !alert.resolved) {
        _alarmPlayer.play();
      }
    });
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
                  Expanded(
                    child: _alerts.isEmpty
                        ? const Center(
                            child: Text(
                              'No alerts yet.',
                              style: TextStyle(color: Colors.white70),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _alerts.length,
                            itemBuilder: (context, index) =>
                                _buildAlertTile(_alerts[index]),
                          ),
                  ),
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
