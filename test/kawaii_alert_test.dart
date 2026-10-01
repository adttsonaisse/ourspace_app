import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ourspace/theme/kawaii.dart';
import 'package:ourspace/widgets/kawaii.dart';

void main() {
  Future<void> pumpAlert(
      WidgetTester tester, KawaiiAlert alert) async {
    await tester.pumpWidget(MaterialApp(
      theme: Kawaii.light(),
      home: Scaffold(body: SingleChildScrollView(child: alert)),
    ));
    await tester.pumpAndSettle();
  }

  for (final kind in KawaiiAlertKind.values) {
    testWidgets('KawaiiAlert renders $kind', (tester) async {
      await pumpAlert(
        tester,
        KawaiiAlert(
          title: 'Title $kind',
          message: 'A message long enough to wrap onto a second line '
              'without clipping or overflowing its sticker card.',
          kind: kind,
        ),
      );
      expect(find.text('Title $kind'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsNothing);
    });
  }

  testWidgets('KawaiiAlert dismiss calls onClose', (tester) async {
    var closed = false;
    await pumpAlert(
      tester,
      KawaiiAlert(
        title: 'Heads up',
        message: 'Dismiss me.',
        kind: KawaiiAlertKind.warning,
        onClose: () => closed = true,
      ),
    );
    await tester.tap(find.byIcon(Icons.close_rounded));
    expect(closed, isTrue);
  });

  testWidgets('KawaiiAlert action calls onAction', (tester) async {
    var acted = false;
    await pumpAlert(
      tester,
      KawaiiAlert(
        title: 'Failed to sync',
        message: 'Check your connection and retry.',
        kind: KawaiiAlertKind.danger,
        actionLabel: 'Retry',
        onAction: () => acted = true,
      ),
    );
    await tester.tap(find.text('Retry'));
    expect(acted, isTrue);
  });
}
