import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iz_mobile/core/database/database_service.dart';
import 'package:iz_mobile/features/auth/providers/auth_provider.dart';
import 'package:iz_mobile/core/network/api_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
// Note: For full ECDH encryption, we'd use the cryptography package.
// For the MVP, we assume the Web client handles the encrypted payload securely.

class QrScannerScreen extends ConsumerStatefulWidget {
  const QrScannerScreen({super.key});

  @override
  ConsumerState<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends ConsumerState<QrScannerScreen> {
  bool _isProcessing = false;
  final MobileScannerController _cameraController = MobileScannerController();

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  Future<void> _handleQrCode(BarcodeCapture capture) async {
    if (_isProcessing) return;
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? rawValue = barcodes.first.rawValue;
    if (rawValue == null || !rawValue.startsWith('iz://qr-login')) return;

    setState(() => _isProcessing = true);
    await _cameraController.stop();

    try {
      final uri = Uri.parse(rawValue);
      final token = uri.queryParameters['token'];
      final pubKeyBase64 = uri.queryParameters['pubKey'];

      if (token == null || pubKeyBase64 == null) {
        throw Exception('Geçersiz QR Kodu');
      }

      await _linkDevice(token, pubKeyBase64);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Web girişi başarılı!')),
        );
        context.pop(); // Go back
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
        setState(() => _isProcessing = false);
        await _cameraController.start();
      }
    }
  }

  Future<void> _linkDevice(String qrToken, String webPubKey) async {
    final user = ref.read(authProvider).user;
    if (user == null) throw Exception('Kullanıcı oturumu bulunamadı');

    const storage = FlutterSecureStorage();
    final identityKeyPriv = await storage.read(key: 'identity_private_key');
    final identityKeyPub = await storage.read(key: 'identity_public_key');
    final signedPrekeyPriv = await storage.read(key: 'signed_prekey_private');
    final signedPrekeyPub = await storage.read(key: 'signed_prekey_public');

    // Fetch the last 50 messages to sync to Web
    final dbService = DatabaseService();
    final db = await dbService.getDatabase(user.id);
    final messagesData = await db.query(
      'messages',
      orderBy: 'created_at DESC',
      limit: 50,
    );

    // Build the payload
    final payload = {
      'identityKey': {
        'publicKey': identityKeyPub ?? '',
        'privateKey': identityKeyPriv ?? '',
      },
      'signedPreKey': {
        'publicKey': signedPrekeyPub ?? '',
        'privateKey': signedPrekeyPriv ?? '',
      },
      'oneTimePreKeys': [],
      'recentMessages': messagesData,
    };

    // MVP: Encode payload as base64. 
    // In production: Encrypt this JSON using AES-GCM with a shared secret derived via ECDH (using webPubKey).
    final encodedPayload = base64Encode(utf8.encode(jsonEncode(payload)));

    final apiClient = ref.read(apiClientProvider);
    await apiClient.post(
      '/auth/qr-link',
      data: {
        'qr_token': qrToken,
        'encrypted_payload': encodedPayload,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Web\'e Bağlan'),
        backgroundColor: Colors.transparent,
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          MobileScanner(
            controller: _cameraController,
            onDetect: _handleQrCode,
          ),
          // QR overlay
          Container(
            decoration: ShapeDecoration(
              shape: QrScannerOverlayShape(
                borderColor: Colors.blueAccent,
                borderRadius: 10,
                borderLength: 30,
                borderWidth: 10,
                cutOutSize: 250,
              ),
            ),
          ),
          if (_isProcessing)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}

class QrScannerOverlayShape extends ShapeBorder {
  final Color borderColor;
  final double borderWidth;
  final Color overlayColor;
  final double borderRadius;
  final double borderLength;
  final double cutOutSize;

  QrScannerOverlayShape({
    this.borderColor = Colors.white,
    this.borderWidth = 3.0,
    this.overlayColor = const Color.fromRGBO(0, 0, 0, 80),
    this.borderRadius = 0,
    this.borderLength = 40,
    this.cutOutSize = 250,
  });

  @override
  EdgeInsetsGeometry get dimensions => const EdgeInsets.all(10);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addPath(getOuterPath(rect), Offset.zero);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    Path path = Path()..addRect(rect);

    rect = Rect.fromCenter(
      center: rect.center,
      width: cutOutSize,
      height: cutOutSize,
    );

    path.addRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(borderRadius)),
    );

    return path;
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final width = rect.width;
    final borderWidthSize = width / 2;
    final height = rect.height;
    final borderOffset = borderWidth / 2;
    final borderLengthSize = borderLength > cutOutSize / 2 + borderWidthSize ? borderWidthSize : borderLength;
    final cutOutRect = Rect.fromCenter(
      center: rect.center,
      width: cutOutSize,
      height: cutOutSize,
    );

    final backgroundPaint = Paint()
      ..color = overlayColor
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    canvas.drawPath(getOuterPath(rect), backgroundPaint);

    final path = Path();
    // Top Left
    path.moveTo(cutOutRect.left, cutOutRect.top + borderLengthSize);
    path.lineTo(cutOutRect.left, cutOutRect.top + borderRadius);
    path.arcToPoint(Offset(cutOutRect.left + borderRadius, cutOutRect.top),
        radius: Radius.circular(borderRadius));
    path.lineTo(cutOutRect.left + borderLengthSize, cutOutRect.top);

    // Top Right
    path.moveTo(cutOutRect.right - borderLengthSize, cutOutRect.top);
    path.lineTo(cutOutRect.right - borderRadius, cutOutRect.top);
    path.arcToPoint(Offset(cutOutRect.right, cutOutRect.top + borderRadius),
        radius: Radius.circular(borderRadius));
    path.lineTo(cutOutRect.right, cutOutRect.top + borderLengthSize);

    // Bottom Right
    path.moveTo(cutOutRect.right, cutOutRect.bottom - borderLengthSize);
    path.lineTo(cutOutRect.right, cutOutRect.bottom - borderRadius);
    path.arcToPoint(Offset(cutOutRect.right - borderRadius, cutOutRect.bottom),
        radius: Radius.circular(borderRadius));
    path.lineTo(cutOutRect.right - borderLengthSize, cutOutRect.bottom);

    // Bottom Left
    path.moveTo(cutOutRect.left + borderLengthSize, cutOutRect.bottom);
    path.lineTo(cutOutRect.left + borderRadius, cutOutRect.bottom);
    path.arcToPoint(Offset(cutOutRect.left, cutOutRect.bottom - borderRadius),
        radius: Radius.circular(borderRadius));
    path.lineTo(cutOutRect.left, cutOutRect.bottom - borderLengthSize);

    canvas.drawPath(path, borderPaint);
  }

  @override
  ShapeBorder scale(double t) {
    return QrScannerOverlayShape(
      borderColor: borderColor,
      borderWidth: borderWidth * t,
      overlayColor: overlayColor,
      borderRadius: borderRadius * t,
      borderLength: borderLength * t,
      cutOutSize: cutOutSize * t,
    );
  }
}
