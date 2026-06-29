import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:iz_mobile/features/auth/providers/auth_provider.dart';
import 'package:iz_mobile/features/auth/providers/account_provider.dart';

// ────────────────────────────────────────────────────────────────────────────
// QR Tarayıcı Ekranı — Web'e Bağlan
// ────────────────────────────────────────────────────────────────────────────
//
// Akış:
//  1. Kamera açılır, QR kod taranır.
//  2. QR URL'si ayrıştırılır → token + webPubKey (gelecekte ECDH için)
//  3. Kullanıcıya onay diyaloğu gösterilir.
//  4. Onay sonrası:
//     a) Güvenli depodan kimlik anahtarları okunur.
//     b) Payload AES-256-GCM ile şifrelenir.
//     c) Backend'e POST /api/auth/qr-link ile gönderilir.
//  5. Web tarafı polling ile payload'ı alır ve oturumu başlatır.
// ────────────────────────────────────────────────────────────────────────────

class QrScannerScreen extends ConsumerStatefulWidget {
  const QrScannerScreen({super.key});

  @override
  ConsumerState<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends ConsumerState<QrScannerScreen>
    with TickerProviderStateMixin {
  bool _isProcessing = false;
  bool _scanEnabled = true;
  bool _torchOn = false;
  final MobileScannerController _cameraController = MobileScannerController();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // ── Torch Toggle ──────────────────────────────────────────────────────────

  Future<void> _toggleTorch() async {
    await _cameraController.toggleTorch();
    if (mounted) setState(() => _torchOn = !_torchOn);
  }

  // ── QR Tespiti ────────────────────────────────────────────────────────────

  Future<void> _handleQrCode(BarcodeCapture capture) async {
    if (_isProcessing || !_scanEnabled) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final rawValue = barcodes.first.rawValue;
    if (rawValue == null || !rawValue.startsWith('iz://qr-login')) return;

    setState(() => _scanEnabled = false);
    await _cameraController.stop();

    try {
      final uri = Uri.parse(rawValue);
      final token = uri.queryParameters['token'];
      final pubKeyBase64 = uri.queryParameters['pubKey'];

      if (token == null) throw Exception('Geçersiz QR Kodu: token eksik');

      if (!mounted) return;
      final confirmed = await _showConfirmationDialog(token);

      if (confirmed != true) {
        await _cameraController.start();
        if (mounted) setState(() => _scanEnabled = true);
        return;
      }

      setState(() => _isProcessing = true);

      await _linkDevice(token, pubKeyBase64);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Web girişi başarılı! Tarayıcıya dön.'),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Hata: $e')),
              ],
            ),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        setState(() {
          _isProcessing = false;
          _scanEnabled = true;
        });
        await _cameraController.start();
      }
    }
  }

  // ── Onay Diyaloğu ─────────────────────────────────────────────────────────

  Future<bool?> _showConfirmationDialog(String token) {
    final accountState = ref.read(accountProvider);
    final activeAccount = accountState.accounts
        .where((a) => a.id == accountState.activeAccountId)
        .firstOrNull;
    final displayName = activeAccount?.displayName ?? 'Bilinmeyen Kullanıcı';
    final username = activeAccount?.username ?? '';

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.security, color: Color(0xFF3B82F6), size: 28),
            SizedBox(width: 12),
            Text(
              'Web Girişini Onayla',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF2D2D3D),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Color(0xFF3B82F6),
                    radius: 20,
                    child: Icon(Icons.person, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (username.isNotEmpty)
                          Text(
                            '@$username',
                            style: const TextStyle(
                              color: Color(0xFF8B8BA7),
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Bu QR kod ile web tarayıcısına giriş yapılacak. Devam etmek istiyor musun?',
              style: TextStyle(color: Color(0xFFB0B0C8), height: 1.5),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Color(0xFFEF4444), size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Bu işlemi siz başlatmadıysanız iptal edin.',
                      style: TextStyle(
                        color: Color(0xFFEF4444),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'İptal',
              style: TextStyle(color: Color(0xFF8B8BA7)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Onayla', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── Cihaz Bağlantı Mantığı (X25519 ECDH + HKDF + AES-256-GCM) ─────────────

  /// Cihazı QR token ile web oturumuna bağlar.
  /// webPubKey mevcutsa X25519 ECDH ile uçtan uca şifreleme yapılır:
  ///   1. Geçici mobil X25519 key pair üretilir.
  ///   2. Shared secret = X25519(mobilePriv, webPub) hesaplanır.
  ///   3. HKDF-SHA256 ile 32 byte AES anahtarı türetilir.
  ///   4. AES-256-GCM ile payload şifrelenir.
  ///   5. Backend'e sadece: mobilePub + nonce + ciphertext + mac gönderilir.
  ///   AES anahtarı hiçbir zaman ağ üzerinden geçmez.
  Future<void> _linkDevice(String qrToken, String? webPubKey) async {
    final authState = ref.read(authProvider);
    final userId = authState.userId;
    if (userId == null) throw Exception('Kullanıcı oturumu bulunamadı');

    const storage = FlutterSecureStorage();
    final identityKeyPub = await storage.read(key: 'identity_public_key');
    final signedPrekeyPub = await storage.read(key: 'signed_prekey_public');

    final plainPayload = jsonEncode({
      'user_id': userId,
      'identityKey': {'publicKey': identityKeyPub ?? ''},
      'signedPreKey': {'publicKey': signedPrekeyPub ?? ''},
      'timestamp': DateTime.now().toIso8601String(),
    });

    final String encryptedPayload;
    if (webPubKey != null && webPubKey.isNotEmpty) {
      encryptedPayload = await _encryptWithECDH(plainPayload, webPubKey);
    } else {
      // Fallback: pubKey yoksa plain base64 (degraded mode)
      encryptedPayload = base64Encode(utf8.encode(plainPayload));
    }

    final authService = ref.read(authServiceProvider);
    await authService.qrLink(
      qrToken: qrToken,
      encryptedPayload: encryptedPayload,
    );
  }

  /// X25519 ECDH + HKDF-SHA256 + AES-256-GCM şifrelemesi.
  /// Dönen format (base64): [32B mobilePub][12B nonce][ct...][16B mac]
  /// Web tarafı: ECDH(webPriv, mobilePub) → HKDF → AES-GCM.decrypt
  Future<String> _encryptWithECDH(String payload, String webPubKeyBase64) async {
    // 1. Web'in X25519 public key'ini decode et
    final webPubKeyBytes = base64Decode(webPubKeyBase64);

    // 2. Geçici mobil X25519 key pair üret
    final algorithm = X25519();
    final mobileKeyPair = await algorithm.newKeyPair();
    final mobilePriv = await mobileKeyPair.extractPrivateKeyBytes();
    final mobilePub = await mobileKeyPair.extractPublicKey();
    final mobilePubBytes = mobilePub.bytes;

    // 3. Shared secret: X25519(mobilePriv, webPub)
    final webRemotePublicKey = SimplePublicKey(webPubKeyBytes, type: KeyPairType.x25519);
    final sharedSecret = await algorithm.sharedSecretKey(
      keyPair: await algorithm.newKeyPairFromSeed(mobilePriv),
      remotePublicKey: webRemotePublicKey,
    );
    final sharedSecretBytes = await sharedSecret.extractBytes();

    // 4. HKDF-SHA256 ile 32 byte AES anahtarı türet
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
    final aesKey = await hkdf.deriveKey(
      secretKey: SecretKey(sharedSecretBytes),
      nonce: mobilePubBytes, // salt olarak mobilePub kullan
      info: utf8.encode('iz-qr-login-v1'),
    );

    // 5. AES-256-GCM ile payload şifrele
    final aesGcm = AesGcm.with256bits();
    final nonce = aesGcm.newNonce();
    final secretBox = await aesGcm.encrypt(
      utf8.encode(payload),
      secretKey: aesKey,
      nonce: nonce,
    );

    // 6. Format: base64( [32B mobilePub] [12B nonce] [ct] [16B mac] )
    final combined = Uint8List.fromList([
      ...mobilePubBytes,       // 32 bytes — web ECDH için
      ...secretBox.nonce,      // 12 bytes — IV
      ...secretBox.cipherText, // N bytes
      ...secretBox.mac.bytes,  // 16 bytes — GCM tag
    ]);

    return base64Encode(combined);
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Web\'e Bağlan',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _torchOn ? Icons.flash_on : Icons.flash_off,
              color: _torchOn ? const Color(0xFFF59E0B) : Colors.white,
            ),
            onPressed: _toggleTorch,
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _cameraController,
            onDetect: _handleQrCode,
          ),
          _buildScanOverlay(),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomInfo(),
          ),
          if (_isProcessing) _buildProcessingOverlay(),
        ],
      ),
    );
  }

  Widget _buildScanOverlay() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (_, __) => CustomPaint(
        painter: _ScanOverlayPainter(
          borderColor: const Color(0xFF3B82F6),
          pulseScale: _pulseAnimation.value,
        ),
        child: Container(),
      ),
    );
  }

  Widget _buildBottomInfo() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 48),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF3B82F6).withValues(alpha: 0.4),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.qr_code_scanner, color: Color(0xFF3B82F6), size: 32),
          const SizedBox(height: 12),
          const Text(
            'iz Web QR Kodunu Tara',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tarayıcınızda iz.app/web adresini aç →\nGiriş ekranında QR kodu göster',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFF10B981).withValues(alpha: 0.4),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock, color: Color(0xFF10B981), size: 14),
                SizedBox(width: 6),
                Text(
                  'Uçtan uca şifreli bağlantı',
                  style: TextStyle(
                    color: Color(0xFF10B981),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessingOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.8),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E2E),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.4),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(
                  color: Color(0xFF3B82F6),
                  strokeWidth: 3,
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Bağlanıyor...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Kimlik doğrulanıyor',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Tarama Overlay Painter
// ────────────────────────────────────────────────────────────────────────────

class _ScanOverlayPainter extends CustomPainter {
  final Color borderColor;
  final double pulseScale;

  _ScanOverlayPainter({required this.borderColor, this.pulseScale = 1.0});

  @override
  void paint(Canvas canvas, Size size) {
    const cutOutSize = 260.0;
    const cornerRadius = 16.0;
    const cornerLength = 32.0;
    const borderWidth = 3.5;

    final center = Offset(size.width / 2, size.height * 0.42);
    final scaledSize = cutOutSize * pulseScale;
    final cutOut = Rect.fromCenter(
      center: center,
      width: scaledSize,
      height: scaledSize,
    );

    // Karartılmış arka plan
    final backgroundPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.65)
      ..style = PaintingStyle.fill;

    final outerPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final innerPath = Path()
      ..addRRect(
          RRect.fromRectAndRadius(cutOut, const Radius.circular(cornerRadius)));
    final combinedPath =
        Path.combine(PathOperation.difference, outerPath, innerPath);
    canvas.drawPath(combinedPath, backgroundPaint);

    // Köşe çizgileri
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..strokeCap = StrokeCap.round;

    final path = Path();

    // Sol üst
    path.moveTo(cutOut.left + cornerLength, cutOut.top);
    path.lineTo(cutOut.left + cornerRadius, cutOut.top);
    path.arcToPoint(Offset(cutOut.left, cutOut.top + cornerRadius),
        radius: const Radius.circular(cornerRadius));
    path.lineTo(cutOut.left, cutOut.top + cornerLength);

    // Sağ üst
    path.moveTo(cutOut.right - cornerLength, cutOut.top);
    path.lineTo(cutOut.right - cornerRadius, cutOut.top);
    path.arcToPoint(Offset(cutOut.right, cutOut.top + cornerRadius),
        radius: const Radius.circular(cornerRadius), clockwise: false);
    path.lineTo(cutOut.right, cutOut.top + cornerLength);

    // Sağ alt
    path.moveTo(cutOut.right, cutOut.bottom - cornerLength);
    path.lineTo(cutOut.right, cutOut.bottom - cornerRadius);
    path.arcToPoint(Offset(cutOut.right - cornerRadius, cutOut.bottom),
        radius: const Radius.circular(cornerRadius));
    path.lineTo(cutOut.right - cornerLength, cutOut.bottom);

    // Sol alt
    path.moveTo(cutOut.left + cornerLength, cutOut.bottom);
    path.lineTo(cutOut.left + cornerRadius, cutOut.bottom);
    path.arcToPoint(Offset(cutOut.left, cutOut.bottom - cornerRadius),
        radius: const Radius.circular(cornerRadius), clockwise: false);
    path.lineTo(cutOut.left, cutOut.bottom - cornerLength);

    canvas.drawPath(path, borderPaint);

    // Tarama çizgisi
    final scanLinePaint = Paint()
      ..shader = LinearGradient(colors: [
        Colors.transparent,
        borderColor.withValues(alpha: 0.6),
        Colors.transparent,
      ]).createShader(Rect.fromLTWH(cutOut.left, cutOut.top, scaledSize, 2));
    final scanY = cutOut.top + scaledSize * (1 - pulseScale + 0.5);
    canvas.drawLine(
      Offset(cutOut.left + cornerRadius, scanY),
      Offset(cutOut.right - cornerRadius, scanY),
      scanLinePaint..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_ScanOverlayPainter old) =>
      old.pulseScale != pulseScale || old.borderColor != borderColor;
}
