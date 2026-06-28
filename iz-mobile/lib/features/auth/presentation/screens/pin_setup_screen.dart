import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/iz_button.dart';
import '../../../core/network/dio_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/crypto_service.dart';
import '../providers/identity_manager.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PinSetupScreen extends ConsumerStatefulWidget {
  const PinSetupScreen({super.key});

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen> {
  String _pin = '';
  String _confirmPin = '';
  bool _isConfirming = false;
  bool _isLoading = false;

  void _onKeyPress(String key) {
    if (_isLoading) return;

    setState(() {
      if (!_isConfirming) {
        if (_pin.length < 6) _pin += key;
        if (_pin.length == 6) {
          Future.delayed(const Duration(milliseconds: 300), () {
            setState(() => _isConfirming = true);
          });
        }
      } else {
        if (_confirmPin.length < 6) _confirmPin += key;
        if (_confirmPin.length == 6) {
          _submitPin();
        }
      }
    });
  }

  void _onBackspace() {
    if (_isLoading) return;
    setState(() {
      if (!_isConfirming && _pin.isNotEmpty) {
        _pin = _pin.substring(0, _pin.length - 1);
      } else if (_isConfirming && _confirmPin.isNotEmpty) {
        _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
      }
    });
  }

  Future<void> _submitPin() async {
    if (_pin != _confirmPin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN numaraları eşleşmiyor. Lütfen tekrar deneyin.')),
      );
      setState(() {
        _pin = '';
        _confirmPin = '';
        _isConfirming = false;
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      final crypto = CryptoService();
      const storage = FlutterSecureStorage();
      final identityManager = IdentityManager(crypto, storage);

      // Generate E2E keys
      await identityManager.generateAndStoreIdentity();
      final identityKeyPair = await identityManager.getIdentityKeyPair();
      final publicBundle = await identityManager.getPublicBundle();
      final signedPreKeyPub = crypto.fromBase64(publicBundle['signed_prekey']!);
      final signature = await crypto.sign(identityKeyPair!, signedPreKeyPub);

      // We need to send PIN and keys to server
      final dio = ref.read(dioProvider);
      await dio.post('/auth/pin/setup', data: {
        'pin': _pin,
        'identity_key': publicBundle['identity_key'],
        'signed_prekey': publicBundle['signed_prekey'],
        'signed_prekey_sig': signature,
        'one_time_prekeys': [], // Usually generate a batch of OTPs here, omit for brevity in setup
      });

      // Save password/PIN to secure storage so IdentityManager can derive key
      await storage.write(key: 'iz_password', value: _pin);

      if (mounted) {
        context.go('/app'); // Go to main app
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildDot(bool isFilled) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: isFilled ? AppColors.accentPrimary : AppColors.glassDim,
        shape: BoxShape.circle,
        border: isFilled ? null : Border.all(color: AppColors.borderDim),
      ),
    );
  }

  Widget _buildKeypadButton(String text) {
    return Expanded(
      child: AspectRatio(
        aspectRatio: 1.5,
        child: InkWell(
          onTap: () => _onKeyPress(text),
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: Text(
              text,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentLength = _isConfirming ? _confirmPin.length : _pin.length;

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Column(
            children: [
              Text(
                _isConfirming ? 'PIN Kodunu Doğrulayın' : 'Güvenlik PIN\'i Belirleyin',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Bu PIN kodu mesajlarınızı şifrelemek için kullanılacaktır. Unutmanız durumunda mesajlarınız geri getirilemez.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (index) => _buildDot(index < currentLength)),
              ),
              const Spacer(),
              Column(
                children: [
                  Row(children: ['1', '2', '3'].map((e) => _buildKeypadButton(e)).toList()),
                  Row(children: ['4', '5', '6'].map((e) => _buildKeypadButton(e)).toList()),
                  Row(children: ['7', '8', '9'].map((e) => _buildKeypadButton(e)).toList()),
                  Row(
                    children: [
                      const Expanded(child: SizedBox()),
                      _buildKeypadButton('0'),
                      Expanded(
                        child: InkWell(
                          onTap: _onBackspace,
                          borderRadius: BorderRadius.circular(16),
                          child: const Center(
                            child: Icon(Icons.backspace_outlined, color: Colors.white, size: 28),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (_isLoading)
                const CircularProgressIndicator(color: AppColors.accentPrimary),
            ],
          ),
        ),
      ),
    );
  }
}
