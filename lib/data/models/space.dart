// Cloud-sync models: spaces, members, invite codes.
// Manual fromJson/toJson (no codegen) to keep M1 diff small.

class Space {
  final String id;
  final String name;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? anniversaryDate;
  const Space(
      {required this.id,
      required this.name,
      required this.createdBy,
      required this.createdAt,
      this.anniversaryDate});

  factory Space.fromJson(Map<String, dynamic> j) => Space(
        id: j['id'] as String,
        name: j['name'] as String,
        createdBy: j['created_by'] as String,
        createdAt: DateTime.parse(j['created_at'] as String),
        anniversaryDate: j['anniversary_date'] == null
            ? null
            : DateTime.parse(j['anniversary_date'] as String),
      );

  /// Day counter source: editable anniversary when set, else creation day.
  DateTime get effectiveAnniversary => anniversaryDate ?? createdAt;

  Map<String, dynamic> toInsert(String name, String uid) => {
        'name': name,
        'created_by': uid,
      };
}

class SpaceMember {
  final String spaceId;
  final String userId;
  final DateTime joinedAt;
  const SpaceMember(
      {required this.spaceId, required this.userId, required this.joinedAt});

  factory SpaceMember.fromJson(Map<String, dynamic> j) => SpaceMember(
        spaceId: j['space_id'] as String,
        userId: j['user_id'] as String,
        joinedAt: DateTime.parse(j['joined_at'] as String),
      );
}

class InviteCode {
  final String code;
  final String spaceId;
  final String createdBy;
  final DateTime expiresAt;
  final int usedCount;
  final int maxUses;
  const InviteCode(
      {required this.code,
      required this.spaceId,
      required this.createdBy,
      required this.expiresAt,
      required this.usedCount,
      required this.maxUses});

  factory InviteCode.fromJson(Map<String, dynamic> j) => InviteCode(
        code: j['code'] as String,
        spaceId: j['space_id'] as String,
        createdBy: j['created_by'] as String,
        expiresAt: DateTime.parse(j['expires_at'] as String),
        usedCount: (j['used_count'] as num).toInt(),
        maxUses: (j['max_uses'] as num).toInt(),
      );

  bool get expired => DateTime.now().isAfter(expiresAt);
  bool get exhausted => usedCount >= maxUses;
}

class MemberProfile {
  final String userId;
  final String username;
  const MemberProfile({required this.userId, required this.username});

  factory MemberProfile.fromJson(Map<String, dynamic> j) => MemberProfile(
        userId: (j['id'] ?? j['user_id']) as String,
        username: ((j['username'] ?? '') as String).trim(),
      );

  String get initial => avatarInitial(username);
}

/// First letter, uppercased. Empty/blank -> fallback.
String avatarInitial(String? name, {String fallback = '?'}) {
  final t = (name ?? '').trim();
  if (t.isEmpty) return fallback;
  return t[0].toUpperCase();
}
