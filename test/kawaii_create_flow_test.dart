import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ourspace/shell.dart';

Future<void> _goToTab(WidgetTester tester, String label) async {
  await tester.tap(find.bySemanticsLabel(label));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Empty note is blocked with a hint', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AppShell()));
    await tester.pumpAndSettle();

    await _goToTab(tester, 'notes');
    expect(find.text('New note'), findsOneWidget);

    await tester.tap(find.text('New note'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Paste it in'));
    await tester.pumpAndSettle();

    expect(find.text('Give it a title first'), findsOneWidget);
    expect(find.text('Note pasted!'), findsNothing);
  });

  testWidgets('Adding a note shows a success alert', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AppShell()));
    await tester.pumpAndSettle();

    await _goToTab(tester, 'notes');
    await tester.tap(find.text('New note'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byType(TextField), 'Left oat latte in the fridge');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Paste it in'));
    await tester.pumpAndSettle();

    expect(find.text('Note pasted!'), findsOneWidget);

    await tester.tap(find.text('Sweet!'));
    await tester.pumpAndSettle();
    expect(find.text('Note pasted!'), findsNothing);
  });

  testWidgets('FAB only shows on notes, piles, dates with matching label',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AppShell()));
    await tester.pumpAndSettle();

    // home: no FAB
    expect(find.text('New note'), findsNothing);
    expect(find.text('New pile'), findsNothing);
    expect(find.text('Plan date'), findsNothing);

    await _goToTab(tester, 'notes');
    expect(find.text('New note'), findsOneWidget);
    expect(find.text('New pile'), findsNothing);
    expect(find.text('Plan date'), findsNothing);

    await _goToTab(tester, 'piles');
    expect(find.text('New note'), findsNothing);
    expect(find.text('New pile'), findsOneWidget);
    expect(find.text('Plan date'), findsNothing);

    await _goToTab(tester, 'dates');
    expect(find.text('New note'), findsNothing);
    expect(find.text('New pile'), findsNothing);
    expect(find.text('Plan date'), findsOneWidget);

    await _goToTab(tester, 'you');
    expect(find.text('New note'), findsNothing);
    expect(find.text('New pile'), findsNothing);
    expect(find.text('Plan date'), findsNothing);
  });
}
