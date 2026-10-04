import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ourspace/theme/kawaii.dart';
import 'package:ourspace/widgets/kawaii.dart';

void main() {
  testWidgets('showKawaiiToast shows styled message per kind',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: Kawaii.light(),
      home: Scaffold(
        body: Builder(
          builder: (ctx) => KawaiiButton(
            label: 'ping',
            onTap: () => showKawaiiToast(ctx, 'hello toast',
                kind: KawaiiAlertKind.success),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('ping'));
    await tester.pump();

    expect(find.text('hello toast'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });
}
