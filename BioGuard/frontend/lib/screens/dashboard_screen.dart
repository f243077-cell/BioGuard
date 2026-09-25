import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/theme.dart';
import '../models/device.dart';
import '../providers/auth_provider.dart';
import '../services/api_exceptions.dart';
import '../utils/time_format.dart';
import '../widgets/glass.dart';

/// BioGuard — Dashboard Screen
/// Polls the backend every few seconds and shows a fleet summary plus each
/// device's live status as a frosted glass card.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  Timer? _pollTimer;

  List<Device> _devices = [];
  bool _loading = true;
  String? _error;

  static const _pollInterval = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _loadDevices();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _loadDevices());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadDevices() async {
    try {
      final devices = await ref.read(apiServiceProvider).fetchDevices();
      if (!mounted) return;
      setState(() {
        _devices = devices;
        _loading = false;
        _error = null;
      });
    } on UnauthorizedException {
      // Token is dead — stop polling immediately so we don't keep hitting
      // a 401 in a loop, then log out. Whatever watches authProvider's
      // state (router / top-level shell) is responsible for the redirect.
      _pollTimer?.cancel();
      if (!mounted) return;
      await ref.read(authProvider.notifier).logout();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: Colors.transparent, body: _buildBody());
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: EmptyState(
          icon: Icons.cloud_off_rounded,
          color: AppColors.danger,
          title: 'Failed to load devices',
          message: _error,
        ),
      );
    }
    if (_devices.isEmpty) {
      return const Center(
        child: EmptyState(
          icon: Icons.sensors_off_rounded,
          title: 'No devices reporting yet',
          message: 'Devices appear here as soon as they send a reading.',
        ),
      );
    }

    final insets = MediaQuery.paddingOf(context);

    return RefreshIndicator(
      onRefresh: _loadDevices,
      edgeOffset: insets.top,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          16,
          insets.top + 16,
          16,
          insets.bottom + 24,
        ),
        children: [
          _buildSummary(),
          const SizedBox(height: 28),
          const SectionHeader(title: 'Devices', trailing: LiveIndicator()),
          ..._devices.map(_buildDeviceCard),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    final anomalies = _devices.where((d) => d.hasAnomaly).length;
    final unlocked = _devices
        .where((d) => d.lock != null && !d.isLocked)
        .length;

    return Row(
      children: [
        Expanded(
          child: _StatTile(
            icon: Icons.sensors_rounded,
            value: _devices.length,
            label: 'Devices',
            color: AppColors.skyMint,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatTile(
            icon: Icons.warning_amber_rounded,
            value: anomalies,
            label: 'Anomalies',
            color: anomalies > 0 ? AppColors.danger : AppColors.skyMint,
            highlight: anomalies > 0,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatTile(
            icon: Icons.lock_open_rounded,
            value: unlocked,
            label: 'Unlocked',
            color: unlocked > 0 ? AppColors.warning : AppColors.skyMint,
            highlight: unlocked > 0,
          ),
        ),
      ],
    );
  }

  Widget _buildDeviceCard(Device device) {
    final temp = device.temperature?.numericValue;
    final anomalous = device.hasAnomaly;
    final lastUpdate = device.temperature?.timestamp ?? device.lock?.timestamp;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GlassPanel(
        tint: anomalous ? AppColors.danger : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconTile(
                  icon: Icons.ac_unit_rounded,
                  color: anomalous ? AppColors.danger : AppColors.skyMint,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.displayName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _subtitleFor(device, lastUpdate),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                anomalous
                    ? const StatusPill(
                        label: 'Anomaly',
                        color: AppColors.danger,
                        icon: Icons.error_outline_rounded,
                      )
                    : const StatusPill(
                        label: 'Normal',
                        color: AppColors.success,
                        icon: Icons.check_circle_outline_rounded,
                      ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  temp != null ? temp.toStringAsFixed(1) : '--',
                  style: TextStyle(
                    color: anomalous ? AppColors.danger : AppColors.textPrimary,
                    fontSize: 44,
                    fontWeight: FontWeight.w700,
                    height: 1,
                    letterSpacing: -1,
                  ),
                ),
                if (temp != null)
                  const Padding(
                    padding: EdgeInsets.only(left: 4, bottom: 4),
                    child: Text(
                      '°C',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const Spacer(),
                _LockChip(device: device),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// "Ward A, Level 2 · Updated 12s ago" when a location is set, else just
  /// "device-001 · Updated 12s ago" (the id, since the title above already
  /// shows the friendly name and the id would otherwise appear nowhere).
  String _subtitleFor(Device device, DateTime? lastUpdate) {
    final updated = lastUpdate != null
        ? 'Updated ${timeAgo(lastUpdate)}'
        : 'No readings yet';
    final lead = device.location?.isNotEmpty == true
        ? device.location!
        : (device.name?.isNotEmpty == true ? device.deviceId : null);
    return lead != null ? '$lead · $updated' : updated;
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    this.highlight = false,
  });

  final IconData icon;
  final int value;
  final String label;
  final Color color;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(14),
      borderRadius: 20,
      tint: highlight ? color : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 12),
          Text(
            '$value',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _LockChip extends StatelessWidget {
  const _LockChip({required this.device});

  final Device device;

  @override
  Widget build(BuildContext context) {
    final hasLock = device.lock != null;
    final locked = device.isLocked;
    final color = !hasLock
        ? AppColors.textMuted
        : (locked ? AppColors.success : AppColors.warning);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.glassFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            locked ? Icons.lock_rounded : Icons.lock_open_rounded,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 6),
          Text(
            !hasLock ? 'No lock data' : (locked ? 'Locked' : 'Unlocked'),
            style: TextStyle(
              color: hasLock ? AppColors.textPrimary : AppColors.textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
