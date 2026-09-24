import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/theme.dart';
import '../models/device.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/api_exceptions.dart';
import '../widgets/glass.dart';

/// BioGuard — Report Screen
/// Lists devices and opens a PDF summary report for the selected one.
class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key, this.isActive = false});

  final bool isActive;

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  List<Device> _devices = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.isActive) {
      _loadDevices();
    }
  }

  @override
  void didUpdateWidget(covariant ReportScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _loadDevices();
    }
  }

  Future<void> _loadDevices() async {
    setState(() {
      _loading = _devices.isEmpty;
      _error = null;
    });

    try {
      final devices = await ref.read(apiServiceProvider).fetchDevices();
      if (!mounted) return;
      setState(() {
        _devices = devices;
        _loading = false;
        _error = null;
      });
    } on UnauthorizedException {
      if (!mounted) return;
      await ref.read(authProvider.notifier).logout();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openReport(String deviceId) async {
    final token = await ref.read(tokenStorageProvider).getToken();
    final uri = Uri.parse(
      '${ApiService.apiBaseUrl}/reports/pdf/$deviceId',
    ).replace(queryParameters: token != null ? {'token': token} : null);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the report')),
      );
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
          onRetry: _loadDevices,
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
          const GlassPanel(
            child: Row(
              children: [
                IconTile(icon: Icons.description_rounded, size: 48),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Device reports',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Open a PDF summary of readings and alerts '
                        'for any device.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          if (_devices.isEmpty)
            const EmptyState(
              icon: Icons.sensors_off_rounded,
              title: 'No devices reporting yet',
              message: 'Pull down to refresh.',
            )
          else ...[
            SectionHeader(
              title: 'Devices',
              trailing: Text(
                '${_devices.length}',
                style: const TextStyle(color: AppColors.textMuted),
              ),
            ),
            ..._devices.map(_buildDeviceTile),
          ],
        ],
      ),
    );
  }

  Widget _buildDeviceTile(Device device) {
    final temp = device.temperature?.numericValue;
    final details = [
      if (temp != null) '${temp.toStringAsFixed(1)}°C',
      if (device.lock != null) device.isLocked ? 'Locked' : 'Unlocked',
    ].join('  ·  ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassPanel(
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        borderRadius: 20,
        child: Row(
          children: [
            IconTile(
              icon: Icons.ac_unit_rounded,
              color: device.hasAnomaly ? AppColors.danger : AppColors.skyMint,
              size: 40,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.deviceId,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (details.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      details,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () => _openReport(device.deviceId),
              icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
              label: const Text('View'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                minimumSize: const Size(0, 40),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
