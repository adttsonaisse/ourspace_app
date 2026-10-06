// Cloud-sync content models: notes, piles, photos, dates.
// colorIdx maps to the local Kawaii palette order — never the DB's business.

class Note {
  final String id;
  final String spaceId;
  final String authorId;
  final String body;
  final int colorIdx;
  final bool pinned;
  final DateTime createdAt;
  const Note(
      {required this.id,
      required this.spaceId,
      required this.authorId,
      required this.body,
      required this.colorIdx,
      required this.pinned,
      required this.createdAt});

  factory Note.fromJson(Map<String, dynamic> j) => Note(
        id: j['id'] as String,
        spaceId: j['space_id'] as String,
        authorId: j['author_id'] as String,
        body: j['body'] as String,
        colorIdx: (j['color_idx'] as num).toInt(),
        pinned: j['pinned'] as bool,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

class Pile {
  final String id;
  final String spaceId;
  final String title;
  final String location;
  final String createdBy;
  final DateTime createdAt;
  const Pile(
      {required this.id,
      required this.spaceId,
      required this.title,
      required this.location,
      required this.createdBy,
      required this.createdAt});

  factory Pile.fromJson(Map<String, dynamic> j) => Pile(
        id: j['id'] as String,
        spaceId: j['space_id'] as String,
        title: j['title'] as String,
        location: (j['location'] ?? '') as String,
        createdBy: j['created_by'] as String,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

class PilePhoto {
  final String id;
  final String pileId;
  final String r2Key;
  final String createdBy;
  final DateTime createdAt;
  const PilePhoto(
      {required this.id,
      required this.pileId,
      required this.r2Key,
      required this.createdBy,
      required this.createdAt});

  factory PilePhoto.fromJson(Map<String, dynamic> j) => PilePhoto(
        id: j['id'] as String,
        pileId: j['pile_id'] as String,
        r2Key: j['r2_key'] as String,
        createdBy: j['created_by'] as String,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

class DatePlan {
  final String id;
  final String spaceId;
  final String title;
  final String note;
  final String place;
  final DateTime day;
  final String createdBy;
  final DateTime createdAt;
  const DatePlan(
      {required this.id,
      required this.spaceId,
      required this.title,
      required this.note,
      required this.place,
      required this.day,
      required this.createdBy,
      required this.createdAt});

  factory DatePlan.fromJson(Map<String, dynamic> j) => DatePlan(
        id: j['id'] as String,
        spaceId: j['space_id'] as String,
        title: j['title'] as String,
        note: (j['note'] ?? '') as String,
        place: (j['place'] ?? '') as String,
        day: DateTime.parse(j['day'] as String),
        createdBy: j['created_by'] as String,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

