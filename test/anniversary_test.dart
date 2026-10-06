import 'package:flutter_test/flutter_test.dart';
import 'package:ourspace/data/space_repo.dart';

void main() {
  test('DemoSpaceRepo updateAnniversary changes effective date', () async {
    final repo = DemoSpaceRepo();
    final space = await repo.createSpace('Our space');
    expect(space.effectiveAnniversary, space.createdAt);

    final picked = DateTime(2023, 5, 17);
    await repo.updateAnniversary(space.id, picked);
    final updated = await repo.mySpace();
    expect(updated, isNotNull);
    expect(updated!.anniversaryDate, DateTime(2023, 5, 17));
    expect(updated.effectiveAnniversary, DateTime(2023, 5, 17));
  });

  test('DemoSpaceRepo updateAnniversary needs a space', () async {
    final repo = DemoSpaceRepo();
    expect(
      () => repo.updateAnniversary('nope', DateTime(2023, 1, 1)),
      throwsA(isA<StateError>()),
    );
  });
}
