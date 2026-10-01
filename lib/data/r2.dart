// Private R2 access via S3-compatible API (minio).
// Bucket is private: reads go through cached presigned GET URLs;
// uploads/deletes are direct. Null when .env is incomplete so the
// app keeps running in demo mode.

import 'dart:typed_data';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:minio/minio.dart';

class _CachedUrl {
  final String url;
  final DateTime validUntil;
  const _CachedUrl(this.url, this.validUntil);
}

class R2Client {
  final Minio minio;
  final String bucket;
  R2Client._(this.minio, this.bucket);

  static R2Client? _instance;
  static R2Client? get instance => _instance ??= fromEnv();

  /// Test hook: drop the cached singleton (env never changes at runtime).
  static void resetForTest() => _instance = null;

  static R2Client? fromEnv() {
    try {
      final endpoint = dotenv.maybeGet('R2_ENDPOINT') ?? '';
      final access = dotenv.maybeGet('R2_ACCESS_KEY') ?? '';
      final secret = dotenv.maybeGet('R2_SECRET_KEY') ?? '';
      final bucket = dotenv.maybeGet('R2_BUCKET') ?? '';
      if (endpoint.isEmpty || access.isEmpty || secret.isEmpty) {
        return null;
      }
      final host = endpoint
          .replaceFirst('https://', '')
          .replaceFirst('http://', '')
          .split('/')
          .first;
      final minio = Minio(
        endPoint: host,
        accessKey: access,
        secretKey: secret,
        region: 'auto',
        useSSL: endpoint.startsWith('https'),
      );
      return R2Client._(minio, bucket.isEmpty ? 'ourspace-piles' : bucket);
    } catch (_) {
      return null;
    }
  }

  final _urlCache = <String, _CachedUrl>{};

  /// Short-lived read URL for a private object (default 15 min),
  /// cached until ~2 min before expiry to avoid re-signing per build.
  Future<String> presignedGet(String key,
      {int expiresSeconds = 900}) async {
    final hit = _urlCache[key];
    if (hit != null && DateTime.now().isBefore(hit.validUntil)) {
      return hit.url;
    }
    final url = await minio.presignedUrl('GET', bucket, key,
        expires: expiresSeconds);
    _urlCache[key] = _CachedUrl(
        url,
        DateTime.now()
            .add(Duration(seconds: expiresSeconds - 120)));
    return url;
  }

  Future<void> putBytes(String key, Uint8List bytes) async {
    await minio.putObject(bucket, key, Stream.value(bytes),
        size: bytes.length);
  }

  Future<void> remove(String key) =>
      minio.removeObject(bucket, key);

  String objectKey(String spaceId, String pileId, String name) =>
      '$spaceId/$pileId/$name';
}
