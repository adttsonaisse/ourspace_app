// Storage hygiene: keeps app data bounded so it never balloons to
// hundreds of MB again. Covers the three real hogs found on-device:
// image_picker leftovers in cache/, stale OTA APKs in files/ota_update/,
// and unbounded image caches.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Photo cache: 200 files / 30 days. Enough for piles, small enough that
/// even full-res photos can't push storage into the hundreds of MB.
CacheManager get photoCache => CacheManager(
      Config(
        'ourspacePhotos',
        stalePeriod: const Duration(days: 30),
        maxNrOfCacheObjects: 200,
      ),
    );

String formatBytes(int bytes) {
  if (bytes <= 0) return '0 KB';
  const units = ['B', 'KB', 'MB', 'GB'];
  var v = bytes.toDouble();
  var i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  return i == 0
      ? '${v.toStringAsFixed(0)} ${units[i]}'
      : '${v.toStringAsFixed(v >= 100 ? 0 : 1)} ${units[i]}';
}

bool _isPickerLeftover(String name) {
  final n = name.toLowerCase();
  return n.startsWith('image_picker') ||
      n.startsWith('scaled_') ||
      n.startsWith('cropped_') ||
      n.startsWith('picked_') ||
      (n.startsWith('image_cropper_'));
}

Future<List<Directory>> _cacheDirs() async {
  final out = <Directory>[];
  try {
    out.add(await getTemporaryDirectory());
  } catch (_) {}
  try {
    out.add(await getApplicationCacheDirectory());
  } catch (_) {}
  // Dedupe by path.
  final seen = <String>{};
  return out.where((d) => seen.add(d.path)).toList();
}

/// Directories that may hold OTA APKs.
/// Plugin writes to `<dataDir>/files/ota_update/<filename>`.
Future<List<Directory>> _otaDirs() async {
  final out = <Directory>[];
  try {
    final tmp = await getTemporaryDirectory();
    // tmp = <dataDir>/cache, so parent = <dataDir>.
    final dataDir = tmp.parent;
    out.add(Directory('${dataDir.path}/files/ota_update'));
  } catch (_) {}
  try {
    final docs = await getApplicationDocumentsDirectory();
    // app_flutter sibling of files/.
    final files = Directory('${docs.parent.path}/files/ota_update');
    if (!out.any((d) => d.path == files.path)) out.add(files);
  } catch (_) {}
  return out;
}

Future<int> _dirBytes(Directory dir) async {
  var total = 0;
  try {
    if (!await dir.exists()) return 0;
    await for (final e in dir.list(recursive: true, followLinks: false)) {
      try {
        if (e is File) total += await e.length();
      } catch (_) {}
    }
  } catch (_) {}
  return total;
}

/// Best-effort delete of one picked file (the image_picker cache copy).
/// Safe to call on web / XFile.fromData (no real path) — just no-ops.
Future<void> deletePickedFile(XFile file) async {
  if (kIsWeb) return;
  try {
    final p = file.path;
    if (p.isEmpty || p.startsWith('blob:')) return;
    final f = File(p);
    if (await f.exists()) await f.delete();
  } catch (_) {}
}

/// Startup sweep: picker leftovers + old OTA APKs (keeps newest 1).
/// Never throws — storage cleanup must not break launch.
Future<void> cleanupStaleAppFiles() async {
  if (kIsWeb) return;
  try {
    for (final dir in await _cacheDirs()) {
      try {
        if (!await dir.exists()) continue;
        await for (final e in dir.list(followLinks: false)) {
          try {
            if (e is File && _isPickerLeftover(e.path.split('/').last)) {
              await e.delete();
            }
          } catch (_) {}
        }
      } catch (_) {}
    }
    await pruneOtaUpdates(keepNewest: 1);
  } catch (_) {}
}

/// Delete old `ourspace-*.apk`, keep the newest [keepNewest].
Future<void> pruneOtaUpdates({int keepNewest = 1}) async {
  if (kIsWeb) return;
  try {
    for (final dir in await _otaDirs()) {
      try {
        if (!await dir.exists()) continue;
        final apks = <File>[];
        await for (final e in dir.list(followLinks: false)) {
          if (e is File && e.path.toLowerCase().endsWith('.apk')) {
            apks.add(e);
          }
        }
        if (apks.length <= keepNewest) continue;
        final withTime = <(File, DateTime)>[];
        for (final f in apks) {
          try {
            withTime.add((f, await f.lastModified()));
          } catch (_) {
            withTime.add((f, DateTime.fromMillisecondsSinceEpoch(0)));
          }
        }
        withTime.sort((a, b) => b.$2.compareTo(a.$2));
        for (var i = keepNewest; i < withTime.length; i++) {
          try {
            await withTime[i].$1.delete();
          } catch (_) {}
        }
      } catch (_) {}
    }
  } catch (_) {}
}

/// Total reclaimable bytes: temp/cache + photo cache + OTA folder.
Future<int> getAppCacheBytes() async {
  if (kIsWeb) return 0;
  var total = 0;
  try {
    for (final dir in await _cacheDirs()) {
      total += await _dirBytes(dir);
    }
    for (final dir in await _otaDirs()) {
      total += await _dirBytes(dir);
    }
  } catch (_) {}
  return total;
}

/// Manual "Clear cache" from Settings: memory + disk, never throws.
Future<void> clearAppCaches() async {
  try {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  } catch (_) {}
  try {
    await photoCache.emptyCache();
  } catch (_) {}
  try {
    await DefaultCacheManager().emptyCache();
  } catch (_) {}
  if (kIsWeb) return;
  try {
    for (final dir in await _cacheDirs()) {
      try {
        if (!await dir.exists()) continue;
        await for (final e in dir.list(followLinks: false)) {
          try {
            final name = e.path.split('/').last;
            if (e is File &&
                (_isPickerLeftover(name) ||
                    name == 'image_cache' ||
                    e.path.contains('libCachedImageData'))) {
              await e.delete();
            } else if (e is Directory &&
                (name == 'libCachedImageData' ||
                    name == 'fm_cache' ||
                    name == 'image_cache')) {
              await e.delete(recursive: true);
            }
          } catch (_) {}
        }
      } catch (_) {}
    }
    // Deleting libCachedImageData files above may leave empty dirs;
    // emptyCache() already dropped the index, so a rescan rebuilds clean.
    await pruneOtaUpdates(keepNewest: 1);
  } catch (_) {}
}
