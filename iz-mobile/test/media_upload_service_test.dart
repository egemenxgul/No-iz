import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:cryptography/cryptography.dart';
import 'package:iz_mobile/features/messages/providers/media_upload_service.dart';
import 'package:dio/dio.dart';

class StubDio extends Fake implements Dio {
  Object? postData;
  Options? getOptions;
  String? getPath;

  @override
  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    void Function(int, int)? onSendProgress,
    void Function(int, int)? onReceiveProgress,
  }) async {
    postData = data;
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: {
        'key': 'test-uuid-key',
        'url': '/api/media/download/test-uuid-key',
        'size': 1024,
      } as T,
      statusCode: 200,
    );
  }

  @override
  Future<Response<T>> get<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    void Function(int, int)? onReceiveProgress,
  }) async {
    getPath = path;
    getOptions = options;

    // Simulate encrypted bytes returning from MinIO
    // Concatenated nonce (12 bytes) + MAC (16 bytes) + ciphertext of 'Hello E2EE'
    final key = Uint8List(32); // zero key
    final secretKey = SecretKey(key);
    final aesGcm = AesGcm.with256bits();
    final nonce = aesGcm.newNonce();
    final secretBox = await aesGcm.encrypt(
      utf8.encode('Hello E2EE'),
      secretKey: secretKey,
      nonce: nonce,
    );
    final encBytes = secretBox.concatenation();

    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: encBytes as T,
      statusCode: 200,
    );
  }
}

void main() {
  group('MediaUploadService Cryptography & Upload/Download Tests', () {
    late MediaUploadService service;
    late StubDio stubDio;

    setUp(() {
      stubDio = StubDio();
      service = MediaUploadService(stubDio);
    });

    test('generateSymmetricKey produces secure 256-bit (32 bytes) keys', () {
      final key1 = service.generateSymmetricKey();
      final key2 = service.generateSymmetricKey();

      expect(key1.length, 32);
      expect(key2.length, 32);
      expect(key1, isNot(equals(key2))); // Cryptographically secure random check
    });

    test('AES-GCM Local Binary Encryption and Decryption Flow works perfectly', () async {
      const originalString = 'Highly confidential E2EE message payload';
      final originalData = Uint8List.fromList(utf8.encode(originalString));

      // 1. Generate key
      final keyBytes = service.generateSymmetricKey();
      final secretKey = SecretKey(keyBytes);

      // 2. Encrypt using AesGcm
      final aesGcm = AesGcm.with256bits();
      final nonce = aesGcm.newNonce();
      final secretBox = await aesGcm.encrypt(
        originalData,
        secretKey: secretKey,
        nonce: nonce,
      );

      final concatenatedBytes = Uint8List.fromList(secretBox.concatenation());

      // 3. Reconstruct SecretBox from Concatenated Binary
      final reconstructedBox = SecretBox.fromConcatenation(
        concatenatedBytes,
        nonceLength: 12,
        macLength: 16,
      );

      // 4. Decrypt and check matches
      final decryptedData = await aesGcm.decrypt(
        reconstructedBox,
        secretKey: secretKey,
      );

      expect(utf8.decode(decryptedData), originalString);
    });

    test('uploadMedia calls the correct backend endpoint and formats response', () async {
      final dummyBytes = Uint8List.fromList([1, 2, 3, 4, 5]);

      final result = await service.uploadMedia(
        fileBytes: dummyBytes,
        filename: 'secret_image.png',
        mimeType: 'image/png',
      );

      expect(result.key, 'test-uuid-key');
      expect(result.url, '/api/media/download/test-uuid-key');
      expect(result.filename, 'secret_image.png');
      expect(result.mimeType, 'image/png');
      expect(result.size, 1024);
      expect(result.mediaKeyBase64.isNotEmpty, true);

      // Verify the postData is a FormData object
      expect(stubDio.postData, isNotNull);
      expect(stubDio.postData, isA<FormData>());
    });

    test('downloadAndDecryptMedia downloads proxy encrypted bytes and decrypts them correctly', () async {
      // StubDio is pre-programmed to return encrypted 'Hello E2EE' using a 32-byte zero key
      final zeroKey = Uint8List(32);
      final keyBase64 = base64Encode(zeroKey);

      final decryptedBytes = await service.downloadAndDecryptMedia(
        mediaUrl: '/api/media/download/test-uuid-key',
        mediaKeyBase64: keyBase64,
      );

      final decryptedString = utf8.decode(decryptedBytes);
      expect(decryptedString, 'Hello E2EE');
      expect(stubDio.getPath, '/api/media/download/test-uuid-key');
      expect(stubDio.getOptions?.responseType, ResponseType.bytes);
    });
  });
}
