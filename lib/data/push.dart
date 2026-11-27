import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A message that arrives while the app is closed: Firebase shows it itself.
@pragma('vm:entry-point')
Future<void> epsilonBackgroundMessage(RemoteMessage message) async {}

/// Push notifications. They start only when Firebase is configured in the app
/// (android/app/google-services.json); until then nothing happens here.
class FirebasePush {
  static bool ready = false;
  static String? token;

  static Future<void> init() async {
    if (kIsWeb) return;
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(epsilonBackgroundMessage);
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      token = await messaging.getToken();
      messaging.onTokenRefresh.listen((t) {
        token = t;
      });
      ready = true;
    } on Object catch (e) {
      debugPrint('Push notifications are off: $e');
    }
  }

  /// Saves this device's token on the user's row, so the server can send to it.
  static Future<void> saveFor(String userId) async {
    final t = token;
    if (!ready || t == null || t.isEmpty) return;
    try {
      await Supabase.instance.client
          .from('users')
          .update({'push_token': t})
          .eq('id', userId);
    } on Object catch (e) {
      debugPrint('Push token not saved: $e');
    }
  }
}
