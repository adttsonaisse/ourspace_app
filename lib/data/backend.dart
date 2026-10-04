// Backend: one seam for every data dependency (cloud vs demo).
// Screens resolve this once; the cloud/demo choice lives here instead of
// scattered resolve* functions plus ad-hoc readiness checks per call site.

import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

import 'auth_repo.dart';
import 'content_repos.dart';
import 'photo_store.dart';
import 'r2.dart';
import 'repos.dart';
import 'space_repo.dart';
import 'supa.dart';

abstract class Backend {
  AuthRepo get auth;
  SpaceRepo get spaces;
  NotesRepo get notes;
  DatesRepo get dates;
  RitualsRepo get rituals;
  PilesRepo get piles;
  PhotoStore get photos;

  /// True when backed by Supabase (false = local demo).
  bool get isCloud;

  /// True when photo uploads can actually work. Demo is always ready
  /// (memory); cloud requires R2 configuration.
  bool get photoUploadsReady;
}

class SupabaseBackend implements Backend {
  final AuthRepo _auth = SupabaseAuthRepo();
  final SpaceRepo _spaces = SupabaseSpaceRepo();
  final NotesRepo _notes = SupabaseNotesRepo();
  final DatesRepo _dates = SupabaseDatesRepo();
  final RitualsRepo _rituals = SupabaseRitualsRepo();
  final PilesRepo _piles = SupabasePilesRepo();

  @override
  AuthRepo get auth => _auth;
  @override
  SpaceRepo get spaces => _spaces;
  @override
  NotesRepo get notes => _notes;
  @override
  DatesRepo get dates => _dates;
  @override
  RitualsRepo get rituals => _rituals;
  @override
  PilesRepo get piles => _piles;

  @override
  PhotoStore get photos => R2Client.instance == null
      ? const _PhotoStoreUnavailable()
      : R2PhotoStore();

  @override
  bool get isCloud => true;

  @override
  bool get photoUploadsReady => R2Client.instance != null;
}

class DemoBackend implements Backend {
  final DemoAuthRepo _auth = DemoAuthRepo();
  final DemoSpaceRepo _spaces = DemoSpaceRepo();
  final MemoryNotesRepo _notes = MemoryNotesRepo();
  final MemoryDatesRepo _dates = MemoryDatesRepo();
  final MemoryRitualsRepo _rituals = MemoryRitualsRepo();
  final MemoryPilesRepo _piles = MemoryPilesRepo();
  final MemoryPhotoStore _photos = MemoryPhotoStore();

  @override
  AuthRepo get auth => _auth;
  @override
  SpaceRepo get spaces => _spaces;
  @override
  NotesRepo get notes => _notes;
  @override
  DatesRepo get dates => _dates;
  @override
  RitualsRepo get rituals => _rituals;
  @override
  PilesRepo get piles => _piles;
  @override
  PhotoStore get photos => _photos;

  @override
  bool get isCloud => false;

  @override
  bool get photoUploadsReady => true;
}

/// Message when uploads cannot work (cloud space paired, R2 missing).
const kPhotoStorageMissing = 'Photo storage is not set up yet.';

/// PhotoStore that fails loudly with an actionable message instead of a
/// null-pointer deep in the R2 client. Used by [SupabaseBackend] when the
/// space is paired but R2 env is incomplete.
class _PhotoStoreUnavailable implements PhotoStore {
  const _PhotoStoreUnavailable();

  @override
  Future<String> upload(
          {required String spaceId,
          required String pileId,
          required XFile file}) =>
      throw StateError(kPhotoStorageMissing);

  @override
  Future<Uint8List?> bytes(String r2Key) async => null;

  @override
  Future<String> url(String r2Key) => throw StateError(kPhotoStorageMissing);

  @override
  Future<void> remove(String r2Key) async {}
}

Backend? _backendSingleton;

/// App-wide backend (mirrors the Supabase client singleton): every screen
/// shares one instance so demo sessions and in-memory pages propagate.
Backend resolveBackend() =>
    _backendSingleton ??= Supa.ready ? SupabaseBackend() : DemoBackend();

/// Test seam: drop the shared instance (env never changes at runtime).
void resetBackendForTest() => _backendSingleton = null;

// Legacy resolvers: thin wrappers so existing call sites keep working.
// New code should resolve Backend once and read repos off it.
AuthRepo resolveAuthRepo() => resolveBackend().auth;
SpaceRepo resolveSpaceRepo() => resolveBackend().spaces;
NotesRepo resolveNotesRepo() => resolveBackend().notes;
DatesRepo resolveDatesRepo() => resolveBackend().dates;
RitualsRepo resolveRitualsRepo() => resolveBackend().rituals;
PilesRepo resolvePilesRepo() => resolveBackend().piles;
