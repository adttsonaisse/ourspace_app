// Generic in-memory table backing the demo/test fakes: seeded lists per
// space, sorted reads, per-space watch streams, and id-based mutation
// with owner notification. The four Memory*Repos are thin adapters over
// this so the scaffolding lives once.

import 'dart:async';

class MemoryTable<T> {
  final String Function(T) idOf;
  final String Function(T) spaceOf;

  /// Comparator applied on read, or null to keep insertion order.
  final int Function(T, T)? sortBy;

  final Map<String, List<T>> _items = {};
  final _ctrl = StreamController<String>.broadcast();

  MemoryTable(
      {required this.idOf, required this.spaceOf, this.sortBy});

  /// Test/seed helper — UI never calls this.
  void seed(String spaceId, List<T> items) {
    _items[spaceId] = List.of(items);
    _ctrl.add(spaceId);
  }

  List<T> sorted(String spaceId) {
    final l = List<T>.of(_items[spaceId] ?? []);
    final cmp = sortBy;
    if (cmp != null) l.sort(cmp);
    return l;
  }

  Future<List<T>> list(String spaceId) async => sorted(spaceId);

  Stream<List<T>> watch(String spaceId) async* {
    yield sorted(spaceId);
    await for (final sid in _ctrl.stream) {
      if (sid == spaceId) yield sorted(spaceId);
    }
  }

  /// Insert or replace by id, then notify the owning space.
  void put(T item) {
    final spaceId = spaceOf(item);
    final l = _items[spaceId] ??= [];
    final i = l.indexWhere((e) => idOf(e) == idOf(item));
    if (i >= 0) {
      l[i] = item;
    } else {
      l.add(item);
    }
    _ctrl.add(spaceId);
  }

  /// Remove by id across all spaces; notifies the owner when found.
  void removeById(String id) {
    final spaceId = spaceOfId(id);
    if (spaceId == null) return;
    _items[spaceId]!.removeWhere((v) => idOf(v) == id);
    _ctrl.add(spaceId);
  }

  /// Replace the first item matching [test] with [update]; notifies.
  /// Returns false when nothing matched.
  bool updateFirst(bool Function(T) test, T Function(T) update) {
    for (final e in _items.entries) {
      final i = e.value.indexWhere(test);
      if (i >= 0) {
        e.value[i] = update(e.value[i]);
        _ctrl.add(e.key);
        return true;
      }
    }
    return false;
  }

  /// Owning space of [id], or null when absent.
  String? spaceOfId(String id) {
    for (final e in _items.entries) {
      if (e.value.any((v) => idOf(v) == id)) return e.key;
    }
    return null;
  }

  /// Manually poke a space (for side maps like pile photos).
  void touch(String spaceId) => _ctrl.add(spaceId);
}
