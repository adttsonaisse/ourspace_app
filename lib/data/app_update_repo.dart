import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

// GitHub release checker: compares the local build version against the
// latest published tag on the release page. Silent on any failure
// (offline, rate-limit, no releases yet) so startup never blocks.

const String kGithubOwner = 'adttsonaisse';
const String kGithubRepo = 'ourspace_app';

Uri get latestReleaseUrl => Uri.https(
      'api.github.com',
      '/repos/$kGithubOwner/$kGithubRepo/releases/latest',
    );

class AppRelease {
  final String tag;
  final String name;
  final String url;
  final String notes;
  const AppRelease({
    required this.tag,
    required this.name,
    required this.url,
    required this.notes,
  });

  factory AppRelease.fromJson(Map<String, dynamic> j) {
    final tag = ((j['tag_name'] ?? '') as String).trim();
    final name = ((j['name'] ?? tag) as String).trim();
    final url = ((j['html_url'] ?? '') as String).trim();
    final notes = ((j['body'] ?? '') as String).trim();
    return AppRelease(tag: tag, name: name, url: url, notes: notes);
  }
}

/// Strip leading `v`, drop `+build`, keep `major.minor.patch`.
List<int> normalizeVersion(String v) {
  var s = v.trim().toLowerCase();
  if (s.startsWith('v')) s = s.substring(1);
  s = s.split('+').first;
  s = s.split('-').first;
  final parts = s.split('.');
  final out = <int>[];
  for (var i = 0; i < 3; i++) {
    if (i < parts.length) {
      out.add(int.tryParse(parts[i].replaceAll(RegExp(r'[^0-9]'), '')) ?? 0);
    } else {
      out.add(0);
    }
  }
  return out;
}

/// True when [remoteTag] is a newer stable version than [localVersion].
bool isNewerVersion(String localVersion, String remoteTag) {
  final l = normalizeVersion(localVersion);
  final r = normalizeVersion(remoteTag);
  for (var i = 0; i < 3; i++) {
    if (r[i] > l[i]) return true;
    if (r[i] < l[i]) return false;
  }
  return false;
}

/// Fetch latest GitHub release. Returns null on any failure.
Future<AppRelease?> fetchLatestRelease({http.Client? client}) async {
  final c = client ?? http.Client();
  final close = client == null;
  try {
    final res = await c
        .get(
          latestReleaseUrl,
          headers: {'Accept': 'application/vnd.github+json'},
        )
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) return null;
    final j = jsonDecode(res.body);
    if (j is! Map<String, dynamic>) return null;
    final rel = AppRelease.fromJson(j);
    if (rel.tag.isEmpty || rel.url.isEmpty) return null;
    return rel;
  } catch (_) {
    return null;
  } finally {
    if (close) c.close();
  }
}
