import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/device_history_provider.dart';
import '../providers/devices_list_provider.dart';
import '../widgets/authenticated_app_bar.dart';
import '../widgets/temperature_chart.dart';
import '../widgets/lock_history_list.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  String? _selectedDeviceId;
  String? _readingType = 'temperature';
  final int _limit = 100;

  @override
  Widget build(BuildContext context) {
    final devicesAsync = ref.watch(devicesListProvider);

    return Scaffold(
      appBar: const AuthenticatedAppBar(title: 'History'),
      body: devicesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Failed to load devices: $err')),
        data: (devices) {
          if (devices.isEmpty) {
            return const Center(child: Text('No devices found'));
          }
          _selectedDeviceId ??= devices.first.deviceId;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButton<String>(
                        value: _selectedDeviceId,
                        isExpanded: true,
                        items: devices
                            .map(
                              (d) => DropdownMenuItem(
                                value: d.deviceId,
                                child: Text(d.deviceId),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _selectedDeviceId = v),
                      ),
                    ),
                    const SizedBox(width: 12),
                    DropdownButton<String>(
                      value: _readingType,
                      items: const [
                        DropdownMenuItem(
                          value: 'temperature',
                          child: Text('Temperature'),
                        ),
                        DropdownMenuItem(value: 'lock', child: Text('Lock')),
                      ],
                      onChanged: (v) => setState(() => _readingType = v),
                    ),
                  ],
                ),
              ),
              Expanded(child: _buildChart(_selectedDeviceId!)),
            ],
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
      error: (err, _) => Center(child: Text('Failed to load history: $err')),
      data: (readings) {
        if (readings.isEmpty) {
          return const Center(child: Text('No readings yet'));
        }
        return _readingType == 'lock'
            ? LockHistoryList(readings: readings)
            : TemperatureChart(readings: readings);
      },
    );
  }
}
