import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ourspace/data/auth_repo.dart';
import 'package:ourspace/screens/auth_login.dart';
import 'package:ourspace/shell.dart';
import 'package:ourspace/theme/kawaii.dart';

class _FailAuth extends DemoAuthRepo {
  @override
  Future<void> signIn(String email, String password) async {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    throw StateError("Hmm, that login didn't match. Try again.");
  }
}

class _UnconfirmedAuth extends DemoAuthRepo {
  @override
  Future<void> signUp(String email, String password,
      {String? username}) async {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    // No session: email confirmation pending, uid stays null.
  }
}

void main() {
  testWidgets('Login success enters shell', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: Kawaii.light(),
      home: LoginRegisterPage(loginFirst: true, auth: DemoAuthRepo()),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'you@cutemail.com');
    await tester.enterText(find.byType(TextField).at(1), 'secret123');
    await tester.tap(find.text('Login to ourspace'));
    await tester.pumpAndSettle();

    expect(find.byType(AppShell), findsOneWidget);
  });

  testWidgets('Login failure shows kawaii alert, stays put', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: Kawaii.light(),
      home: LoginRegisterPage(loginFirst: true, auth: _FailAuth()),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'you@cutemail.com');
    await tester.enterText(find.byType(TextField).at(1), 'wrongpass');
    await tester.tap(find.text('Login to ourspace'));
    await tester.pumpAndSettle();

    expect(find.text('No account for this email yet'), findsOneWidget);
    expect(
        find.text(
            "We couldn't match that email + password. Check for typos or make a space instead."),
        findsOneWidget);
    expect(find.text('Create one'), findsOneWidget);
    expect(find.byType(AppShell), findsNothing);

    // Alert action switches to register mode.
    await tester.ensureVisible(find.text('Create one'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create one'));
    await tester.pumpAndSettle();
    expect(find.text('Create our space'), findsOneWidget);
  });

  testWidgets('Login email format is validated inline', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: Kawaii.light(),
      home: LoginRegisterPage(loginFirst: true, auth: DemoAuthRepo()),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'not-an-email');
    await tester.enterText(find.byType(TextField).at(1), 'secret123');
    await tester.tap(find.text('Login to ourspace'));
    await tester.pumpAndSettle();

    expect(find.text('That email looks off'), findsOneWidget);
    expect(find.byType(AppShell), findsNothing);
  });

  testWidgets('Register without session parks on login', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: Kawaii.light(),
      home: LoginRegisterPage(auth: _UnconfirmedAuth()),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'alex_02');
    await tester.enterText(find.byType(TextField).at(1), 'you@cutemail.com');
    await tester.enterText(find.byType(TextField).at(2), 'secret123');
    await tester.ensureVisible(find.text('Create our space'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create our space'));
    await tester.pumpAndSettle();

    expect(find.text('Check your inbox'), findsOneWidget);
    expect(find.text('Account created — confirm your email, then log in'),
        findsOneWidget);
    expect(find.text('Login to ourspace'), findsOneWidget);
  });

  testWidgets('Register saves username', (tester) async {
    final auth = DemoAuthRepo();
    await tester.pumpWidget(MaterialApp(
      theme: Kawaii.light(),
      home: LoginRegisterPage(auth: auth),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'alex_02');
    await tester.enterText(find.byType(TextField).at(1), 'you@cutemail.com');
    await tester.enterText(find.byType(TextField).at(2), 'secret123');
    await tester.ensureVisible(find.text('Create our space'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create our space'));
    await tester.pumpAndSettle();

    expect(auth.username, 'alex_02');
  });

  test('friendlyAuthError maps offline', () {
    expect(
      friendlyAuthError(const SocketException('Failed host lookup')),
      'No connection. Check internet and retry.',
    );
  });

  test('demo username propagates across resolveAuthRepo callers', () async {
    // Regression: register on the login page must be visible in shell /
    // settings, which resolve their own repo. No Supa in tests, so this
    // exercises the shared demo instance.
    final loginSide = resolveAuthRepo();
    final settingsSide = resolveAuthRepo();
    expect(identical(loginSide, settingsSide), isTrue);

    await (loginSide as DemoAuthRepo).signUp(
        'you@cutemail.com', 'secret123',
        username: 'alex_02');
    expect(settingsSide.currentUsername, 'alex_02');
    expect(settingsSide.currentUserId, isNotNull);

    await (settingsSide as DemoAuthRepo).signOut();
    expect(loginSide.currentUserId, isNull);
  });
}
