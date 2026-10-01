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
}
