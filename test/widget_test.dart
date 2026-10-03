import 'package:flutter_test/flutter_test.dart';
import 'package:ourspace/main.dart';

void main() {
  testWidgets('OurSpace boots to Get Started', (WidgetTester tester) async {
    await tester.pumpWidget(const OurSpaceApp());
    await tester.pumpAndSettle();
    expect(find.textContaining('universe of two'), findsOneWidget);
    expect(find.textContaining('Get started'), findsOneWidget);
  });
}
