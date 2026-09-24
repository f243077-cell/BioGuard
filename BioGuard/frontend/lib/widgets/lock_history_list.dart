import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/reading.dart';
import '../utils/time_format.dart';
import 'glass.dart';

class LockHistoryList extends StatelessWidget {
  const LockHistoryList({super.key, required this.readings});

  final List<Reading> readings;

  @override
  Widget build(BuildContext context) {
    if (readings.isEmpty) {
      return const Center(
        child: EmptyState(
          icon: Icons.lock_outline_rounded,
          title: 'No lock events to show',
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: readings.length,
      separatorBuilder: (_, _) => Divider(
        height: 1,
        indent: 68,
        color: Colors.white.withValues(alpha: 0.06),
      ),
      itemBuilder: (context, index) {
        final r = readings[index];
        final isLocked = r.statusValue == 'locked';
        final color = r.anomalous
            ? AppColors.danger
            : (isLocked ? AppColors.success : AppColors.warning);
        final status = (r.statusValue?.isNotEmpty ?? false)
            ? r.statusValue!
            : 'unknown';

        return ListTile(
          leading: IconTile(
            icon: isLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
            color: color,
            size: 40,
          ),
          title: Text(
            '${status[0].toUpperCase()}${status.substring(1)}',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            dateTimeLabel(r.timestamp),
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          trailing: r.anomalous
              ? const StatusPill(label: 'Anomaly', color: AppColors.danger)
              : null,
        );
      },
    );
  }
}
