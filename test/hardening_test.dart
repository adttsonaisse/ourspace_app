import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ourspace/data/content_repos.dart';
import 'package:ourspace/data/models/content.dart';
import 'package:ourspace/data/repos.dart';
import 'package:ourspace/screens/tab_notes.dart';
import 'package:ourspace/theme/kawaii.dart';
import 'package:ourspace/widgets/offline_banner.dart';

class _FailNotes extends MemoryNotesRepo {
  @override
  Stream<List<Note>> watch(String spaceId) =>
      Stream.error(StateError('boom offline'));
}

void main() {
  testWidgets('Notes error state with retry', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: Kawaii.light(),
      home: Scaffold(
          body: NotesTab(
              spaceId: 's', notesRepo: _FailNotes(), myUid: 'u')),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Could not load notes'), findsOneWidget);
    expect(find.textContaining('boom'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('Offline banner shows only when offline', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: OfflineBanner(
              stream: Stream.value([ConnectivityResult.none]))),
    ));
    await tester.pumpAndSettle();
    expect(find.text('No connection — changes won’t sync'), findsOneWidget);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: OfflineBanner(
              stream: Stream.value([ConnectivityResult.wifi]))),
    ));
    await tester.pumpAndSettle();
    expect(find.text('No connection — changes won’t sync'), findsNothing);
  });

  test('NotesRepo abstract is satisfied by memory impl', () {
    // Compile-time contract check: MemoryNotesRepo must stay a NotesRepo
    // so tabs never depend on Supabase directly.
    expect(MemoryNotesRepo(), isA<NotesRepo>());
  });
}
