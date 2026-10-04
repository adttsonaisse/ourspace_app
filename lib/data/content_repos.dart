// Content repos: Supabase (cloud) + Memory (solo/demo/tests).
// Tabs depend on the abstracts in repos.dart and never touch Supabase.

import 'package:supabase_flutter/supabase_flutter.dart';

import 'memory_store.dart';
import 'models/content.dart';
import 'repos.dart';
import 'supabase_helpers.dart';
import 'supa.dart';

// ---------------- notes ----------------

class SupabaseNotesRepo implements NotesRepo {
  SupabaseClient get _c => Supa.client;

  @override
  Future<List<Note>> list(String spaceId) => guard(() async {
        final rows = await _c
            .from('notes')
            .select()
            .eq('space_id', spaceId)
            .order('created_at', ascending: false);
        return parseRows(rows, Note.fromJson);
      });

  @override
  Stream<List<Note>> watch(String spaceId) {
    return watchRows(
      _c
          .from('notes')
          .stream(primaryKey: ['id'])
          .eq('space_id', spaceId)
          .order('created_at', ascending: false),
      Note.fromJson,
    );
  }

  @override
  Future<Note> create(
      {required String spaceId,
      required String body,
      required int colorIdx}) =>
      guard(() async {
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
      });

  @override
  Future<void> togglePin(String id, bool pinned) => guard(() async {
        await _c.from('notes').update({'pinned': pinned}).eq('id', id);
      });

  @override
  Future<void> remove(String id) => guard(() async {
        await _c.from('notes').delete().eq('id', id);
      });
}

class MemoryNotesRepo implements NotesRepo {
  final _table = MemoryTable<Note>(
    idOf: (n) => n.id,
    spaceOf: (n) => n.spaceId,
    sortBy: (a, b) => b.createdAt.compareTo(a.createdAt),
  );
  int _seq = 0;

  /// Test/seed helper — UI never calls this.
  void seed(String spaceId, List<Note> notes) =>
      _table.seed(spaceId, notes);

  @override
  Future<List<Note>> list(String spaceId) => _table.list(spaceId);

  @override
  Stream<List<Note>> watch(String spaceId) => _table.watch(spaceId);

  @override
  Future<Note> create(
      {required String spaceId,
      required String body,
      required int colorIdx}) async {
    final n = Note(
      id: 'm${_seq++}',
      spaceId: spaceId,
      authorId: kDemoUid,
      body: body,
      colorIdx: colorIdx,
      pinned: false,
      createdAt: DateTime.now(),
    );
    _table.put(n);
    return n;
  }

  @override
  Future<void> togglePin(String id, bool pinned) async {
    _table.updateFirst(
      (n) => n.id == id,
      (n) => Note(
          id: n.id,
          spaceId: n.spaceId,
          authorId: n.authorId,
          body: n.body,
          colorIdx: n.colorIdx,
          pinned: pinned,
          createdAt: n.createdAt),
    );
  }

  @override
  Future<void> remove(String id) async => _table.removeById(id);
}

// ---------------- dates ----------------

class SupabaseDatesRepo implements DatesRepo {
  SupabaseClient get _c => Supa.client;

  @override
  Future<List<DatePlan>> list(String spaceId) => guard(() async {
        final rows = await _c
            .from('date_plans')
            .select()
            .eq('space_id', spaceId)
            .order('day');
        return parseRows(rows, DatePlan.fromJson);
      });

  @override
  Stream<List<DatePlan>> watch(String spaceId) {
    return watchRows(
      _c
          .from('date_plans')
          .stream(primaryKey: ['id'])
          .eq('space_id', spaceId)
          .order('day'),
      DatePlan.fromJson,
    );
  }

  @override
  Future<DatePlan> create(
      {required String spaceId,
      required String title,
      required String note,
      required String place,
      required DateTime day}) =>
      guard(() async {
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
      });

  @override
  Future<void> remove(String id) => guard(() async {
        await _c.from('date_plans').delete().eq('id', id);
      });
}

class MemoryDatesRepo implements DatesRepo {
  final _table = MemoryTable<DatePlan>(
    idOf: (p) => p.id,
    spaceOf: (p) => p.spaceId,
    sortBy: (a, b) => a.day.compareTo(b.day),
  );
  int _seq = 0;

  void seed(String spaceId, List<DatePlan> plans) =>
      _table.seed(spaceId, plans);

  @override
  Future<List<DatePlan>> list(String spaceId) => _table.list(spaceId);

  @override
  Stream<List<DatePlan>> watch(String spaceId) => _table.watch(spaceId);

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
      createdBy: kDemoUid,
      createdAt: DateTime.now(),
    );
    _table.put(p);
    return p;
  }

  @override
  Future<void> remove(String id) async => _table.removeById(id);
}

// ---------------- rituals ----------------

class SupabaseRitualsRepo implements RitualsRepo {
  SupabaseClient get _c => Supa.client;

  @override
  Future<List<Ritual>> list(String spaceId) => guard(() async {
        final rows = await _c
            .from('rituals')
            .select()
            .eq('space_id', spaceId)
            .order('sort');
        return parseRows(rows, Ritual.fromJson);
      });

  @override
  Stream<List<Ritual>> watch(String spaceId) {
    return watchRows(
      _c
          .from('rituals')
          .stream(primaryKey: ['id'])
          .eq('space_id', spaceId)
          .order('sort'),
      Ritual.fromJson,
    );
  }

  @override
  Future<Ritual> create(
      {required String spaceId,
      required String title,
      required int colorIdx}) =>
      guard(() async {
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
      });

  @override
  Future<void> toggle(String id, bool done) => guard(() async {
        await _c.from('rituals').update(
            {'done': done, 'updated_at': DateTime.now().toIso8601String()}).eq(
            'id', id);
      });

  @override
  Future<void> remove(String id) => guard(() async {
        await _c.from('rituals').delete().eq('id', id);
      });
}

class MemoryRitualsRepo implements RitualsRepo {
  final _table = MemoryTable<Ritual>(
    idOf: (r) => r.id,
    spaceOf: (r) => r.spaceId,
    sortBy: (a, b) => a.sort.compareTo(b.sort),
  );
  int _seq = 0;

  void seed(String spaceId, List<Ritual> rituals) =>
      _table.seed(spaceId, rituals);

  @override
  Future<List<Ritual>> list(String spaceId) => _table.list(spaceId);

  @override
  Stream<List<Ritual>> watch(String spaceId) => _table.watch(spaceId);

  @override
  Future<Ritual> create(
      {required String spaceId,
      required String title,
      required int colorIdx}) async {
    final l = await _table.list(spaceId);
    final r = Ritual(
      id: 'm${_seq++}',
      spaceId: spaceId,
      title: title,
      colorIdx: colorIdx,
      done: false,
      sort: l.length,
      updatedAt: DateTime.now(),
    );
    _table.put(r);
    return r;
  }

  @override
  Future<void> toggle(String id, bool done) async {
    _table.updateFirst(
      (r) => r.id == id,
      (o) => Ritual(
          id: o.id,
          spaceId: o.spaceId,
          title: o.title,
          colorIdx: o.colorIdx,
          done: done,
          sort: o.sort,
          updatedAt: DateTime.now()),
    );
  }

  @override
  Future<void> remove(String id) async => _table.removeById(id);
}

// ---------------- piles (rows in M4, photos in M5) ----------------

class SupabasePilesRepo implements PilesRepo {
  SupabaseClient get _c => Supa.client;

  @override
  Future<List<Pile>> list(String spaceId) => guard(() async {
        final rows = await _c
            .from('piles')
            .select()
            .eq('space_id', spaceId)
            .order('created_at', ascending: false);
        return parseRows(rows, Pile.fromJson);
      });

  @override
  Stream<List<Pile>> watch(String spaceId) {
    return watchRows(
      _c
          .from('piles')
          .stream(primaryKey: ['id'])
          .eq('space_id', spaceId)
          .order('created_at', ascending: false),
      Pile.fromJson,
    );
  }

  @override
  Future<Pile> create(
      {required String spaceId,
      required String title,
      required String location}) =>
      guard(() async {
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
      });

  @override
  Future<List<PilePhoto>> photos(String pileId) => guard(() async {
        final rows = await _c
            .from('pile_photos')
            .select()
            .eq('pile_id', pileId)
            .order('created_at');
        return parseRows(rows, PilePhoto.fromJson);
      });

  @override
  Future<PilePhoto> addPhoto(
          {required String pileId, required String r2Key}) =>
      guard(() async {
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
      });

  @override
  Future<void> removePhoto(String id) => guard(() async {
        await _c.from('pile_photos').delete().eq('id', id);
      });

  @override
  Future<void> removePile(String id) => guard(() async {
        await _c.from('piles').delete().eq('id', id);
      });
}

class MemoryPilesRepo implements PilesRepo {
  final _table = MemoryTable<Pile>(
    idOf: (p) => p.id,
    spaceOf: (p) => p.spaceId,
  );
  final Map<String, List<PilePhoto>> _photos = {};
  int _seq = 0;

  void seed(String spaceId, List<Pile> piles) =>
      _table.seed(spaceId, piles);

  @override
  Future<List<Pile>> list(String spaceId) async {
    // Newest first: insertion order is oldest-first (see create).
    return _table.sorted(spaceId).reversed.toList();
  }

  @override
  Stream<List<Pile>> watch(String spaceId) =>
      _table.watch(spaceId).map((l) => l.reversed.toList());

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
      createdBy: kDemoUid,
      createdAt: DateTime.now(),
    );
    _table.put(p);
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
      createdBy: kDemoUid,
      createdAt: DateTime.now(),
    );
    (_photos[pileId] ??= []).add(ph);
    return ph;
  }

  @override
  Future<void> removePhoto(String id) async {
    String? pileId;
    for (final e in _photos.entries) {
      if (e.value.any((p) => p.id == id)) {
        e.value.removeWhere((p) => p.id == id);
        pileId = e.key;
        break;
      }
    }
    if (pileId == null) return;
    final spaceId = _table.spaceOfId(pileId);
    if (spaceId != null) _table.touch(spaceId);
  }

  @override
  Future<void> removePile(String id) async => _table.removeById(id);
}

// ---------------- resolvers ----------------
// Moved to backend.dart: resolveAuthRepo/resolveSpaceRepo/
// resolveNotesRepo/resolveDatesRepo/resolveRitualsRepo/resolvePilesRepo
// delegate to the shared Backend singleton. Kept importable from here
// via backend.dart — do not re-add them (circular import).
