import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ourspace/data/content_repos.dart';
import 'package:ourspace/data/models/content.dart';
import 'package:ourspace/screens/tab_notes.dart';
import 'package:ourspace/theme/kawaii.dart';

MemoryNotesRepo _seeded() {
  final repo = MemoryNotesRepo();
  final now = DateTime.now();
  repo.seed('t', [
    Note(
        id: '1',
        spaceId: 't',
        authorId: 'june',
        body: 'Oat latte in fridge',
        colorIdx: 0,
        pinned: true,
        createdAt: now),
    Note(
        id: '2',
        spaceId: 't',
        authorId: 'maya',
        body: 'Dream: beach house',
        colorIdx: 1,
        pinned: false,
        createdAt: now.subtract(const Duration(hours: 1))),
    Note(
        id: '3',
        spaceId: 't',
        authorId: 'maya',
        body: 'Shared thank-you',
        colorIdx: 3,
        pinned: false,
        createdAt: now.subtract(const Duration(hours: 2))),
  ]);
  return repo;
}

Future<void> _pump(WidgetTester tester, MemoryNotesRepo repo) async {
  await tester.pumpWidget(MaterialApp(
    theme: Kawaii.light(),
    home: Scaffold(
        body: NotesTab(spaceId: 't', notesRepo: repo, myUid: 'maya')),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Notes filter Pinned shows only pinned', (tester) async {
    await _pump(tester, _seeded());
    expect(find.text('Oat latte in fridge'), findsOneWidget);

    await tester.tap(find.text('Pinned'));
    await tester.pumpAndSettle();

    expect(find.text('Oat latte in fridge'), findsOneWidget);
    expect(find.text('Dream: beach house'), findsNothing);
  });

  testWidgets('Notes filter Mine shows own notes', (tester) async {
    await _pump(tester, _seeded());
    await tester.tap(find.text('Mine'));
    await tester.pumpAndSettle();

    expect(find.text('Oat latte in fridge'), findsNothing);
    expect(find.text('Dream: beach house'), findsOneWidget);
    expect(find.text('Shared thank-you'), findsOneWidget);
  });

  testWidgets('Empty space shows empty state', (tester) async {
    await _pump(tester, MemoryNotesRepo());
    expect(find.text('No notes yet'), findsOneWidget);
  });
}
