/// BioGuard — App-wide constants
library;

/// The backend's base URL. Override at build/run time with:
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.23:8000
///
/// The default (10.0.2.2) is a special address the Android emulator maps
/// to the host machine's localhost — it does not work on a physical
/// device, iOS simulator, or desktop/web, which all need the backend
/// machine's real LAN IP or hostname instead. See README.md.
class AppConfig {
  AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  /// Same host as [apiBaseUrl], with a ws(s):// scheme and the alerts path.
  /// Computed rather than duplicated so the two can never drift apart.
  static String get wsAlertsUrl {
    final uri = Uri.parse(apiBaseUrl);
    final wsScheme = uri.scheme == 'https' ? 'wss' : 'ws';
    return uri.replace(scheme: wsScheme, path: '/ws/alerts').toString();
  }
}
