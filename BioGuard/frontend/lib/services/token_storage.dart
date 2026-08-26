import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// BioGuard — Secure Token Storage
/// Persists the JWT locally so sessions survive app restarts.
class TokenStorage {
  static const _tokenKey = 'bioguard_access_token';

  final FlutterSecureStorage _storage;

  TokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  Future<void> saveToken(String token) =>
      _storage.write(key: _tokenKey, value: token);

  Future<String?> getToken() => _storage.read(key: _tokenKey);

  Future<void> deleteToken() => _storage.delete(key: _tokenKey);
}
