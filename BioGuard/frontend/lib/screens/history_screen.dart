import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/theme.dart';
import '../providers/device_history_provider.dart';
import '../providers/devices_list_provider.dart';
import '../widgets/glass.dart';
import '../widgets/temperature_chart.dart';
import '../widgets/lock_history_list.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  String? _selectedDeviceId;
  String _readingType = 'temperature';
  final int _limit = 100;

  @override
  Widget build(BuildContext context) {
    final devicesAsync = ref.watch(devicesListProvider);

    // No own Scaffold/AppBar/background: this screen is embedded as a tab
    // inside MainShell, which already provides one shared AppBar and
    // GlassBackground for the whole IndexedStack — matching Dashboard,
    // Alerts and Reports.
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: devicesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: EmptyState(
            icon: Icons.cloud_off_rounded,
            color: AppColors.danger,
            title: 'Failed to load devices',
            message: '$err',
          ),
        ),
        data: (devices) {
          if (devices.isEmpty) {
            return const Center(
              child: EmptyState(
                icon: Icons.sensors_off_rounded,
                title: 'No devices found',
              ),
            );
          }
          _selectedDeviceId ??= devices.first.deviceId;

          // SafeArea reads MediaQuery inside this Scaffold's body, so it
          // still includes the shared app bar's height even though this
          // screen has no appBar/extendBodyBehindAppBar of its own —
          // MainShell's Scaffold provides both.
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GlassPanel(
                    padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
                    borderRadius: 18,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.sensors_rounded,
                          color: AppColors.skyMint,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedDeviceId,
                              isExpanded: true,
                              dropdownColor: AppColors.graphiteLight,
                              borderRadius: BorderRadius.circular(16),
                              icon: const Icon(
                                Icons.expand_more_rounded,
                                color: AppColors.textSecondary,
                              ),
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                              items: devices
                                  .map(
                                    (d) => DropdownMenuItem(
                                      value: d.deviceId,
                                      child: Text(d.displayName),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _selectedDeviceId = v),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<String>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: 'temperature',
                        icon: Icon(Icons.thermostat_rounded, size: 18),
                        label: Text('Temperature'),
                      ),
                      ButtonSegment(
                        value: 'lock',
                        icon: Icon(Icons.lock_rounded, size: 18),
                        label: Text('Lock'),
                      ),
                    ],
                    selected: {_readingType},
                    onSelectionChanged: (s) =>
                        setState(() => _readingType = s.first),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: GlassPanel(
                      padding: const EdgeInsets.all(8),
                      child: _buildChart(_selectedDeviceId!),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildChart(String deviceId) {
    final historyAsync = ref.watch(
      deviceHistoryProvider(
        HistoryQuery(
          deviceId: deviceId,
          readingType: _readingType,
          limit: _limit,
        ),
      ),
    );

    return historyAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: EmptyState(
          icon: Icons.cloud_off_rounded,
          color: AppColors.danger,
          title: 'Failed to load history',
          message: '$err',
        ),
      ),
      data: (readings) {
        if (readings.isEmpty) {
          return const Center(
            child: EmptyState(
              icon: Icons.insights_rounded,
              title: 'No readings yet',
            ),
          );
        }
        return _readingType == 'lock'
            ? LockHistoryList(readings: readings)
            : TemperatureChart(readings: readings);
      },
    );
  }
}
