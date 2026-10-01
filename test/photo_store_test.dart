import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ourspace/data/content_repos.dart';
import 'package:ourspace/data/photo_store.dart';
import 'package:ourspace/screens/tab_galleries.dart';
import 'package:ourspace/theme/kawaii.dart';

// 1x1 transparent PNG — decodes for real, no disk needed (disk IO hangs
// inside testWidgets' FakeAsync zone, so XFile.fromData is used).
final _png1x1 = Uint8List.fromList([
  137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, //
  0, 0, 0, 1, 0, 0, 0, 1, 8, 6, 0, 0, 0, 31, 21, 196, 137, //
  0, 0, 0, 13, 73, 68, 65, 84, 120, 156, 99, 250, 207, 207, 0, //
  0, 3, 5, 1, 2, 233, 204, 11, 232, 0, 0, 0, 0, 73, 69, 78, //
  68, 174, 66, 96, 130,
]);

XFile _photo(String name) =>
    XFile.fromData(_png1x1, name: name, mimeType: 'image/png');

void main() {
  test('MemoryPhotoStore round-trips bytes', () async {
    final store = MemoryPhotoStore();
    final key = await store.upload(
        spaceId: 's', pileId: 'p', file: _photo('a.png'));
    expect(key.startsWith('mem/s/p/'), isTrue);
    final bytes = await store.bytes(key);
    expect(bytes, isNotNull);
    expect(bytes!.length, _png1x1.length);
    await store.remove(key);
    expect(await store.bytes(key), isNull);
  });

  testWidgets('Galleries empty state', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: Kawaii.light(),
      home: Scaffold(
          body: GalleriesTab(
              spaceId: 's',
              pilesRepo: MemoryPilesRepo(),
              photoStore: MemoryPhotoStore())),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Start the first pile'), findsOneWidget);
  });

  testWidgets('Galleries shows pile with photo count', (tester) async {
    final piles = MemoryPilesRepo();
    final photos = MemoryPhotoStore();
    final pile = await piles.create(
        spaceId: 's', title: 'Beach daze', location: 'Bali');
    final key = await photos.upload(
        spaceId: 's', pileId: pile.id, file: _photo('b.png'));
    await piles.addPhoto(pileId: pile.id, r2Key: key);

    await tester.pumpWidget(MaterialApp(
      theme: Kawaii.light(),
      home: Scaffold(
          body: GalleriesTab(
              spaceId: 's', pilesRepo: piles, photoStore: photos)),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Beach daze'), findsOneWidget);
    expect(find.text('1 piles • 1 pics'), findsOneWidget);
  });
}
