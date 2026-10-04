import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ourspace/data/backend.dart';
import 'package:ourspace/data/composer.dart';

class _NoStoreBackend extends DemoBackend {
  @override
  bool get photoUploadsReady => false;
}

XFile _photo(String name) => XFile.fromData(
      Uint8List.fromList([1, 2, 3, 4]),
      name: name,
      mimeType: 'image/jpeg',
    );

void main() {
  test('createNote stores the note', () async {
    final backend = DemoBackend();
    await AppComposer(backend).createNote(
        spaceId: 's', body: 'hello', colorIdx: 2);
    final notes = await backend.notes.list('s');
    expect(notes, hasLength(1));
    expect(notes.first.body, 'hello');
    expect(notes.first.colorIdx, 2);
  });

  test('createPile attaches uploaded photos', () async {
    final backend = DemoBackend();
    final report = await AppComposer(backend).createPile(
        spaceId: 's', title: 'trip', location: 'beach',
        images: [_photo('a.jpg'), _photo('b.jpg')]);
    expect(report.failed, 0);
    final piles = await backend.piles.list('s');
    expect(piles, hasLength(1));
    expect(await backend.piles.photos(piles.first.id), hasLength(2));
  });

  test('createPile without storage aborts before creating', () async {
    final backend = _NoStoreBackend();
    final composer = AppComposer(backend);
    await expectLater(
      composer.createPile(
          spaceId: 's', title: 'trip', location: '',
          images: [_photo('a.jpg')]),
      throwsA(isA<StateError>().having(
          (e) => e.message, 'message', kPhotoStorageMissing)),
    );
    expect(await backend.piles.list('s'), isEmpty);
  });

  test('createDate stores the plan', () async {
    final backend = DemoBackend();
    await AppComposer(backend).createDate(
        spaceId: 's',
        title: 'picnic',
        note: 'bring blanket',
        place: 'park',
        day: DateTime(2026, 10, 5));
    final plans = await backend.dates.list('s');
    expect(plans, hasLength(1));
    expect(plans.first.title, 'picnic');
  });
}
