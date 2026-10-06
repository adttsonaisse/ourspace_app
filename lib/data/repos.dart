// Repository contracts. UI depends on these, never on Supabase directly.
// Supabase implementations land in M2–M5; fakes back the widget tests.

import 'models/space.dart';
import 'models/content.dart';

/// Local identity used across every demo-mode fake. Single source so the
/// sentinel values never drift between modules (values are stable API:
/// tests and persisted prefs depend on them).
const kDemoUid = 'demo-user';
const kDemoSpaceId = 'local';

abstract class AuthRepo {
  Future<void> signUp(String email, String password, {String? username});
  Future<void> signIn(String email, String password);
  Future<void> signOut();
  String? get currentUserId;
  String? get currentUsername;
  String? get currentEmail;
  Stream<String?> watchAuth();
}

abstract class SpaceRepo {
  /// Space of the current user, null when unpaired/solo.
  Future<Space?> mySpace();
  Future<Space> createSpace(String name);
  Future<InviteCode> createInvite(String spaceId);
  Future<Space> joinWithCode(String code);
  Future<void> leave(String spaceId);
  Stream<Space?> watchMySpace();
  Future<void> ensureProfile({String? username});
  Future<List<MemberProfile>> membersWithProfiles(String spaceId);
  Future<void> updateAnniversary(String spaceId, DateTime date);
}

abstract class NotesRepo {
  Future<List<Note>> list(String spaceId);
  Stream<List<Note>> watch(String spaceId);
  Future<Note> create(
      {required String spaceId,
      required String body,
      required int colorIdx});
  Future<void> togglePin(String id, bool pinned);
  Future<void> remove(String id);
}

abstract class PilesRepo {
  Future<List<Pile>> list(String spaceId);
  Stream<List<Pile>> watch(String spaceId);
  Future<Pile> create(
      {required String spaceId,
      required String title,
      required String location});
  Future<List<PilePhoto>> photos(String pileId);
  Future<PilePhoto> addPhoto(
      {required String pileId, required String r2Key});
  Future<void> removePhoto(String id);
  Future<void> removePile(String id);
}

abstract class DatesRepo {
  Future<List<DatePlan>> list(String spaceId);
  Stream<List<DatePlan>> watch(String spaceId);
  Future<DatePlan> create(
      {required String spaceId,
      required String title,
      required String note,
      required String place,
      required DateTime day});
  Future<void> remove(String id);
}
