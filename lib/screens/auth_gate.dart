import 'dart:async';

import 'package:flutter/material.dart';

import '../data/auth_repo.dart';
import '../data/backend.dart';
import '../data/repos.dart';
import '../data/supa.dart';
import '../shell.dart';
import '../theme/kawaii.dart';
import '../widgets/kawaii.dart';
import '../widgets/kawaii_deco.dart';
import 'auth_get_started.dart';

/// Cold-start router: signed-in users skip auth, signed-out users land on
/// Get Started. Supabase restores its session in [Supa.init] (before runApp)
/// and the SDK persists it across restarts; demo mode restores from
/// SharedPreferences via [DemoAuthRepo.restore]. Stays subscribed to
/// [AuthRepo.watchAuth] so an expired/revoked session kicks back to login.
class AuthGate extends StatefulWidget {
  final AuthRepo? auth;
  const AuthGate({super.key, this.auth});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final AuthRepo _auth;
  StreamSubscription<String?>? _sub;
  String? _uid;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _auth = widget.auth ?? resolveAuthRepo();
    _uid = _auth.currentUserId;
    if (_uid != null) _loading = false;
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final auth = _auth;
    if (!Supa.ready && auth is DemoAuthRepo) {
      // Bounded: prefs can pend in widget tests without a mock, and must
      // never trap the gate on splash in prod either.
      try {
        await auth.restore().timeout(const Duration(seconds: 3));
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _uid = _auth.currentUserId;
      _loading = false;
    });    _sub = _auth.watchAuth().listen((uid) {
      if (!mounted) return;
      setState(() => _uid = uid ?? _auth.currentUserId);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: KawaiiCard(
              color: Kawaii.peach,
              padding: EdgeInsets.zero,
              child: KawaiiPolkaBg(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      KawaiiDoodles(),
                      SizedBox(height: 10),
                      KawaiiAppMascot(size: 64),
                      SizedBox(height: 10),
                      Text(
                        'ourspace',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          fontFamily: Kawaii.displayFamily,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        ' unwrapping your stickers…',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      SizedBox(height: 16),
                      CircularProgressIndicator(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    if (_uid != null) return const AppShell();
    return const GetStartedPage();
  }
}
