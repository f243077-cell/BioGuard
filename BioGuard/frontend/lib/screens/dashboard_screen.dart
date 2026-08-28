import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/device.dart';
import '../providers/auth_provider.dart';
import '../services/api_exceptions.dart';

/// BioGuard — Dashboard Screen
/// Polls the backend every few seconds and shows each device's live status
/// as a glassmorphic card over a colorful gradient background.
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
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6A11CB), Color(0xFF2575FC), Color(0xFF00C9A7)],
          ),
        ),
        child: SafeArea(child: _buildBody()),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    if (_error != null) {
      return Center(
        child: Text(
          'Failed to load devices:\n$_error',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white),
        ),
      );
    }
    if (_devices.isEmpty) {
      return const Center(
        child: Text(
          'No devices reporting yet.',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDevices,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text(
              'BioGuard',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ..._devices.map(_buildDeviceCard),
        ],
      ),
    );
  }

  Widget _buildDeviceCard(Device device) {
    final temp = device.temperature?.numericValue;
    final anomalous = device.hasAnomaly;
    final locked = device.isLocked;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      device.deviceId,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (anomalous) _buildBadge('ANOMALY', Colors.redAccent),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildStat(
                      icon: Icons.thermostat,
                      label: temp != null
                          ? '${temp.toStringAsFixed(1)}°C'
                          : '--',
                      color: anomalous
                          ? Colors.orangeAccent
                          : Colors.cyanAccent,
                    ),
                    const SizedBox(width: 24),
                    _buildStat(
                      icon: locked ? Icons.lock : Icons.lock_open,
                      label: locked ? 'Locked' : 'Unlocked',
                      color: locked ? Colors.greenAccent : Colors.redAccent,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStat({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 16)),
      ],
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
