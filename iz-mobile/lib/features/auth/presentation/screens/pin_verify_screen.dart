import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/colors.dart';
import '../../../core/network/dio_provider.dart';
import '../providers/crypto_service.dart';
import '../providers/identity_manager.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PinVerifyScreen extends ConsumerStatefulWidget {
  const PinVerifyScreen({super.key});

  @override
  ConsumerState<PinVerifyScreen> createState() => _PinVerifyScreenState();
}

class _PinVerifyScreenState extends ConsumerState<PinVerifyScreen> {
  String _pin = '';
  bool _isLoading = false;

  void _onKeyPress(String key) {
    if (_isLoading) return;

    setState(() {
      if (_pin.length < 6) _pin += key;
      if (_pin.length == 6) {
        _verifyPin();
      }
    });
  }

  void _onBackspace() {
    if (_isLoading) return;
    setState(() {
      if (_pin.isNotEmpty) {
        _pin = _pin.substring(0, _pin.length - 1);
      }
    });
  }

  Future<void> _verifyPin() async {
    setState(() => _isLoading = true);

    try {
      final dio = ref.read(dioProvider);
      await dio.post('/auth/pin/verify', data: {
        'pin': _pin,
      });

      // Save password/PIN to secure storage so IdentityManager can derive key
      const storage = FlutterSecureStorage();
      await storage.write(key: 'iz_password', value: _pin);

      if (mounted) {
        context.go('/app');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hatalı PIN, lütfen tekrar deneyin.')),
        );
        setState(() {
          _pin = '';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _resetPin() async {
    // Navigate to PIN reset or show dialog
    final emailController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgBase,
        title: Text('PIN Sıfırlama', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('PIN sıfırlama işlemi eski şifreli mesajlarınızı okunamayacak hale getirir.', style: TextStyle(color: Colors.redAccent)),
            SizedBox(height: 16),
            TextField(
              controller: emailController,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'E-posta adresiniz',
                hintStyle: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('İptal'),
          ),
          TextButton(
            onPressed: () async {
              try {
                final dio = ref.read(dioProvider);
                await dio.post('/auth/pin/reset/request', data: {'email': emailController.text});
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sıfırlama bağlantısı gönderildi.')));
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata oluştu: $e')));
              }
            },
            child: Text('Sıfırla', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
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
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Column(
            children: [
              Text(
                'Uygulama Kilidi',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Lütfen mesajlarınızın şifresini çözmek için 6 haneli PIN kodunuzu girin.',
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
                children: List.generate(6, (index) => _buildDot(index < _pin.length)),
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
              const SizedBox(height: 16),
              TextButton(
                onPressed: _resetPin,
                child: Text('PIN Kodunu Unuttum', style: TextStyle(color: AppColors.textSecondary)),
              )
            ],
          ),
        ),
      ),
    );
  }
}
