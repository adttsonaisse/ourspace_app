import 'package:flutter_test/flutter_test.dart';
import 'package:ourspace/data/content_repos.dart';

void main() {
  test('MemoryNotesRepo CRUD + ordering', () async {
    final repo = MemoryNotesRepo();
    expect(await repo.list('s'), isEmpty);

    final a = await repo.create(
        spaceId: 's', body: 'first', colorIdx: 0);
    final b = await repo.create(
        spaceId: 's', body: 'second', colorIdx: 2);
    var all = await repo.list('s');
    expect(all.map((n) => n.id), [b.id, a.id]); // newest first

    await repo.togglePin(a.id, true);
    all = await repo.list('s');
    expect(all.firstWhere((n) => n.id == a.id).pinned, isTrue);

    await repo.remove(b.id);
    expect((await repo.list('s')).length, 1);

    // spaces are isolated
    await repo.create(spaceId: 'other', body: 'x', colorIdx: 0);
    expect((await repo.list('s')).length, 1);
  });

  test('MemoryDatesRepo sorts by day', () async {
    final repo = MemoryDatesRepo();
    final now = DateTime.now();
    await repo.create(
        spaceId: 's',
        title: 'later',
        note: '',
        place: '',
        day: now.add(const Duration(days: 5)));
    await repo.create(
        spaceId: 's',
        title: 'sooner',
        note: '',
        place: '',
        day: now.add(const Duration(days: 1)));
    final all = await repo.list('s');
    expect(all.map((d) => d.title), ['sooner', 'later']);

    await repo.remove(all.first.id);
    expect(await repo.list('s'), hasLength(1));
  });

  test('MemoryPilesRepo photos attach to pile', () async {
    final repo = MemoryPilesRepo();
    final p = await repo.create(
        spaceId: 's', title: 'Trip', location: 'Bali');
    expect(await repo.photos(p.id), isEmpty);
    await repo.addPhoto(pileId: p.id, r2Key: 'k1');
    expect((await repo.photos(p.id)).length, 1);
    await repo.removePile(p.id);
    expect(await repo.list('s'), isEmpty);
  });
}
