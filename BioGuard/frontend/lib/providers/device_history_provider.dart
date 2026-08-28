import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/reading.dart';
import '../services/api_exceptions.dart';
import 'auth_provider.dart';

class HistoryQuery {
  const HistoryQuery({
    required this.deviceId,
    this.readingType,
    this.limit = 100,
  });
  final String deviceId;
  final String? readingType;
  final int limit;

  @override
  bool operator ==(Object other) =>
      other is HistoryQuery &&
      other.deviceId == deviceId &&
      other.readingType == readingType &&
      other.limit == limit;

  @override
  int get hashCode => Object.hash(deviceId, readingType, limit);
}

final deviceHistoryProvider = FutureProvider.autoDispose
    .family<List<Reading>, HistoryQuery>((ref, query) async {
      final api = ref.watch(apiServiceProvider);
      try {
        return await api.fetchDeviceHistory(
          query.deviceId,
          readingType: query.readingType,
          limit: query.limit,
        );
      } on UnauthorizedException {
        ref.read(authProvider.notifier).logout();
        rethrow;
      }
    });
