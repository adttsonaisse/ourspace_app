// Auth implementations. UI takes an AuthRepo (see repos.dart) so tests
// inject fakes and prod resolves Supabase when configured.

import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'repos.dart';
import 'supa.dart';
import '../theme/prefs.dart';

/// Supabase-backed auth. Throws FriendlyAuthError (a StateError with a
/// human message) so screens can show it directly in a SnackBar.
class SupabaseAuthRepo implements AuthRepo {
  SupabaseClient get _c => Supa.client;

  @override
  Future<void> signUp(String email, String password,
      {String? username}) async {
    try {
      await _c.auth.signUp(
        email: email.trim(),
        password: password,
        data: (username ?? '').trim().isEmpty
            ? null
            : {'username': username!.trim()},
      );
    } catch (e) {
      throw StateError(friendlyAuthError(e));
    }
  }

  @override
  Future<void> signIn(String email, String password) async {
    try {
      await _c.auth.signInWithPassword(
          email: email.trim(), password: password);
    } catch (e) {
      throw StateError(friendlyAuthError(e));
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _c.auth.signOut();
    } catch (e) {
      throw StateError(friendlyAuthError(e));
    }
  }

  @override
  String? get currentUserId => _c.auth.currentUser?.id;

  @override
  String? get currentUsername {
    final m = _c.auth.currentUser?.userMetadata;
    final u = (m?['username'] as String?)?.trim();
    if (u != null && u.isNotEmpty) return u;
    return null;
  }

  @override
  String? get currentEmail => _c.auth.currentUser?.email;

  @override
  Stream<String?> watchAuth() =>
      _c.auth.onAuthStateChange.map((e) => e.session?.user.id);
}

/// Local demo auth (no backend): accepts anything, remembers a fake uid.
/// Instances constructed directly are independent (tests); the app shares
/// one via [resolveAuthRepo] so the username/session from login is visible
/// in the shell and settings — mirroring the shared Supabase client.
class DemoAuthRepo implements AuthRepo {
  String? _uid;
  String? _username;
  String? _email;
  final _ctrl = StreamController<String?>.broadcast();

  /// Last username handed to signUp — test seam, demo only.
  String? get username => _username;

  @override
  Future<void> signUp(String email, String password,
      {String? username}) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    _uid = 'demo-user';
    _username = (username ?? '').trim().isEmpty ? null : username!.trim();
    _email = email.trim().isEmpty ? null : email.trim();
    _ctrl.add(_uid);
    // Fire-and-forget: login must never block on local storage, and several
    // widget tests run without a SharedPreferences mock.
    unawaited(_persist());
  }

  @override
  Future<void> signIn(String email, String password) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    _uid = 'demo-user';
    _email = email.trim().isEmpty ? _email : email.trim();
    _ctrl.add(_uid);
    // Fire-and-forget: see signUp.
    unawaited(_persist());
  }

  @override
  Future<void> signOut() async {
    _uid = null;
    _ctrl.add(null);
    unawaited(_clearPersisted());
  }

  /// Rehydrate the last demo session (cold start without backend).
  /// No-op when already signed in or nothing was saved.
  Future<void> restore() async {
    if (_uid != null) return;
    try {
      final s = await KawaiiPrefs.loadDemoSession();
      if ((s.uid ?? '').isEmpty) return;
      _uid = s.uid;
      _email = s.email;
      _username = s.username;
    } catch (_) {}
  }

  Future<void> _persist() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await KawaiiPrefs.saveDemoSession(
          uid: uid, email: _email, username: _username);
    } catch (_) {}
  }

  Future<void> _clearPersisted() async {
    try {
      await KawaiiPrefs.clearDemoSession();
    } catch (_) {}
  }

  @override
  String? get currentUserId => _uid;

  @override
  String? get currentUsername => _username;

  @override
  String? get currentEmail => _email;

  @override
  Stream<String?> watchAuth() => _ctrl.stream;
}

/// Demo auth shared by every screen (mirrors the Supabase singleton
/// client): login on one page must be visible in shell/settings.
DemoAuthRepo? _demoAuthSingleton;

/// Prod resolves Supabase when configured, demo otherwise.
/// Demo resolves to a shared instance so the username/session from the
/// login page propagates to the shell and settings instead of falling
/// back to 'you'. Direct `DemoAuthRepo()` constructors stay independent
/// for tests.
AuthRepo resolveAuthRepo() {
  if (Supa.ready) return SupabaseAuthRepo();
  return _demoAuthSingleton ??= DemoAuthRepo();
}

String friendlyAuthError(Object e) {
  if (e is SocketException) {
    return 'No connection. Check internet and retry.';
  }
  if (e is TimeoutException ||
      e.toString().toLowerCase().contains('timed out') ||
      e.toString().toLowerCase().contains('timeout')) {
    return 'No connection. Check internet and retry.';
  }
  if (e is AuthException) {
    final m = e.message.toLowerCase();
    if (m.contains('already registered') || m.contains('already exists')) {
      return 'Already have an account? Log in instead.';
    }
    if (m.contains('email not confirmed') ||
        m.contains('not confirmed') ||
        (m.contains('confirm') && m.contains('email'))) {
      return 'Confirm your email first, then log in.';
    }
    if (m.contains('invalid login') ||
        m.contains('invalid credentials') ||
        m.contains('user not found') ||
        m.contains('not found')) {
      return "Hmm, that login didn't match. Try again.";
    }
    if (m.contains('password')) return 'Password needs 6+ characters.';
    if (m.contains('email')) return 'That email looks off.';
    if (m.contains('network') || m.contains('failed host')) {
      return 'No connection. Check internet and retry.';
    }
    return e.message;
  }
  if (e is StateError && e.message.isNotEmpty) return e.message;
  return 'Something hiccuped. Try again.';
}
