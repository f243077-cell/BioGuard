import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/device.dart';
import '../services/api_exceptions.dart';
import 'auth_provider.dart';

final devicesListProvider = FutureProvider.autoDispose<List<Device>>((
  ref,
) async {
  final api = ref.watch(apiServiceProvider);
  try {
    return await api.fetchDevices();
  } on UnauthorizedException {
    ref.read(authProvider.notifier).logout();
    rethrow;
  }
});
