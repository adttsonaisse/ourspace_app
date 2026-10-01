import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ourspace/shell.dart';

void main() {
  testWidgets('Empty note is blocked with a hint', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AppShell()));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Note'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Paste it in'));
    await tester.pumpAndSettle();

    expect(find.text('Give it a title first'), findsOneWidget);
    expect(find.text('Note pasted!'), findsNothing);
  });

  testWidgets('Adding a note shows a success alert', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AppShell()));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Note'));
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
}
