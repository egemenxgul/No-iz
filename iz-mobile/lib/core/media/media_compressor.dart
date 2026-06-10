import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

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

  // Skip compression for already-compressed formats or non-image files.
  static const _compressibleMimeTypes = {
    'image/jpeg',
    'image/jpg',
    'image/png',
    'image/webp',
    'image/heic',
    'image/heif',
  };

  /// Returns true if this MIME type can be compressed.
  static bool shouldCompress(String mimeType) =>
      _compressibleMimeTypes.contains(mimeType.toLowerCase());

  /// Compresses [bytes] with the given MIME type.
  /// Returns a [CompressResult] with the (possibly smaller) byte array.
  /// If compression produces a LARGER file (rare), the original bytes are returned.
  static Future<CompressResult> compressImage(
    Uint8List bytes,
    String mimeType, {
    int maxWidth = _maxWidth,
    int maxHeight = _maxHeight,
    int quality = _defaultQuality,
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
      final format = _formatForMime(mimeType);
      final compressed = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: 0,
        minHeight: 0,
        quality: quality,
        format: format,
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

  // ── Helpers ──────────────────────────────────────────────────────────────────

  static CompressFormat _formatForMime(String mime) {
    switch (mime.toLowerCase()) {
      case 'image/webp':
        return CompressFormat.webp;
      case 'image/png':
        // PNG compression is lossless — use JPEG for better size reduction.
        // TODO(product): Offer a "preserve transparency" option to keep PNG.
        return CompressFormat.jpeg;
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
