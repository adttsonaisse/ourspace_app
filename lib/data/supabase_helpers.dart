// Supabase call helpers: one error-mapping wrapper and one row parser
// shared by every Supabase*Repo, instead of the same try/catch +
// fromJson loop copied per method.

import 'space_repo.dart' show friendlySpaceError;

/// Run [fn], mapping any failure to a user-facing StateError via [map].
Future<T> guard<T>(Future<T> Function() fn,
    [String Function(Object) map = friendlySpaceError]) async {
  try {
    return await fn();
  } catch (e) {
    throw StateError(map(e));
  }
}

/// Parse PostgREST rows into models. Throws StateError on shape mismatch
/// (surfaced through [guard] at call sites).
List<T> parseRows<T>(
    List rows, T Function(Map<String, dynamic>) fromJson) {
  return [
    for (final r in rows)
      fromJson(Map<String, dynamic>.from(r as Map)),
  ];
}

/// Map a realtime stream into models, mapping stream errors the same way.
Stream<List<T>> watchRows<T>(
    Stream<List> source, T Function(Map<String, dynamic>) fromJson) {
  return source.map((rows) => parseRows(rows, fromJson)).handleError(
    (Object e) {
      throw StateError(friendlySpaceError(e));
    },
  );
}
