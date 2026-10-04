import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ourspace/data/backend.dart';
import 'package:ourspace/data/backend_errors.dart';

void main() {
  test('userMessage unwraps friendly StateErrors', () {
    expect(userMessage(StateError('hello there')), 'hello there');
    expect(userMessage('plain boom'), 'plain boom');
  });

  test('commonBackendMessage maps transport failures', () {
    expect(commonBackendMessage(const SocketException('x')),
        'No connection. Check internet and retry.');
    expect(commonBackendMessage(TimeoutException('t')),
        'No connection. Check internet and retry.');
    expect(commonBackendMessage('weird backend'), isNull);
  });

  test('resolveBackend shares one demo instance', () {
    resetBackendForTest();
    final a = resolveBackend();
    final b = resolveBackend();
    expect(a.isCloud, isFalse);
    expect(identical(a, b), isTrue);
    expect(identical(resolveAuthRepo(), resolveAuthRepo()), isTrue);
    expect(a.photoUploadsReady, isTrue);
    resetBackendForTest();
  });

  test('cloud backend without R2 fails photo uploads loudly', () {
    // No dotenv in tests -> R2Client.instance is null.
    final backend = SupabaseBackend();
    expect(backend.photoUploadsReady, isFalse);
    final file = XFile.fromData(Uint8List.fromList([]), name: 'x.jpg');
    expect(
      () => backend.photos
          .upload(spaceId: 's', pileId: 'p', file: file),
      throwsA(isA<StateError>().having(
          (e) => e.message, 'message', kPhotoStorageMissing)),
    );
  });
}
