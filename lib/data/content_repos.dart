// Content repos: Supabase (cloud) + Memory (solo/demo/tests).
// Tabs depend on the abstracts in repos.dart and never touch Supabase.

import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/content.dart';
import 'repos.dart';
import 'space_repo.dart' show friendlySpaceError;
import 'supa.dart';

// ---------------- notes ----------------

class SupabaseNotesRepo implements NotesRepo {
  SupabaseClient get _c => Supa.client;

  @override
  Future<List<Note>> list(String spaceId) async {
    try {
      final rows = await _c
          .from('notes')
          .select()
          .eq('space_id', spaceId)
          .order('created_at', ascending: false);
      return [
        for (final r in rows)
          Note.fromJson(Map<String, dynamic>.from(r as Map))
      ];
    } catch (e) {
      throw StateError(friendlySpaceError(e));
    }
  }

  @override
  Stream<List<Note>> watch(String spaceId) {
    return _c
        .from('notes')
        .stream(primaryKey: ['id'])
        .eq('space_id', spaceId)
        .order('created_at', ascending: false)
        .map((rows) => [
              for (final r in rows)
                Note.fromJson(Map<String, dynamic>.from(r as Map))
            ])
        .handleError((Object e) {
      throw StateError(friendlySpaceError(e));
    });
  }

  @override
  Future<Note> create(
      {required String spaceId,
      required String body,
      required int colorIdx}) async {
    try {
      final uid = _c.auth.currentUser?.id;
      if (uid == null) throw StateError('Log in first.');
      final row = await _c
          .from('notes')
          .insert({
            'space_id': spaceId,
            'author_id': uid,
            'body': body,
            'color_idx': colorIdx,
          })
          .select()
          .single();
      return Note.fromJson(Map<String, dynamic>.from(row as Map));
    } catch (e) {
      throw StateError(friendlySpaceError(e));
    }
  }

  @override
  Future<void> togglePin(String id, bool pinned) async {
    try {
      await _c.from('notes').update({'pinned': pinned}).eq('id', id);
    } catch (e) {
      throw StateError(friendlySpaceError(e));
    }
  }

  @override
  Future<void> remove(String id) async {
    try {
      await _c.from('notes').delete().eq('id', id);
    } catch (e) {
      throw StateError(friendlySpaceError(e));
    }
  }
}

class MemoryNotesRepo implements NotesRepo {
  final Map<String, List<Note>> _items = {};
  final _ctrl = StreamController<String>.broadcast();
  int _seq = 0;

  /// Test/seed helper — UI never calls this.
  void seed(String spaceId, List<Note> notes) {
    _items[spaceId] = List.of(notes);
    _ctrl.add(spaceId);
  }

  List<Note> _sorted(String spaceId) {
    final l = List<Note>.of(_items[spaceId] ?? []);
    l.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return l;
  }

  @override
  Future<List<Note>> list(String spaceId) async => _sorted(spaceId);

  @override
  Stream<List<Note>> watch(String spaceId) async* {
    yield _sorted(spaceId);
    await for (final sid in _ctrl.stream) {
      if (sid == spaceId) yield _sorted(spaceId);
    }
  }

  @override
  Future<Note> create(
      {required String spaceId,
      required String body,
      required int colorIdx}) async {
    final n = Note(
      id: 'm${_seq++}',
      spaceId: spaceId,
      authorId: 'demo-user',
      body: body,
      colorIdx: colorIdx,
      pinned: false,
      createdAt: DateTime.now(),
    );
    (_items[spaceId] ??= []).add(n);
    _ctrl.add(spaceId);
    return n;
  }

  @override
  Future<void> togglePin(String id, bool pinned) async {
    for (final l in _items.values) {
      final i = l.indexWhere((n) => n.id == id);
      if (i >= 0) {
        l[i] = Note(
            id: l[i].id,
            spaceId: l[i].spaceId,
            authorId: l[i].authorId,
            body: l[i].body,
            colorIdx: l[i].colorIdx,
            pinned: pinned,
            createdAt: l[i].createdAt);
        _ctrl.add(l[i].spaceId);
        return;
      }
    }
  }

  @override
  Future<void> remove(String id) async {
    for (final e in _items.entries) {
      if (e.value.any((n) => n.id == id)) {
        e.value.removeWhere((n) => n.id == id);
        _ctrl.add(e.key);
        return;
      }
    }
  }
}

// ---------------- dates ----------------

class SupabaseDatesRepo implements DatesRepo {
  SupabaseClient get _c => Supa.client;

  @override
  Future<List<DatePlan>> list(String spaceId) async {
    try {
      final rows = await _c
          .from('date_plans')
          .select()
          .eq('space_id', spaceId)
          .order('day');
      return [
        for (final r in rows)
          DatePlan.fromJson(Map<String, dynamic>.from(r as Map))
      ];
    } catch (e) {
      throw StateError(friendlySpaceError(e));
    }
  }

  @override
  Stream<List<DatePlan>> watch(String spaceId) {
    return _c
        .from('date_plans')
        .stream(primaryKey: ['id'])
        .eq('space_id', spaceId)
        .order('day')
        .map((rows) => [
              for (final r in rows)
                DatePlan.fromJson(Map<String, dynamic>.from(r as Map))
            ])
        .handleError((Object e) {
      throw StateError(friendlySpaceError(e));
    });
  }

  @override
  Future<DatePlan> create(
      {required String spaceId,
      required String title,
      required String note,
      required String place,
      required DateTime day}) async {
    try {
      final uid = _c.auth.currentUser?.id;
      if (uid == null) throw StateError('Log in first.');
      final row = await _c
          .from('date_plans')
          .insert({
            'space_id': spaceId,
            'title': title,
            'note': note,
            'place': place,
            'day': day.toIso8601String().substring(0, 10),
            'created_by': uid,
          })
          .select()
          .single();
      return DatePlan.fromJson(Map<String, dynamic>.from(row as Map));
    } catch (e) {
      throw StateError(friendlySpaceError(e));
    }
  }

  @override
  Future<void> remove(String id) async {
    try {
      await _c.from('date_plans').delete().eq('id', id);
    } catch (e) {
      throw StateError(friendlySpaceError(e));
    }
  }
}

class MemoryDatesRepo implements DatesRepo {
  final Map<String, List<DatePlan>> _items = {};
  final _ctrl = StreamController<String>.broadcast();
  int _seq = 0;

  void seed(String spaceId, List<DatePlan> plans) {
    _items[spaceId] = List.of(plans);
    _ctrl.add(spaceId);
  }

  List<DatePlan> _sorted(String spaceId) {
    final l = List<DatePlan>.of(_items[spaceId] ?? []);
    l.sort((a, b) => a.day.compareTo(b.day));
    return l;
  }

  @override
  Future<List<DatePlan>> list(String spaceId) async => _sorted(spaceId);

  @override
  Stream<List<DatePlan>> watch(String spaceId) async* {
    yield _sorted(spaceId);
    await for (final sid in _ctrl.stream) {
      if (sid == spaceId) yield _sorted(spaceId);
    }
  }

  @override
  Future<DatePlan> create(
      {required String spaceId,
      required String title,
      required String note,
      required String place,
      required DateTime day}) async {
    final p = DatePlan(
      id: 'm${_seq++}',
      spaceId: spaceId,
      title: title,
      note: note,
      place: place,
      day: day,
      createdBy: 'demo-user',
      createdAt: DateTime.now(),
    );
    (_items[spaceId] ??= []).add(p);
    _ctrl.add(spaceId);
    return p;
  }

  @override
  Future<void> remove(String id) async {
    for (final e in _items.entries) {
      if (e.value.any((p) => p.id == id)) {
        e.value.removeWhere((p) => p.id == id);
        _ctrl.add(e.key);
        return;
      }
    }
  }
}

// ---------------- rituals ----------------

class SupabaseRitualsRepo implements RitualsRepo {
  SupabaseClient get _c => Supa.client;

  @override
  Future<List<Ritual>> list(String spaceId) async {
    try {
      final rows = await _c
          .from('rituals')
          .select()
          .eq('space_id', spaceId)
          .order('sort');
      return [
        for (final r in rows)
          Ritual.fromJson(Map<String, dynamic>.from(r as Map))
      ];
    } catch (e) {
      throw StateError(friendlySpaceError(e));
    }
  }

  @override
  Stream<List<Ritual>> watch(String spaceId) {
    return _c
        .from('rituals')
        .stream(primaryKey: ['id'])
        .eq('space_id', spaceId)
        .order('sort')
        .map((rows) => [
              for (final r in rows)
                Ritual.fromJson(Map<String, dynamic>.from(r as Map))
            ])
        .handleError((Object e) {
      throw StateError(friendlySpaceError(e));
    });
  }

  @override
  Future<Ritual> create(
      {required String spaceId,
      required String title,
      required int colorIdx}) async {
    try {
      final existing = await list(spaceId);
      final row = await _c
          .from('rituals')
          .insert({
            'space_id': spaceId,
            'title': title,
            'color_idx': colorIdx,
            'sort': existing.length,
          })
          .select()
          .single();
      return Ritual.fromJson(Map<String, dynamic>.from(row as Map));
    } catch (e) {
      throw StateError(friendlySpaceError(e));
    }
  }

  @override
  Future<void> toggle(String id, bool done) async {
    try {
      await _c.from('rituals').update(
          {'done': done, 'updated_at': DateTime.now().toIso8601String()}).eq(
          'id', id);
    } catch (e) {
      throw StateError(friendlySpaceError(e));
    }
  }

  @override
  Future<void> remove(String id) async {
    try {
      await _c.from('rituals').delete().eq('id', id);
    } catch (e) {
      throw StateError(friendlySpaceError(e));
    }
  }
}

class MemoryRitualsRepo implements RitualsRepo {
  final Map<String, List<Ritual>> _items = {};
  final _ctrl = StreamController<String>.broadcast();
  int _seq = 0;

  void seed(String spaceId, List<Ritual> rituals) {
    _items[spaceId] = List.of(rituals);
    _ctrl.add(spaceId);
  }

  List<Ritual> _sorted(String spaceId) {
    final l = List<Ritual>.of(_items[spaceId] ?? []);
    l.sort((a, b) => a.sort.compareTo(b.sort));
    return l;
  }

  @override
  Future<List<Ritual>> list(String spaceId) async => _sorted(spaceId);

  @override
  Stream<List<Ritual>> watch(String spaceId) async* {
    yield _sorted(spaceId);
    await for (final sid in _ctrl.stream) {
      if (sid == spaceId) yield _sorted(spaceId);
    }
  }

  @override
  Future<Ritual> create(
      {required String spaceId,
      required String title,
      required int colorIdx}) async {
    final l = (_items[spaceId] ??= []);
    final r = Ritual(
      id: 'm${_seq++}',
      spaceId: spaceId,
      title: title,
      colorIdx: colorIdx,
      done: false,
      sort: l.length,
      updatedAt: DateTime.now(),
    );
    l.add(r);
    _ctrl.add(spaceId);
    return r;
  }

  @override
  Future<void> toggle(String id, bool done) async {
    for (final e in _items.entries) {
      final i = e.value.indexWhere((r) => r.id == id);
      if (i >= 0) {
        final o = e.value[i];
        e.value[i] = Ritual(
            id: o.id,
            spaceId: o.spaceId,
            title: o.title,
            colorIdx: o.colorIdx,
            done: done,
            sort: o.sort,
            updatedAt: DateTime.now());
        _ctrl.add(e.key);
        return;
      }
    }
  }

  @override
  Future<void> remove(String id) async {
    for (final e in _items.entries) {
      if (e.value.any((r) => r.id == id)) {
        e.value.removeWhere((r) => r.id == id);
        _ctrl.add(e.key);
        return;
      }
    }
  }
}

// ---------------- piles (rows in M4, photos in M5) ----------------

class SupabasePilesRepo implements PilesRepo {
  SupabaseClient get _c => Supa.client;

  @override
  Future<List<Pile>> list(String spaceId) async {
    try {
      final rows = await _c
          .from('piles')
          .select()
          .eq('space_id', spaceId)
          .order('created_at', ascending: false);
      return [
        for (final r in rows)
          Pile.fromJson(Map<String, dynamic>.from(r as Map))
      ];
    } catch (e) {
      throw StateError(friendlySpaceError(e));
    }
  }

  @override
  Stream<List<Pile>> watch(String spaceId) {
    return _c
        .from('piles')
        .stream(primaryKey: ['id'])
        .eq('space_id', spaceId)
        .order('created_at', ascending: false)
        .map((rows) => [
              for (final r in rows)
                Pile.fromJson(Map<String, dynamic>.from(r as Map))
            ])
        .handleError((Object e) {
      throw StateError(friendlySpaceError(e));
    });
  }

  @override
  Future<Pile> create(
      {required String spaceId,
      required String title,
      required String location}) async {
    try {
      final uid = _c.auth.currentUser?.id;
      if (uid == null) throw StateError('Log in first.');
      final row = await _c
          .from('piles')
          .insert({
            'space_id': spaceId,
            'title': title,
            'location': location,
            'created_by': uid,
          })
          .select()
          .single();
      return Pile.fromJson(Map<String, dynamic>.from(row as Map));
    } catch (e) {
      throw StateError(friendlySpaceError(e));
    }
  }

  @override
  Future<List<PilePhoto>> photos(String pileId) async {
    try {
      final rows = await _c
          .from('pile_photos')
          .select()
          .eq('pile_id', pileId)
          .order('created_at');
      return [
        for (final r in rows)
          PilePhoto.fromJson(Map<String, dynamic>.from(r as Map))
      ];
    } catch (e) {
      throw StateError(friendlySpaceError(e));
    }
  }

  @override
  Future<PilePhoto> addPhoto(
      {required String pileId, required String r2Key}) async {
    try {
      final uid = _c.auth.currentUser?.id;
      if (uid == null) throw StateError('Log in first.');
      final row = await _c
          .from('pile_photos')
          .insert({
            'pile_id': pileId,
            'r2_key': r2Key,
            'created_by': uid,
          })
          .select()
          .single();
      return PilePhoto.fromJson(Map<String, dynamic>.from(row as Map));
    } catch (e) {
      throw StateError(friendlySpaceError(e));
    }
  }

  @override
  Future<void> removePhoto(String id) async {
    try {
      await _c.from('pile_photos').delete().eq('id', id);
    } catch (e) {
      throw StateError(friendlySpaceError(e));
    }
  }

  @override
  Future<void> removePile(String id) async {
    try {
      await _c.from('piles').delete().eq('id', id);
    } catch (e) {
      throw StateError(friendlySpaceError(e));
    }
  }
}

class MemoryPilesRepo implements PilesRepo {
  final Map<String, List<Pile>> _items = {};
  final Map<String, List<PilePhoto>> _photos = {};
  final _ctrl = StreamController<String>.broadcast();
  int _seq = 0;

  void seed(String spaceId, List<Pile> piles) {
    _items[spaceId] = List.of(piles);
    _ctrl.add(spaceId);
  }

  @override
  Future<List<Pile>> list(String spaceId) async =>
      List.of(_items[spaceId] ?? []);

  @override
  Stream<List<Pile>> watch(String spaceId) async* {
    yield List.of(_items[spaceId] ?? []);
    await for (final sid in _ctrl.stream) {
      if (sid == spaceId) yield List.of(_items[spaceId] ?? []);
    }
  }

  @override
  Future<Pile> create(
      {required String spaceId,
      required String title,
      required String location}) async {
    final p = Pile(
      id: 'm${_seq++}',
      spaceId: spaceId,
      title: title,
      location: location,
      createdBy: 'demo-user',
      createdAt: DateTime.now(),
    );
    (_items[spaceId] ??= []).insert(0, p);
    _ctrl.add(spaceId);
    return p;
  }

  @override
  Future<List<PilePhoto>> photos(String pileId) async =>
      List.of(_photos[pileId] ?? []);

  @override
  Future<PilePhoto> addPhoto(
      {required String pileId, required String r2Key}) async {
    final ph = PilePhoto(
      id: 'm${_seq++}',
      pileId: pileId,
      r2Key: r2Key,
      createdBy: 'demo-user',
      createdAt: DateTime.now(),
    );
    (_photos[pileId] ??= []).add(ph);
    return ph;
  }

  @override
  Future<void> removePhoto(String id) async {
    for (final l in _photos.values) {
      l.removeWhere((p) => p.id == id);
    }
  }

  @override
  Future<void> removePile(String id) async {
    for (final e in _items.entries) {
      if (e.value.any((p) => p.id == id)) {
        e.value.removeWhere((p) => p.id == id);
        _ctrl.add(e.key);
        return;
      }
    }
  }
}

// ---------------- resolvers ----------------

NotesRepo resolveNotesRepo() =>
    Supa.ready ? SupabaseNotesRepo() : MemoryNotesRepo();
DatesRepo resolveDatesRepo() =>
    Supa.ready ? SupabaseDatesRepo() : MemoryDatesRepo();
RitualsRepo resolveRitualsRepo() =>
    Supa.ready ? SupabaseRitualsRepo() : MemoryRitualsRepo();
PilesRepo resolvePilesRepo() =>
    Supa.ready ? SupabasePilesRepo() : MemoryPilesRepo();
