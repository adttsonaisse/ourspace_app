import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ourspace/data/space_repo.dart';
import 'package:ourspace/screens/auth_pairing.dart';
import 'package:ourspace/shell.dart';
import 'package:ourspace/theme/kawaii.dart';

// NOTE: manual pumps only — PairingPage runs a 1s countdown timer,
// pumpAndSettle would never settle.

Future<void> _pumpPairing(WidgetTester tester) async {
  await tester.pumpWidget(MaterialApp(
    theme: Kawaii.light(),
    home: PairingPage(spaceRepo: DemoSpaceRepo()),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('Demo mode has no local code, shows retry', (tester) async {
    await _pumpPairing(tester);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Solo demo — pair codes come from the backend.'),
        findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('482916'), findsNothing);
  });

  testWidgets('Join wrong code shows error, stays put', (tester) async {
    await _pumpPairing(tester);
    await tester.tap(find.text('I have a code'));
    await tester.pump(const Duration(milliseconds: 200));

    await tester.enterText(find.byType(TextField), '000000');
    await tester.tap(find.text('Check code'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text("Hmm, that code didn't match. Check with your person."),
        findsOneWidget);
    expect(find.byType(AppShell), findsNothing);
  });

  testWidgets('Join code without backend shows error, stays put',
      (tester) async {
    await _pumpPairing(tester);
    await tester.tap(find.text('I have a code'));
    await tester.pump(const Duration(milliseconds: 200));

    await tester.enterText(find.byType(TextField), '482916');
    await tester.tap(find.text('Check code'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text("Hmm, that code didn't match. Check with your person."),
        findsOneWidget);
    expect(find.byType(AppShell), findsNothing);
  });
}
