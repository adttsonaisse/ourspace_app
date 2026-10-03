import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ourspace/data/app_update_repo.dart';

void main() {
  group('normalizeVersion', () {
    test('strips v prefix and build metadata', () {
      expect(normalizeVersion('v1.2.3'), [1, 2, 3]);
      expect(normalizeVersion('1.0.0+1'), [1, 0, 0]);
      expect(normalizeVersion('v2.0.1+42'), [2, 0, 1]);
    });

    test('pads missing parts', () {
      expect(normalizeVersion('1.2'), [1, 2, 0]);
      expect(normalizeVersion('v3'), [3, 0, 0]);
    });
  });

  group('isNewerVersion', () {
    test('detects patch/minor/major bumps', () {
      expect(isNewerVersion('1.0.0', 'v1.0.1'), isTrue);
      expect(isNewerVersion('1.0.0', 'v1.1.0'), isTrue);
      expect(isNewerVersion('1.0.0', 'v2.0.0'), isTrue);
    });

    test('same or older is not newer', () {
      expect(isNewerVersion('1.0.0', 'v1.0.0'), isFalse);
      expect(isNewerVersion('1.1.0', 'v1.0.9'), isFalse);
      expect(isNewerVersion('2.0.0', 'v1.9.9'), isFalse);
    });

    test('ignores build numbers', () {
      expect(isNewerVersion('1.0.0+1', 'v1.0.0'), isFalse);
    });
  });

  group('AppRelease.fromJson', () {
    test('parses tag, url and notes', () {
      final rel = AppRelease.fromJson({
        'tag_name': 'v1.1.0',
        'name': 'Cute drop',
        'html_url': 'https://github.com/o/r/releases/tag/v1.1.0',
        'body': 'fresh stickers',
      });
      expect(rel.tag, 'v1.1.0');
      expect(rel.url, contains('releases/tag'));
      expect(rel.notes, 'fresh stickers');
      expect(rel.supportsDirectInstall, isFalse);
    });

    test('picks the apk asset url', () {
      final rel = AppRelease.fromJson({
        'tag_name': 'v1.1.0',
        'html_url': 'https://github.com/o/r/releases/tag/v1.1.0',
        'assets': [
          {
            'name': 'app-release.apk',
            'browser_download_url':
                'https://github.com/o/r/releases/download/v1.1.0/app-release.apk',
          },
          {
            'name': 'notes.txt',
            'browser_download_url': 'https://example.com/notes.txt',
          },
        ],
      });
      expect(rel.apkUrl, contains('.apk'));
      expect(rel.supportsDirectInstall, isTrue);
    });
  });

  group('fetchLatestRelease', () {
    test('returns release on 200', () async {
      final client = MockClient((_) async => http.Response(
            jsonEncode({
              'tag_name': 'v1.1.0',
              'name': 'Cute drop',
              'html_url': 'https://github.com/o/r/releases/tag/v1.1.0',
              'body': 'notes',
            }),
            200,
          ));
      final rel = await fetchLatestRelease(client: client);
      expect(rel?.tag, 'v1.1.0');
    });

    test('returns null on 404 (no releases yet)', () async {
      final client = MockClient((_) async => http.Response('{}', 404));
      expect(await fetchLatestRelease(client: client), isNull);
    });

    test('returns null on malformed body', () async {
      final client = MockClient(
          (_) async => http.Response(jsonEncode({'nope': true}), 200));
      expect(await fetchLatestRelease(client: client), isNull);
    });

    test('returns null on network error', () async {
      final client = MockClient((_) async => throw Exception('offline'));
      expect(await fetchLatestRelease(client: client), isNull);
    });
  });

  group('checkForAppUpdate', () {
    MockClient releaseClient(String tag) => MockClient((_) async =>
        http.Response(
            jsonEncode({
              'tag_name': tag,
              'html_url': 'https://github.com/o/r/releases/tag/$tag',
            }),
            200));

    test('same version stays quiet (upToDate)', () async {
      final check = await checkForAppUpdate(
          localVersion: '1.1.0', client: releaseClient('v1.1.0'));
      expect(check.status, UpdateStatus.upToDate);
      expect(check.release, isNull);
    });

    test('older local build reports available', () async {
      final check = await checkForAppUpdate(
          localVersion: '1.0.0', client: releaseClient('v1.1.0'));
      expect(check.status, UpdateStatus.available);
      expect(check.release?.tag, 'v1.1.0');
    });

    test('failure maps to failed, never throws', () async {
      final client = MockClient((_) async => throw Exception('offline'));
      final check =
          await checkForAppUpdate(localVersion: '1.0.0', client: client);
      expect(check.status, UpdateStatus.failed);
      expect(check.release, isNull);
    });
  });
}
