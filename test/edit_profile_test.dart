import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ourspace/data/auth_repo.dart';
import 'package:ourspace/data/space_repo.dart';
import 'package:ourspace/screens/tab_settings.dart';
import 'package:ourspace/theme/kawaii.dart';

void main() {
  testWidgets('Edit profile updates username', (tester) async {
    final auth = DemoAuthRepo();
    final spaces = DemoSpaceRepo();
    final space = await spaces.createSpace('Our space');

    await tester.pumpWidget(MaterialApp(
      theme: Kawaii.light(),
      home: Scaffold(
        body: SettingsTab(auth: auth, spaceRepo: spaces, space: space),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('@you'), findsOneWidget);

    await tester.tap(find.text('Edit profile'));
    await tester.pumpAndSettle();

    expect(find.text('Edit username'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'alex_02');
    await tester.tap(find.text('Save username'));
    await tester.pumpAndSettle();

    expect(find.text('Username updated'), findsOneWidget);
    expect(find.text('@alex_02'), findsOneWidget);
  });

  testWidgets('Edit profile blocks empty username', (tester) async {
    final auth = DemoAuthRepo();
    final spaces = DemoSpaceRepo();
    final space = await spaces.createSpace('Our space');

    await tester.pumpWidget(MaterialApp(
      theme: Kawaii.light(),
      home: Scaffold(
        body: SettingsTab(auth: auth, spaceRepo: spaces, space: space),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Edit profile'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.text('Save username'));
    await tester.pump();

    expect(find.text('Pick a username'), findsOneWidget);
    // Sheet stays open, old name untouched.
    expect(find.text('@you'), findsOneWidget);
  });
}
