// Push (FCM): realtime partner updates, delivered by the system even
// when the app is closed. Firebase is push-only here; auth + data stay
// on Supabase. Every step is best-effort so push can never break login,
// screens, or widget tests (no Firebase there).

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'supa.dart';
import '../theme/prefs.dart';

/// Tab opened when a push is tapped. Mirrors AppShell titles order:
/// home(0) notes(1) piles(2) dates(3) you(4).
int? _tabForKind(String? kind) => switch (kind) {
      'note' => 1,
      'pile' => 2,
      'date' => 3,
      _ => null,
    };

/// Killed-state delivery lands here (no UI context available).
@pragma('vm:entry-point')
Future<void> _bgHandler(RemoteMessage m) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
}

abstract class Push {
  /// Set when a push is tapped; AppShell jumps then clears it.
  static final ValueNotifier<int?> openTab = ValueNotifier(null);

  static bool _ready = false;
  static final _local = FlutterLocalNotificationsPlugin();

  static const _channel = AndroidNotificationChannel(
    'ourspace_push',
    'Sweet updates',
    description: 'Notes, piles and date plans from your partner.',
    importance: Importance.high,
  );

  static Future<void> init() async {
    if (_ready) return;
    try {
      await Firebase.initializeApp();
      final fm = FirebaseMessaging.instance;
      // NOTE: no requestPermission here. init() runs fire-and-forget
      // before runApp, when the Android Activity may not be attached yet
      // — the plugin then errors ("Unable to detect current Android
      // Activity"), the catch below swallows it, and the user is never
      // asked again. Permission is requested later via ensurePermission(),
      // called post-first-frame from AppShell / the settings toggle.
      await _local
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);
      const initSettings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      );
      await _local.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (r) {
          final tab = _tabForKind(r.payload);
          if (tab != null) openTab.value = tab;
        },
      );
      // Foreground: FCM is silent, so show a local heads-up instead.
      FirebaseMessaging.onMessage.listen(_showForeground);
      // Tap: from background + from killed state (cold start).
      FirebaseMessaging.onMessageOpenedApp.listen(_route);
      final initial = await fm.getInitialMessage();
      if (initial != null) _route(initial);
      FirebaseMessaging.onBackgroundMessage(_bgHandler);
      FirebaseMessaging.instance.onTokenRefresh.listen((_) {
        registerToken();
      });
      _ready = true;
    } catch (_) {
      // No Play Services / no google-services.json / tests: push stays off.
    }
  }

  /// Ask for notification permission. Safe to call repeatedly: returns
  /// true when already granted, prompts once otherwise. Must run when an
  /// Activity is attached (post-first-frame), never from early init().
  /// Never throws — false on tests, no Play Services, or denial.
  /// Note: on Android <13 there is no runtime dialog (POST_NOTIFICATIONS
  /// doesn't exist; notifications are granted at install), so the FCM plugin
  /// resolves authorized immediately — toggle ON with no dialog is correct
  /// there, not a bug.
  static Future<bool> ensurePermission() async {
    try {
      final s = await FirebaseMessaging.instance
          .requestPermission(alert: true, badge: true, sound: true);
      return s.authorizationStatus == AuthorizationStatus.authorized ||
          s.authorizationStatus == AuthorizationStatus.provisional;
    } catch (_) {
      return false;
    }
  }

  /// Current system status, for the settings toggle. False when unknown.
  static Future<bool> notificationsEnabled() async {
    try {
      final s = await FirebaseMessaging.instance.getNotificationSettings();
      return s.authorizationStatus == AuthorizationStatus.authorized ||
          s.authorizationStatus == AuthorizationStatus.provisional;
    } catch (_) {
      return false;
    }
  }

  static void _route(RemoteMessage m) {
    final tab = _tabForKind(m.data['kind']);
    if (tab != null) openTab.value = tab;
  }

  static Future<void> _showForeground(RemoteMessage m) async {
    try {
      final enabled =
          await KawaiiPrefs.loadNotif().timeout(const Duration(seconds: 1), onTimeout: () => false);
      if (!enabled) return;
      final n = m.notification;
      if (n == null) return;
      await _local.show(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: n.title,
        body: n.body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'ourspace_push',
            'Sweet updates',
            channelDescription:
                'Notes, piles and date plans from your partner.',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        payload: m.data['kind'],
      );
    } catch (_) {}
  }

  /// Saves this device's FCM token for the signed-in user (multi-device
  /// safe: one row per token). No-op in demo mode / offline.
  static Future<void> registerToken() async {
    try {
      if (!Supa.available) return;
      final uid = Supa.client.auth.currentUser?.id;
      if (uid == null) return;
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      await Supa.client.from('device_tokens').upsert({
        'user_id': uid,
        'token': token,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  /// Removes only this device's token (other devices keep theirs).
  /// Call BEFORE signOut while the uid is still available.
  static Future<void> unregisterToken() async {
    try {
      if (!Supa.available) return;
      final uid = Supa.client.auth.currentUser?.id;
      if (uid == null) return;
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      await Supa.client
          .from('device_tokens')
          .delete()
          .eq('user_id', uid)
          .eq('token', token);
    } catch (_) {}
  }
}
