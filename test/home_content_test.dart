import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ourspace/data/content_repos.dart';
import 'package:ourspace/data/models/space.dart';
import 'package:ourspace/data/photo_store.dart';
import 'package:ourspace/screens/tab_home.dart';
import 'package:ourspace/theme/kawaii.dart';
import 'package:ourspace/widgets/kawaii_fab.dart';

class _FakePhotos implements PhotoStore {
  @override
  Future<String> upload(
          {required String spaceId,
          required String pileId,
          required XFile file}) =>
      Future.value('k');
  @override
  Future<Uint8List?> bytes(String r2Key) async => null;
  @override
  Future<String> url(String r2Key) => Future.value('https://x');
  @override
  Future<void> remove(String r2Key) async {}
}

Future<void> _pump(
  WidgetTester tester, {
  MemoryNotesRepo? notes,
  MemoryDatesRepo? dates,
  MemoryPilesRepo? piles,
  List<MemberProfile> members = const [],
}) async {
  await tester.pumpWidget(MaterialApp(
    theme: Kawaii.light(),
    home: Scaffold(
        body: HomeTab(
            space: null,
            members: members,
            notesRepo: notes ?? MemoryNotesRepo(),
            datesRepo: dates ?? MemoryDatesRepo(),
            pilesRepo: piles ?? MemoryPilesRepo(),
            photoStore: _FakePhotos())),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Empty home shows fresh page + CTA', (tester) async {
    await _pump(tester);
    expect(find.text('Fresh page, you two'), findsOneWidget);
    expect(find.text('Drop a sweet note'), findsOneWidget);
    expect(find.text('Today in ourspace'), findsOneWidget);
  });

  testWidgets('Next date is the large highlight', (tester) async {
    final dates = MemoryDatesRepo();
    final now = DateTime.now();
    await dates.create(
        spaceId: 'local',
        title: 'Sunset picnic',
        note: '',
        place: 'Park',
        day: DateTime(now.year, now.month, now.day + 1));
    await _pump(tester, dates: dates);
    expect(find.text('Sunset picnic'), findsOneWidget);
    expect(find.textContaining('Next up'), findsOneWidget);
  });

  testWidgets('Quick actions call onCreate', (tester) async {
    CreateKind? tapped;
    await tester.pumpWidget(MaterialApp(
      theme: Kawaii.light(),
      home: Scaffold(
          body: HomeTab(
              space: null,
              notesRepo: MemoryNotesRepo(),
              datesRepo: MemoryDatesRepo(),
              pilesRepo: MemoryPilesRepo(),
              photoStore: _FakePhotos(),
              onCreate: (k) => tapped = k)),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Note'));
    expect(tapped, CreateKind.note);
  });

  testWidgets('Pair title uses member names', (tester) async {
    await _pump(tester, members: const [
      MemberProfile(userId: 'demo-user', username: 'Mochi'),
      MemberProfile(userId: 'p2', username: 'Boba'),
    ]);
    expect(find.text('Mochi & Boba'), findsOneWidget);
  });

  test('Space effectiveAnniversary falls back to createdAt', () {
    final created = DateTime(2023, 2, 12);
    final s = Space(
        id: 's', name: 'n', createdBy: 'u', createdAt: created);
    expect(s.effectiveAnniversary, created);
    final s2 = Space(
        id: 's',
        name: 'n',
        createdBy: 'u',
        createdAt: created,
        anniversaryDate: DateTime(2024, 5, 1));
    expect(s2.effectiveAnniversary, DateTime(2024, 5, 1));
  });
}
