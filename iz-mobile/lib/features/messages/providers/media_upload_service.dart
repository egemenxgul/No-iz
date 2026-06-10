import 'dart:math';
import 'dart:typed_data';
import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:http_parser/http_parser.dart';
import '../../../core/network/dio_provider.dart';

class UploadResult {
  final String key;
  final String url;
  final String mediaKeyBase64;
  final String filename;
  final String mimeType;
  final int size;

  UploadResult({
    required this.key,
    required this.url,
    required this.mediaKeyBase64,
    required this.filename,
    required this.mimeType,
    required this.size,
  });

  Map<String, dynamic> toMap() {
    return {
      'key': key,
      'url': url,
      'media_key': mediaKeyBase64,
      'filename': filename,
      'mime_type': mimeType,
      'size': size,
    };
  }
}

class MediaUploadService {
  final Dio _dio;
  final _aesGcm = AesGcm.with256bits();

  MediaUploadService(this._dio);

  String _parseError(DioException e, String defaultMsg) {
    try {
      final data = e.response?.data;
      if (data is Map && data.containsKey('error')) {
        return data['error']?.toString() ?? defaultMsg;
      }
      if (data is String && data.isNotEmpty) {
        return data;
      }
    } catch (_) {}
    return defaultMsg;
  }

  /// Generates a secure random 256-bit symmetric key.
  Uint8List generateSymmetricKey() {
    final rng = Random.secure();
    final bytes = Uint8List(32);
    for (var i = 0; i < 32; i++) {
      bytes[i] = rng.nextInt(256);
    }
    return bytes;
  }

  /// Encrypts local file bytes and uploads them to backend `/api/media/upload`.
  /// Returns metadata containing the generated encryption key and the download URL.
  Future<UploadResult> uploadMedia({
    required Uint8List fileBytes,
    required String filename,
    required String mimeType,
    void Function(double)? onProgress,
  }) async {
    // 1. Generate ephemeral AES-256 key
    final key = generateSymmetricKey();

    // 2. Encrypt bytes using AES-GCM
    final secretKey = SecretKey(key);
    final nonce = _aesGcm.newNonce();
    final secretBox = await _aesGcm.encrypt(
      fileBytes,
      secretKey: secretKey,
      nonce: nonce,
    );

    // Concatenate: nonce (12 bytes) + MAC (16 bytes) + ciphertext
    final encryptedBytes = Uint8List.fromList(secretBox.concatenation());

    // 3. Prepare Multipart FormData
    final uuidName = '${const Uuid().v4()}.enc';
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        encryptedBytes,
        filename: uuidName,
        contentType: MediaType('application', 'octet-stream'),
      ),
    });

    // 4. Send upload POST request with progress tracking
    try {
      final response = await _dio.post(
        '/api/media/upload',
        data: formData,
        onSendProgress: (sent, total) {
          if (total > 0 && onProgress != null) {
            onProgress(sent / total);
          }
        },
      );

      final data = response.data;
      final keyParam = data['key'] as String;
      final urlParam = data['url'] as String;
      final sizeParam = data['size'] as int;

      return UploadResult(
        key: keyParam,
        url: urlParam,
        mediaKeyBase64: base64Encode(key),
        filename: filename,
        mimeType: mimeType,
        size: sizeParam,
      );
    } on DioException catch (e) {
      throw _parseError(e, 'Medya yüklenirken hata oluştu');
    }
  }

  /// Downloads proxy'd encrypted media payload from `/api/media/download/{key}` and decrypts it.
  Future<Uint8List> downloadAndDecryptMedia({
    required String mediaUrl,
    required String mediaKeyBase64,
  }) async {
    try {
      // 1. Fetch encrypted bytes from authenticated endpoint
      final response = await _dio.get<List<int>>(
        mediaUrl,
        options: Options(responseType: ResponseType.bytes),
      );

      final encryptedBytes = Uint8List.fromList(response.data!);

      // 2. Extract key
      final key = base64Decode(mediaKeyBase64);
      final secretKey = SecretKey(key);

      // 3. Reconstruct SecretBox: nonce length 12, mac length 16
      final secretBox = SecretBox.fromConcatenation(
        encryptedBytes,
        nonceLength: 12,
        macLength: 16,
      );

      // 4. Decrypt AES-GCM payload
      final plaintext = await _aesGcm.decrypt(
        secretBox,
        secretKey: secretKey,
      );

      return Uint8List.fromList(plaintext);
    } on DioException catch (e) {
      throw _parseError(e, 'Medya indirilirken hata oluştu');
    } catch (e) {
      throw 'Medya deşifre edilemedi: $e';
    }
  }
}

final mediaUploadServiceProvider = Provider<MediaUploadService>((ref) {
  final dio = ref.watch(dioProvider);
  return MediaUploadService(dio);
});
