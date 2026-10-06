import 'package:flutter_test/flutter_test.dart';
import 'package:ourspace/data/space_repo.dart';

Map<String, dynamic> _inviteRow() => {
      'code': '482916',
      'space_id': '11111111-1111-1111-1111-111111111111',
      'created_by': '22222222-2222-2222-2222-222222222222',
      'expires_at': '2026-10-05T00:00:00.000Z',
      'used_count': 0,
      'max_uses': 1,
    };

void main() {
  test('parseInviteCodeResponse accepts a Map row', () {
    final inv = parseInviteCodeResponse(_inviteRow());
    expect(inv.code, '482916');
    expect(inv.spaceId, '11111111-1111-1111-1111-111111111111');
    expect(inv.usedCount, 0);
    expect(inv.maxUses, 1);
  });

  test('parseInviteCodeResponse accepts a one-element List', () {
    final inv = parseInviteCodeResponse([_inviteRow()]);
    expect(inv.code, '482916');
  });

  test('parseInviteCodeResponse throws on other shapes', () {
    expect(() => parseInviteCodeResponse('nope'), throwsStateError);
    expect(() => parseInviteCodeResponse([]), throwsStateError);
    expect(() => parseInviteCodeResponse(42), throwsStateError);
  });

  test('parseRpcUuid unwraps String and one-element List', () {
    const sid = '11111111-1111-1111-1111-111111111111';
    expect(parseRpcUuid(sid), sid);
    expect(parseRpcUuid([sid]), sid);
  });

  test('parseRpcUuid throws on other shapes', () {
    expect(() => parseRpcUuid(''), throwsStateError);
    expect(() => parseRpcUuid([]), throwsStateError);
    expect(() => parseRpcUuid(42), throwsStateError);
  });

  test('PGRST116-style shape errors stay generic for users', () {
    expect(
      friendlySpaceError(
          'JSON object requested, multiple (or no) rows returned'),
      'Something hiccuped. Try again.',
    );
  });

  test('Stale session maps to login action', () {
    expect(
      friendlySpaceError('PostgrestException(message: JWT expired)'),
      'Session expired. Log in again.',
    );
    expect(
      friendlySpaceError('401 Unauthorized'),
      'Session expired. Log in again.',
    );
  });

  test('Membership race tells the user to retry once', () {
    expect(
      friendlySpaceError(
          'duplicate key value violates unique constraint "space_members_pkey"'),
      'Almost there — tap Check code once more.',
    );
  });

  test('Backend recursion shape gets honest retry copy', () {
    expect(
      friendlySpaceError('stack depth limit exceeded (54001)'),
      'Server hiccup. Try again in a bit.',
    );
  });

  test('Known join failures keep their specific copy', () {    expect(
      friendlySpaceError('code not found'),
      "Hmm, that code didn't match. Check with your person.",
    );
    expect(
      friendlySpaceError('code expired'),
      'That code expired — ask your person for a fresh one.',
    );
    expect(
      friendlySpaceError('space is full'),
      'That space already has two — solo for now?',
    );
  });
}
