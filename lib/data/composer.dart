// Composer: multi-step creation flows (note/pile/date) as a testable
// data-layer service. Widgets own validation + form state; this owns the
// orchestration (create pile -> upload N photos -> attach N rows) so the
// failure policy lives in one place with unit tests. Repo errors are
// already user-facing StateErrors — this lets them propagate.

import 'package:image_picker/image_picker.dart';

import 'backend.dart';

class PileUploadReport {
  final int failed;
  const PileUploadReport(this.failed);
}

class AppComposer {
  final Backend backend;
  const AppComposer(this.backend);

  Future<void> createNote({
    required String spaceId,
    required String body,
    required int colorIdx,
  }) async {
    await backend.notes
        .create(spaceId: spaceId, body: body, colorIdx: colorIdx);
  }

  /// Creates the pile, then uploads + attaches each image. Aborts before
  /// creating anything when photo uploads cannot work, so no orphan pile
  /// lingers. Returns how many photos failed (0 = all attached).
  Future<PileUploadReport> createPile({
    required String spaceId,
    required String title,
    required String location,
    required List<XFile> images,
  }) async {
    if (images.isNotEmpty && !backend.photoUploadsReady) {
      throw StateError(kPhotoStorageMissing);
    }
    final pile = await backend.piles
        .create(spaceId: spaceId, title: title, location: location);
    var failed = 0;
    for (final img in images) {
      try {
        final key = await backend.photos.upload(
            spaceId: spaceId, pileId: pile.id, file: img);
        await backend.piles.addPhoto(pileId: pile.id, r2Key: key);
      } catch (_) {
        failed++;
      }
    }
    return PileUploadReport(failed);
  }

  Future<void> createDate({
    required String spaceId,
    required String title,
    required String note,
    required String place,
    required DateTime day,
  }) async {
    await backend.dates.create(
        spaceId: spaceId,
        title: title,
        note: note,
        place: place,
        day: day);
  }
}
