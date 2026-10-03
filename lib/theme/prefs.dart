import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'kawaii.dart';

abstract class KawaiiPrefs {
  static const _themeKey = 'kawaii_theme_dark';
  static const _notifKey = 'kawaii_notif';
  static const _skippedUpdateKey = 'kawaii_skipped_update_tag';

  static Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final dark = prefs.getBool(_themeKey) ?? false;
    Kawaii.themeMode.value = dark ? ThemeMode.dark : ThemeMode.light;
  }

  static Future<void> saveTheme(bool dark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, dark);
  }

  static Future<bool> loadNotif() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notifKey) ?? true;
  }

  static Future<void> saveNotif(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notifKey, v);
  }

  static Future<String?> loadSkippedUpdateTag() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_skippedUpdateKey);
  }

  static Future<void> saveSkippedUpdateTag(String tag) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_skippedUpdateKey, tag);
  }

  // Demo-mode session (no backend): remembers the local login so the app
  // skips auth on cold start. Supabase mode needs nothing here — the
  // SDK persists its own session.
  static const _demoUidKey = 'demo_auth_uid';
  static const _demoEmailKey = 'demo_auth_email';
  static const _demoUsernameKey = 'demo_auth_username';

  static Future<({String? uid, String? email, String? username})>
      loadDemoSession() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      uid: prefs.getString(_demoUidKey),
      email: prefs.getString(_demoEmailKey),
      username: prefs.getString(_demoUsernameKey),
    );
  }

  static Future<void> saveDemoSession(
      {required String uid, String? email, String? username}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_demoUidKey, uid);
    if (email == null) {
      await prefs.remove(_demoEmailKey);
    } else {
      await prefs.setString(_demoEmailKey, email);
    }
    if (username == null) {
      await prefs.remove(_demoUsernameKey);
    } else {
      await prefs.setString(_demoUsernameKey, username);
    }
  }

  static Future<void> clearDemoSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_demoUidKey);
    await prefs.remove(_demoEmailKey);
    await prefs.remove(_demoUsernameKey);
  }
}
