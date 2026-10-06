// Space + invite pairing. UI takes a SpaceRepo so tests inject fakes.
// Server rules (see supabase/schema.sql): max 2 members per space,
// invite expiry 24h, single use — enforced atomically in join_with_code.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'backend_errors.dart';
import 'models/space.dart';
import 'repos.dart';
import 'supabase_helpers.dart';
import 'supa.dart';

class SupabaseSpaceRepo implements SpaceRepo {
  SupabaseClient get _c => Supa.client;
  String? get _uid => _c.auth.currentUser?.id;

  @override
  Future<Space?> mySpace() {
    final uid = _uid;
    if (uid == null) return Future.value();
    return guard(() async {
      final mem = await _c
          .from('space_members')
          .select('space_id')
          .eq('user_id', uid)
          .limit(1);
      if (mem.isEmpty) return null;
      final sid = (mem.first as Map)['space_id'] as String;
      final sp =
          await _c.from('spaces').select().eq('id', sid).limit(1);
      if (sp.isEmpty) return null;
      return Space.fromJson(Map<String, dynamic>.from(sp.first as Map));
    });
  }

  @override
  Future<Space> createSpace(String name) => guard(() async {
        final uid = _uid;
        if (uid == null) throw StateError('Log in first.');
        final row = await _c
            .from('spaces')
            .insert({'name': name, 'created_by': uid}).select()
            .single();
        final space =
            Space.fromJson(Map<String, dynamic>.from(row as Map));
        await _c.from('space_members')
            .insert({'space_id': space.id, 'user_id': uid});
        return space;
      });

  @override
  Future<InviteCode> createInvite(String spaceId) => guard(() async {
        final row =
            await _c.rpc('create_invite', params: {'sid': spaceId});
        return parseInviteCodeResponse(row);
      });

  @override
  Future<Space> joinWithCode(String code) => guard(() async {
        final sid = parseRpcUuid(await _c
            .rpc('join_with_code', params: {'p_code': code.trim()}));
        final row = await _c
            .from('spaces')
            .select()
            .eq('id', sid)
            .single();
        return Space.fromJson(Map<String, dynamic>.from(row as Map));
      });

  @override
  Future<void> leave(String spaceId) => guard(() async {
        final uid = _uid;
        if (uid == null) return;
        await _c
            .from('space_members')
            .delete()
            .eq('space_id', spaceId)
            .eq('user_id', uid);
        final rest = await _c
            .from('space_members')
            .select('user_id')
            .eq('space_id', spaceId)
            .limit(1);
        if (rest.isEmpty) {
          await _c.from('spaces').delete().eq('id', spaceId);
        }
      });

  @override
  Future<void> updateAnniversary(String spaceId, DateTime date) =>
      guard(() async {
        final day =
            DateTime(date.year, date.month, date.day).toIso8601String().substring(0, 10);
        await _c.from('spaces').update({'anniversary_date': day}).eq('id', spaceId);
      });

  @override
  Stream<Space?> watchMySpace() =>
      _c.auth.onAuthStateChange.asyncMap((_) => mySpace());

  String _displayName({String? hint}) {
    final meta = _c.auth.currentUser?.userMetadata?['username'] as String?;
    final name = (hint ?? meta ?? '').trim();
    if (name.isNotEmpty) return name;
    final email = _c.auth.currentUser?.email ?? '';
    final prefix = email.split('@').first.trim();
    return prefix.isEmpty ? 'you' : prefix;
  }

  @override
  Future<void> ensureProfile({String? username}) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _c.from('profiles').upsert({
        'id': uid,
        'username': _displayName(hint: username),
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {
      // Profiles table missing (old backend) — avatars fall back to
      // auth metadata. Never block space loading.
    }
  }

  @override
  Future<List<MemberProfile>> membersWithProfiles(String spaceId) async {
    try {
      final memRows = await _c
          .from('space_members')
          .select('user_id')
          .eq('space_id', spaceId);
      final ids = [
        for (final r in memRows) (r as Map)['user_id'] as String
      ];
      if (ids.isEmpty) return [];
      final profRows =
          await _c.from('profiles').select('id, username').inFilter('id', ids);
      final byId = {
        for (final r in profRows)
          ((r as Map)['id'] as String):
              (((r as Map)['username'] ?? '') as String)
      };
      final me = _uid;
      final out = [
        for (final id in ids)
          MemberProfile(
            userId: id,
            username: (byId[id] ?? '').trim().isEmpty
                ? (id == me ? _displayName() : 'partner')
                : byId[id]!.trim(),
          ),
      ];
      out.sort((a, b) {
        if (a.userId == me) return -1;
        if (b.userId == me) return 1;
        return a.username.compareTo(b.username);
      });
      return out;
    } catch (_) {
      final me = _uid;
      if (me == null) return [];
      return [MemberProfile(userId: me, username: _displayName())];
    }
  }
}

/// Local demo pairing: no backend, so no valid codes.
/// Valid invite codes only come from Supabase (see SupabaseSpaceRepo).
/// Demo keeps spaces/notes working solo; pairing shows a retry card.
class DemoSpaceRepo implements SpaceRepo {
  Space? _space;
  final _ctrl = StreamController<Space?>.broadcast();
  final Map<String, String> _usernames = {kDemoUid: 'you'};
  List<MemberProfile>? _seededMembers;

  @override
  Future<Space?> mySpace() async => _space;

  @override
  Future<Space> createSpace(String name) async {
    _space = Space(
      id: 'demo-space',
      name: name.isEmpty ? 'Our space' : name,
      createdBy: kDemoUid,
      createdAt: DateTime.now(),
    );
    _ctrl.add(_space);
    return _space!;
  }

  @override
  Future<InviteCode> createInvite(String spaceId) async {
    throw StateError('Solo demo — pair codes come from the backend.');
  }

  @override
  Future<Space> joinWithCode(String code) async {
    throw StateError('code not found');
  }

  @override
  Future<void> leave(String spaceId) async {
    if (_space?.id == spaceId) {
      _space = null;
      _ctrl.add(null);
    }
  }

  @override
  Future<void> updateAnniversary(String spaceId, DateTime date) async {
    final cur = _space;
    if (cur == null || cur.id != spaceId) {
      throw StateError('Pair first — then set your anniversary');
    }
    final day = DateTime(date.year, date.month, date.day);
    _space = Space(
      id: cur.id,
      name: cur.name,
      createdBy: cur.createdBy,
      createdAt: cur.createdAt,
      anniversaryDate: day,
    );
    _ctrl.add(_space);
  }

  @override
  Stream<Space?> watchMySpace() => _ctrl.stream;

  /// Test seam: force a paired member list in demo mode.
  void seedMembers(List<MemberProfile> members) {
    _seededMembers = List.of(members);
    for (final m in members) {
      _usernames[m.userId] = m.username;
    }
  }

  @override
  Future<void> ensureProfile({String? username}) async {
    final name = (username ?? '').trim();
    if (name.isNotEmpty) _usernames[kDemoUid] = name;
    _seededMembers = null;
  }

  @override
  Future<List<MemberProfile>> membersWithProfiles(String spaceId) async {
    if (_space == null || _space!.id != spaceId) return [];
    if (_seededMembers != null) return List.of(_seededMembers!);
    return [
      MemberProfile(
        userId: kDemoUid,
        username: _usernames[kDemoUid] ?? 'you',
      ),
    ];
  }
}

/// One `invite_codes` row out of a PostgREST RPC response.
/// Single-composite RPCs normally decode to a Map, but a one-element
/// List is accepted too so a shape change fails loudly in tests,
/// not silently in production. Anything else throws StateError.
InviteCode parseInviteCodeResponse(dynamic row) {
  final first = row is List && row.isNotEmpty ? row.first : row;
  if (first is! Map) {
    throw StateError('Something hiccuped. Try again.');
  }
  return InviteCode.fromJson(Map<String, dynamic>.from(first));
}

/// UUID scalar out of a PostgREST RPC response (normally a String,
/// sometimes wrapped in a one-element List).
String parseRpcUuid(dynamic value) {
  final v = value is List && value.isNotEmpty ? value.first : value;
  if (v is String && v.isNotEmpty) return v;
  throw StateError('Something hiccuped. Try again.');
}

String friendlySpaceError(Object e) {
  final common = commonBackendMessage(e);
  if (common != null) return common;
  final m = e.toString().toLowerCase();
  if (m.contains('code not found')) {
    return "Hmm, that code didn't match. Check with your person.";
  }
  // Stale session mid-call (e.g. 'JWT expired'): Supabase auto-refreshes,
  // but a 401 can still slip through — actionable instead of generic.
  // Checked before 'expired' so 'JWT expired' doesn't read as a code issue.
  if (m.contains('jwt') ||
      m.contains('invalid token') ||
      m.contains('unauthorized') ||
      m.contains(' 401')) {
    return 'Session expired. Log in again.';
  }
  if (m.contains('expired')) {
    return 'That code expired — ask your person for a fresh one.';
  }
  if (m.contains('used')) {
    return 'That code was already used — ask for a fresh one.';
  }
  if (m.contains('space is full') || m.contains('full')) {
    return 'That space already has two — solo for now?';
  }
  // Membership race: our row already exists server-side, so the next
  // Check code takes the already-member path and succeeds.
  if (m.contains('duplicate key')) {
    return 'Almost there — tap Check code once more.';
  }
  if (m.contains('not a member')) return 'Join a space first.';
  if (m.contains('log in first')) return 'Log in first.';
  if (m.contains('does not exist') ||
      m.contains('schema cache') ||
      m.contains('relation') ||
      m.contains('function create_invite') ||
      m.contains('function join_with_code')) {
    debugPrint('[space] backend missing: $e');
    return 'Something hiccuped. Try again.';
  }
  if (m.contains('permission denied') || m.contains('row-level security')) {
    debugPrint('[space] rls blocked: $e');
    return 'Something hiccuped. Try again.';
  }
  if (e is StateError && e.message.isNotEmpty) return e.message;
  return 'Something hiccuped. Try again.';
}
