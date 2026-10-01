// Space + invite pairing. UI takes a SpaceRepo so tests inject fakes.
// Server rules (see supabase/schema.sql): max 2 members per space,
// invite expiry 24h, single use — enforced atomically in join_with_code.

import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/space.dart';
import 'repos.dart';
import 'supa.dart';

class SupabaseSpaceRepo implements SpaceRepo {
  SupabaseClient get _c => Supa.client;
  String? get _uid => _c.auth.currentUser?.id;

  @override
  Future<Space?> mySpace() async {
    final uid = _uid;
    if (uid == null) return null;
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
  }

  @override
  Future<Space> createSpace(String name) async {
    try {
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
    } catch (e) {
      throw StateError(friendlySpaceError(e));
    }
  }

  @override
  Future<InviteCode> createInvite(String spaceId) async {
    try {
      final row =
          await _c.rpc('create_invite', params: {'sid': spaceId});
      return InviteCode.fromJson(
          Map<String, dynamic>.from(row as Map));
    } catch (e) {
      throw StateError(friendlySpaceError(e));
    }
  }

  @override
  Future<Space> joinWithCode(String code) async {
    try {
      final sid = await _c
          .rpc('join_with_code', params: {'p_code': code.trim()});
      final row = await _c
          .from('spaces')
          .select()
          .eq('id', sid as String)
          .single();
      return Space.fromJson(Map<String, dynamic>.from(row as Map));
    } catch (e) {
      throw StateError(friendlySpaceError(e));
    }
  }

  @override
  Future<void> leave(String spaceId) async {
    try {
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
    } catch (e) {
      throw StateError(friendlySpaceError(e));
    }
  }

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

/// Local demo pairing: deterministic MOCHI-42, no backend.
/// Keeps widget tests + fresh clones usable without .env.
class DemoSpaceRepo implements SpaceRepo {
  Space? _space;
  final _ctrl = StreamController<Space?>.broadcast();
  final Map<String, String> _usernames = {'demo-user': 'you'};
  List<MemberProfile>? _seededMembers;

  @override
  Future<Space?> mySpace() async => _space;

  @override
  Future<Space> createSpace(String name) async {
    _space = Space(
      id: 'demo-space',
      name: name.isEmpty ? 'Our space' : name,
      createdBy: 'demo-user',
      createdAt: DateTime.now(),
    );
    _ctrl.add(_space);
    return _space!;
  }

  @override
  Future<InviteCode> createInvite(String spaceId) async {
    return InviteCode(
      code: 'MOCHI-42',
      spaceId: spaceId,
      createdBy: 'demo-user',
      expiresAt: DateTime.now().add(const Duration(hours: 24)),
      usedCount: 0,
      maxUses: 1,
    );
  }

  @override
  Future<Space> joinWithCode(String code) async {
    final norm = code.trim().toUpperCase().replaceAll(' ', '');
    if (norm != 'MOCHI-42') throw StateError('code not found');
    _space ??= Space(
      id: 'demo-space',
      name: 'Our space',
      createdBy: 'demo-user',
      createdAt: DateTime.now(),
    );
    _ctrl.add(_space);
    return _space!;
  }

  @override
  Future<void> leave(String spaceId) async {
    if (_space?.id == spaceId) {
      _space = null;
      _ctrl.add(null);
    }
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
    if (name.isNotEmpty) _usernames['demo-user'] = name;
    _seededMembers = null;
  }

  @override
  Future<List<MemberProfile>> membersWithProfiles(String spaceId) async {
    if (_space == null || _space!.id != spaceId) return [];
    if (_seededMembers != null) return List.of(_seededMembers!);
    return [
      MemberProfile(
        userId: 'demo-user',
        username: _usernames['demo-user'] ?? 'you',
      ),
    ];
  }
}

SpaceRepo resolveSpaceRepo() =>
    Supa.ready ? SupabaseSpaceRepo() : DemoSpaceRepo();

String friendlySpaceError(Object e) {
  if (e is SocketException) {
    return 'No connection. Check internet and retry.';
  }
  final m = e.toString().toLowerCase();
  if (m.contains('code not found')) {
    return "Hmm, that code didn't match. Check with your person.";
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
  if (m.contains('not a member')) return 'Join a space first.';
  if (m.contains('log in first')) return 'Log in first.';
  if (m.contains('failed host') || m.contains('network')) {
    return 'No connection. Check internet and retry.';
  }
  if (e is TimeoutException || m.contains('timeout') || m.contains('timed out')) {
    return 'Request timed out — check internet and retry.';
  }
  if (m.contains('does not exist') ||
      m.contains('schema cache') ||
      m.contains('relation') ||
      m.contains('function create_invite') ||
      m.contains('function join_with_code')) {
    return 'Backend needs setup — run supabase/schema.sql (+ m6/m7) in Supabase SQL editor, then retry.';
  }
  if (m.contains('permission denied') || m.contains('row-level security')) {
    return 'Blocked by database rules — re-run supabase/schema.sql policies in Supabase SQL editor.';
  }
  if (e is StateError && e.message.isNotEmpty) return e.message;
  return 'Something hiccuped. Try again.';
}
