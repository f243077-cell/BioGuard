import 'package:flutter/material.dart';

import '../models/reading.dart';

class LockHistoryList extends StatelessWidget {
  const LockHistoryList({super.key, required this.readings});

  final List<Reading> readings;

  @override
  Widget build(BuildContext context) {
    if (readings.isEmpty) {
      return const Center(child: Text('No lock events to show'));
    }

    return ListView.separated(
      itemCount: readings.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final r = readings[index];
        final isLocked = r.statusValue == 'locked';
        return ListTile(
          leading: Icon(
            isLocked ? Icons.lock : Icons.lock_open,
            color: r.anomalous ? Theme.of(context).colorScheme.error : null,
          ),
          title: Text(r.statusValue ?? 'unknown'),
          subtitle: Text(r.timestamp.toLocal().toString()),
          trailing: r.anomalous
              ? Icon(
                  Icons.warning_amber,
                  color: Theme.of(context).colorScheme.error,
                )
              : null,
        );
      },
    );
  }
}
