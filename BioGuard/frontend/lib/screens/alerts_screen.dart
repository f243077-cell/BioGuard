import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/theme.dart';
import '../models/alert.dart';
import '../providers/auth_provider.dart';
import '../services/api_exceptions.dart';
import '../services/websocket_service.dart';
import '../utils/alarm_player.dart';
import '../utils/time_format.dart';
import '../widgets/alert_banner.dart';
import '../widgets/glass.dart';

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
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(child: _buildList()),
          if (_bannerAlert != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AlertBanner(
                key: ValueKey('${_bannerAlert!.id}-${_bannerAlert!.resolved}'),
                alert: _bannerAlert!,
                onDismiss: () => setState(() => _bannerAlert = null),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildList() {
    final insets = MediaQuery.paddingOf(context);

    final Widget content;
    if (_loadingHistory && _alerts.isEmpty) {
      content = const Padding(
        padding: EdgeInsets.only(top: 80),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (_historyError != null && _alerts.isEmpty) {
      content = EmptyState(
        icon: Icons.cloud_off_rounded,
        color: AppColors.danger,
        title: 'Failed to load alert history',
        message: _historyError,
        onRetry: _loadHistory,
      );
    } else if (_alerts.isEmpty) {
      content = EmptyState(
        icon: Icons.notifications_none_rounded,
        title: _connected ? 'No alerts yet' : 'Waiting to reconnect…',
        message: _connected
            ? 'You will be notified here the moment something goes wrong.'
            : null,
      );
    } else {
      content = Column(children: _alerts.map(_buildAlertTile).toList());
    }

    return RefreshIndicator(
      onRefresh: _loadHistory,
      edgeOffset: insets.top,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          16,
          insets.top + 16,
          16,
          insets.bottom + 24,
        ),
        children: [_buildStatusHeader(), const SizedBox(height: 20), content],
      ),
    );
  }

  Widget _buildStatusHeader() {
    final active = _alerts.where((a) => !a.resolved).length;
    final resolved = _alerts.length - active;

    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      borderRadius: 20,
      tint: _connected ? null : AppColors.warning,
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: LiveIndicator(active: _connected),
            ),
          ),
          if (_alerts.isNotEmpty) ...[
            _CountBadge(
              label: '$active active',
              color: active > 0 ? AppColors.danger : AppColors.textMuted,
            ),
            const SizedBox(width: 6),
            _CountBadge(label: '$resolved resolved', color: AppColors.success),
          ],
        ],
      ),
    );
  }

  Widget _buildAlertTile(Alert alert) {
    final isCritical = alert.severity == 'critical';
    final color = alert.resolved
        ? AppColors.success
        : (isCritical ? AppColors.danger : AppColors.warning);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassPanel(
        padding: const EdgeInsets.all(16),
        borderRadius: 20,
        tint: !alert.resolved && isCritical ? AppColors.danger : null,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconTile(
              icon: alert.resolved
                  ? Icons.check_circle_rounded
                  : Icons.warning_amber_rounded,
              color: color,
              size: 40,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          alert.deviceId,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        timeAgo(alert.createdAt),
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    alert.message,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13.5,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 10),
                  StatusPill(
                    label: alert.resolved ? 'Resolved' : alert.severity,
                    color: color,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
