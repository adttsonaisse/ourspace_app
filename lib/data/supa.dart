// Supabase bootstrap. Optional: when .env keys are missing (tests,
// fresh clone) the app runs in local-demo mode instead of crashing.

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class Supa {
  static bool _ready = false;
  static bool get ready => _ready;
  static bool get available {
    try {
      Supabase.instance.client;
      return _ready;
    } catch (_) {
      return false;
    }
  }

  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> init() async {
    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {
      _ready = false;
      return;
    }
    final url = dotenv.maybeGet('SUPABASE_URL') ?? '';
    final anon = dotenv.maybeGet('SUPABASE_ANON_KEY') ?? '';
    if (url.isEmpty || anon.isEmpty || url.contains('xyzcompany')) {
      _ready = false;
      return;
    }
    // ignore: deprecated_member_use
    await Supabase.initialize(url: url, anonKey: anon);
    _ready = true;
  }
}
