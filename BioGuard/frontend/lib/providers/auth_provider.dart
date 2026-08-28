import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../services/api_service.dart';
import '../services/token_storage.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  const AuthState({required this.status, this.isLoading = false, this.error});

  final AuthStatus status;
  final bool isLoading;
  final String? error;

  AuthState copyWith({
    AuthStatus? status,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._tokenStorage)
    : super(const AuthState(status: AuthStatus.unknown)) {
    _restoreSession();
  }

  final TokenStorage _tokenStorage;

  Future<void> _restoreSession() async {
    final token = await _tokenStorage.getToken();
    state = AuthState(
      status: token != null
          ? AuthStatus.authenticated
          : AuthStatus.unauthenticated,
    );
  }

  Future<void> register(String username, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final response = await http.post(
        Uri.parse('${ApiService.apiBaseUrl}/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      if (response.statusCode != 201) {
        final detail = _extractErrorDetail(response.body);
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          isLoading: false,
          error: detail ?? 'Could not create account',
        );
        return;
      }

      // /auth/register returns UserOut, not a token — chain straight into
      // login so the user isn't asked to re-enter credentials immediately.
      await login(username, password);
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        isLoading: false,
        error: 'Could not reach the server. Check your connection.',
      );
    }
  }

  Future<void> login(String username, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final response = await http.post(
        Uri.parse('${ApiService.apiBaseUrl}/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      if (response.statusCode != 200) {
        final detail = _extractErrorDetail(response.body);
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          isLoading: false,
          error: detail ?? 'Invalid username or password',
        );
        return;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final token = data['access_token'] as String;
      await _tokenStorage.saveToken(token);

      state = const AuthState(status: AuthStatus.authenticated);
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        isLoading: false,
        error: 'Could not reach the server. Check your connection.',
      );
    }
  }

  Future<void> logout() async {
    await _tokenStorage.deleteToken();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  String? _extractErrorDetail(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      return json['detail'] as String?;
    } catch (_) {
      return null;
    }
  }
}

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(tokenStorageProvider));
});

final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService(tokenStorage: ref.watch(tokenStorageProvider));
});
