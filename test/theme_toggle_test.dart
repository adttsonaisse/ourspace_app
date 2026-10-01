import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ourspace/main.dart';
import 'package:ourspace/theme/kawaii.dart';

void main() {
  setUp(() => Kawaii.themeMode.value = ThemeMode.light);
  tearDown(() => Kawaii.themeMode.value = ThemeMode.light);

  testWidgets('Theme toggle flips light/dark', (tester) async {
    await tester.pumpWidget(const OurSpaceApp());
    await tester.pumpAndSettle();
    expect(Kawaii.themeMode.value, ThemeMode.light);

    Kawaii.themeMode.value = ThemeMode.dark;
    await tester.pumpAndSettle();

    final ctx = tester.element(find.byType(Scaffold));
    expect(Theme.of(ctx).brightness, Brightness.dark);
  });
}
