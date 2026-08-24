import 'package:firebase_messaging/firebase_messaging.dart';

/// BioGuard — FCM Service
/// Requests notification permission and subscribes the device to the
/// shared alerts topic (must match _FCM_TOPIC in the backend's fcm.py).
class FcmService {
  static const String _topic = 'bioguard_alerts';

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  Future<void> initialize() async {
    await _messaging.requestPermission(alert: true, badge: true, sound: true);
    await _messaging.subscribeToTopic(_topic);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification != null) {
        print(
          '[BioGuard] Push received: ${notification.title} — ${notification.body}',
        );
      }
    });
  }
}
