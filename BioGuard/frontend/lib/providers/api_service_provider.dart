import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api_service.dart';
import '../services/token_storage.dart';

/// Single shared TokenStorage instance so ApiService and auth_provider
/// read/write the same underlying token.
final tokenStorageProvider = Provider<TokenStorage>((ref) {
  return TokenStorage();
});

final apiServiceProvider = Provider<ApiService>((ref) {
  final tokenStorage = ref.watch(tokenStorageProvider);
  return ApiService(tokenStorage: tokenStorage);
});
