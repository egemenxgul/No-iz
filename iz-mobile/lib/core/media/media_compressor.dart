import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_compress/video_compress.dart';

/// Result of a compression operation, including size metadata for analytics.
class CompressResult {
  final Uint8List bytes;
  final int originalSize;
  final int compressedSize;
  final String mimeType;

  const CompressResult({
    required this.bytes,
    required this.originalSize,
    required this.compressedSize,
    required this.mimeType,
  });

  double get ratio => originalSize > 0 ? compressedSize / originalSize : 1.0;

  String get summary =>
      '${(originalSize / 1024).toStringAsFixed(1)}KB → '
      '${(compressedSize / 1024).toStringAsFixed(1)}KB '
      '(${(ratio * 100).toStringAsFixed(0)}%)';
}

/// Compresses images before upload.
/// Compress MUST happen before encryption so the encrypted blob is as small
/// as possible, reducing upload bandwidth and storage costs.
///
/// Security note: compressed bytes are still passed through AES-256-GCM
/// encryption before being sent to MinIO — compression never touches the wire.
class MediaCompressor {
  // Default constraints for uploaded images.
  static const int _maxWidth = 1920;
  static const int _maxHeight = 1920;
  static const int _defaultQuality = 85; // 85% JPEG quality — good balance

  static const _compressibleImageTypes = {
    'image/jpeg',
    'image/jpg',
    'image/png',
    'image/webp',
    'image/heic',
    'image/heif',
  };

  static const _compressibleVideoTypes = {
    'video/mp4',
    'video/quicktime', // .mov
  };

  /// Returns true if this MIME type can be compressed.
  static bool shouldCompress(String mimeType) {
    final lower = mimeType.toLowerCase();
    return _compressibleImageTypes.contains(lower) || _compressibleVideoTypes.contains(lower);
  }

  static bool isVideo(String mimeType) => _compressibleVideoTypes.contains(mimeType.toLowerCase());

  /// Centralized compression entry point.
  static Future<CompressResult> compressMedia(Uint8List bytes, String mimeType, {bool isHD = false}) async {
    final preserveTrans = mimeType.toLowerCase() == 'image/png';
    if (isVideo(mimeType)) {
      return compressVideo(bytes, mimeType, isHD: isHD);
    } else if (shouldCompress(mimeType)) {
      return compressImage(
        bytes, 
        mimeType, 
        isHD: isHD, 
        preserveTransparency: preserveTrans,
      );
    }
    return CompressResult(
      bytes: bytes,
      originalSize: bytes.length,
      compressedSize: bytes.length,
      mimeType: mimeType,
    );
  }

  /// Compresses [bytes] with the given MIME type.
  /// Returns a [CompressResult] with the (possibly smaller) byte array.
  /// If compression produces a LARGER file (rare), the original bytes are returned.
  static Future<CompressResult> compressImage(
    Uint8List bytes,
    String mimeType, {
    bool isHD = false,
    bool preserveTransparency = false,
  }) async {
    if (!shouldCompress(mimeType)) {
      return CompressResult(
        bytes: bytes,
        originalSize: bytes.length,
        compressedSize: bytes.length,
        mimeType: mimeType,
      );
    }

    try {
      final format = _formatForMime(mimeType, preserveTransparency);
      
      final w = isHD ? 3840 : _maxWidth;
      final h = isHD ? 3840 : _maxHeight;
      final q = isHD ? 100 : _defaultQuality;

      final compressed = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: w,
        minHeight: h,
        quality: q,
        format: format,
        keepExif: false, // Explicitly strip EXIF metadata
      );

      if (compressed.isEmpty) {
        // Compression failed — fall back to originals.
        return CompressResult(
          bytes: bytes,
          originalSize: bytes.length,
          compressedSize: bytes.length,
          mimeType: mimeType,
        );
      }

      // Only use compressed bytes if they are actually smaller.
      final useCompressed = compressed.length < bytes.length;
      final result = useCompressed ? compressed : bytes;
      final resultMime = useCompressed ? _mimeForFormat(format) : mimeType;

      if (kDebugMode) {
        final r = CompressResult(
          bytes: result,
          originalSize: bytes.length,
          compressedSize: result.length,
          mimeType: resultMime,
        );
        debugPrint('[MediaCompressor] ${r.summary}');
      }

      return CompressResult(
        bytes: result,
        originalSize: bytes.length,
        compressedSize: result.length,
        mimeType: resultMime,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[MediaCompressor] error: $e');
      // On any error, return the original uncompressed bytes.
      return CompressResult(
        bytes: bytes,
        originalSize: bytes.length,
        compressedSize: bytes.length,
        mimeType: mimeType,
      );
    }
  }

  /// Compresses [bytes] containing a video.
  static Future<CompressResult> compressVideo(Uint8List bytes, String mimeType, {bool isHD = false}) async {
    try {
      // video_compress requires a physical file path.
      final tempDir = await getTemporaryDirectory();
      final ext = mimeType == 'video/quicktime' ? '.mov' : '.mp4';
      final tempFile = File('${tempDir.path}/temp_video_${DateTime.now().millisecondsSinceEpoch}$ext');
      await tempFile.writeAsBytes(bytes);

      final mediaInfo = await VideoCompress.compressVideo(
        tempFile.path,
        quality: isHD ? VideoQuality.HighestQuality : VideoQuality.MediumQuality,
        deleteOrigin: true, // deletes tempFile after compression
        includeAudio: true, // ensure audio is not stripped
      );

      if (mediaInfo == null || mediaInfo.file == null) {
        return CompressResult(
          bytes: bytes,
          originalSize: bytes.length,
          compressedSize: bytes.length,
          mimeType: mimeType,
        );
      }

      final compressedBytes = await mediaInfo.file!.readAsBytes();
      
      // Clean up the compressed file from cache
      if (await mediaInfo.file!.exists()) {
        await mediaInfo.file!.delete();
      }

      final useCompressed = compressedBytes.length < bytes.length;
      final result = useCompressed ? compressedBytes : bytes;

      if (kDebugMode) {
        final r = CompressResult(
          bytes: result,
          originalSize: bytes.length,
          compressedSize: result.length,
          mimeType: mimeType,
        );
        debugPrint('[MediaCompressor] Video: ${r.summary}');
      }

      return CompressResult(
        bytes: result,
        originalSize: bytes.length,
        compressedSize: result.length,
        mimeType: mimeType,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[MediaCompressor] video error: $e');
      return CompressResult(
        bytes: bytes,
        originalSize: bytes.length,
        compressedSize: bytes.length,
        mimeType: mimeType,
      );
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  static CompressFormat _formatForMime(String mime, bool preserveTransparency) {
    switch (mime.toLowerCase()) {
      case 'image/webp':
        return CompressFormat.webp;
      case 'image/png':
        // PNG compression is lossless — use JPEG for better size reduction unless we need to keep transparency.
        return preserveTransparency ? CompressFormat.png : CompressFormat.jpeg;
      case 'image/heic':
      case 'image/heif':
        return CompressFormat.heic;
      default:
        return CompressFormat.jpeg;
    }
  }

  static String _mimeForFormat(CompressFormat format) {
    switch (format) {
      case CompressFormat.webp:
        return 'image/webp';
      case CompressFormat.heic:
        return 'image/heic';
      default:
        return 'image/jpeg';
    }
  }
}
