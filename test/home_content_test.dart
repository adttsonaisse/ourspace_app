import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ourspace/data/content_repos.dart';
import 'package:ourspace/data/models/content.dart';
import 'package:ourspace/screens/tab_home.dart';
import 'package:ourspace/theme/kawaii.dart';

Future<void> _pump(WidgetTester tester, MemoryNotesRepo notes,
    MemoryRitualsRepo rituals) async {
  await tester.pumpWidget(MaterialApp(
    theme: Kawaii.light(),
    home: Scaffold(
        body: HomeTab(
            space: null, notesRepo: notes, ritualsRepo: rituals)),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Ritual toggle persists in repo', (tester) async {
    final notes = MemoryNotesRepo();
    final rituals = MemoryRitualsRepo();
    final now = DateTime.now();
    rituals.seed('local', [
      Ritual(
          id: 'r1',
          spaceId: 'local',
          title: 'Film Friday',
          colorIdx: 0,
          done: false,
          sort: 0,
          updatedAt: now),
    ]);
    await _pump(tester, notes, rituals);
    expect(find.text('0/1 done'), findsOneWidget);

    await tester.tap(find.text('Film Friday'));
    await tester.pumpAndSettle();

    expect(find.text('1/1 done'), findsOneWidget);
    final stored = await rituals.list('local');
    expect(stored.single.done, isTrue);
  });

  testWidgets('Empty home shows note + ritual empty states', (tester) async {
    await _pump(tester, MemoryNotesRepo(), MemoryRitualsRepo());
    expect(find.textContaining('No notes yet'), findsOneWidget);
    expect(find.text('fresh page'), findsOneWidget);
  });
}
