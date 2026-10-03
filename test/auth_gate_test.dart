import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ourspace/data/auth_repo.dart';
import 'package:ourspace/data/repos.dart';
import 'package:ourspace/screens/auth_gate.dart';
import 'package:ourspace/screens/auth_get_started.dart';
import 'package:ourspace/shell.dart';
import 'package:ourspace/theme/kawaii.dart';
import 'package:ourspace/theme/prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpGate(WidgetTester tester, AuthRepo auth) async {
    await tester.pumpWidget(MaterialApp(
      theme: Kawaii.light(),
      home: AuthGate(auth: auth),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('Logged out shows Get Started', (tester) async {
    await pumpGate(tester, DemoAuthRepo());

    expect(find.byType(GetStartedPage), findsOneWidget);
    expect(find.byType(AppShell), findsNothing);
  });

  testWidgets('Active session skips login', (tester) async {
    final auth = DemoAuthRepo();
    await pumpGate(tester, auth);
    expect(find.byType(GetStartedPage), findsOneWidget);

    // signIn has a 200ms delay but schedules no frame until it fires, so
    // pump once to advance fake time, then settle.
    final login = auth.signIn('you@cutemail.com', 'secret123');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    await login;

    expect(find.byType(AppShell), findsOneWidget);
  });

  testWidgets('Demo session persists across instances', (tester) async {
    await KawaiiPrefs.saveDemoSession(
        uid: 'demo-user',
        email: 'you@cutemail.com',
        username: 'you');

    final fresh = DemoAuthRepo();
    await pumpGate(tester, fresh);

    expect(fresh.currentUserId, 'demo-user');
    expect(find.byType(AppShell), findsOneWidget);
  });

  testWidgets('Sign out returns to Get Started', (tester) async {
    final auth = DemoAuthRepo();
    await pumpGate(tester, auth);

    final login = auth.signIn('you@cutemail.com', 'secret123');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    await login;
    expect(find.byType(AppShell), findsOneWidget);

    await auth.signOut();
    await tester.pumpAndSettle();

    expect(find.byType(GetStartedPage), findsOneWidget);
    expect(find.byType(AppShell), findsNothing);
  });
}
