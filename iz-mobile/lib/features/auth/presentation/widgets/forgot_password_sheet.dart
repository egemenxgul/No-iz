import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iz_mobile/core/theme/app_colors.dart';
import 'package:iz_mobile/core/localization/locale_provider.dart';
import 'package:dio/dio.dart';
import '../../../../core/network/dio_provider.dart';
import 'auth_widgets.dart';

class ForgotPasswordSheet extends ConsumerStatefulWidget {
  const ForgotPasswordSheet({super.key});

  @override
  ConsumerState<ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: const ForgotPasswordSheet(),
      ),
    );
  }
}

class _ForgotPasswordSheetState extends ConsumerState<ForgotPasswordSheet> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isSuccess = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);

    try {
      final dio = ref.read(dioProvider);
      await dio.post('/auth/forgot-password', data: {
        'email': _emailController.text.trim(),
      });
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isSuccess = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.danger,
            content: Text('Bir hata oluştu. Lütfen tekrar deneyin.', 
              style: GoogleFonts.inter(color: Colors.white)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textMuted.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          
          if (_isSuccess) ...[
            const Icon(Icons.check_circle_outline, color: AppColors.success, size: 64),
            const SizedBox(height: 16),
            Text(
              'Sıfırlama Bağlantısı Gönderildi',
              style: GoogleFonts.outfit(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'E-posta adresinize şifre sıfırlama talimatlarını içeren bir bağlantı gönderdik.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            IzButton(
              label: 'Kapat',
              onPressed: () => Navigator.pop(context),
            ),
          ] else ...[
            Text(
              'Şifrenizi mi Unuttunuz?',
              style: GoogleFonts.outfit(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Hesabınıza bağlı e-posta adresini girin, size sıfırlama bağlantısı gönderelim.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            Form(
              key: _formKey,
              child: IzTextField(
                label: 'E-posta Adresi',
                hint: 'ornek@email.com',
                controller: _emailController,
                textInputType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Lütfen e-posta adresinizi girin';
                  }
                  if (!val.contains('@')) {
                    return 'Geçerli bir e-posta girin';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 24),
            IzButton(
              label: 'Bağlantı Gönder',
              isLoading: _isLoading,
              onPressed: _handleSubmit,
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
