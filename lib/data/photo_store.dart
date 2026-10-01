// Photo bytes: R2 (paired) or in-memory (solo/demo/tests).
// Galleries checks bytes() first (local demo photos), else loads url()
// (presigned R2). DB rows stay in PilesRepo; this owns only the blobs.

import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

import 'r2.dart';

abstract class PhotoStore {
  /// Stores the file, returns the key to save in pile_photos.r2_key.
  Future<String> upload(
      {required String spaceId,
      required String pileId,
      required XFile file});

  /// Local bytes when available (memory store), else null.
  Future<Uint8List?> bytes(String r2Key);

  /// Remote read URL (presigned R2). Memory keys throw — check bytes().
  Future<String> url(String r2Key);

  /// Best-effort blob delete; row deletes live in PilesRepo.
  Future<void> remove(String r2Key);
}

String _safeName(String name) =>
    name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');

class R2PhotoStore implements PhotoStore {
  R2Client _req() {
    final c = R2Client.instance;
    if (c == null) throw StateError('Photo storage not configured.');
    return c;
  }

  @override
  Future<String> upload(
      {required String spaceId,
      required String pileId,
      required XFile file}) async {
    final c = _req();
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) throw StateError('That photo was empty.');
    final key = c.objectKey(spaceId, pileId,
        '${DateTime.now().millisecondsSinceEpoch}-${_safeName(file.name)}');
    try {
      await c.putBytes(key, bytes);
    } catch (e) {
      throw StateError(
          'Upload failed. Check internet and retry. ($e)'.split(' (').first);
    }
    return key;
  }

  @override
  Future<Uint8List?> bytes(String r2Key) async => null;

  @override
  Future<String> url(String r2Key) async {
    try {
      return await _req().presignedGet(r2Key);
    } catch (e) {
      throw StateError('Could not open photo. ($e)'.split(' (').first);
    }
  }

  @override
  Future<void> remove(String r2Key) async {
    try {
      await _req().remove(r2Key);
    } catch (_) {
      // Orphaned R2 objects are invisible + cheap; DB row is truth.
    }
  }
}

class MemoryPhotoStore implements PhotoStore {
  final _blobs = <String, Uint8List>{};

  @override
  Future<String> upload(
      {required String spaceId,
      required String pileId,
      required XFile file}) async {
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) throw StateError('That photo was empty.');
    final key =
        'mem/$spaceId/$pileId/${DateTime.now().millisecondsSinceEpoch}-${file.name}';
    _blobs[key] = bytes;
    return key;
  }

  @override
  Future<Uint8List?> bytes(String r2Key) async => _blobs[r2Key];

  @override
  Future<String> url(String r2Key) =>
      throw StateError('Local photo — use bytes().');

  @override
  Future<void> remove(String r2Key) async {
    _blobs.remove(r2Key);
  }
}
