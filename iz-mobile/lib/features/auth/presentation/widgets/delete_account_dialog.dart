import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iz_mobile/core/theme/app_colors.dart';
import 'package:iz_mobile/features/auth/providers/auth_provider.dart';
import 'package:go_router/go_router.dart';
import 'auth_widgets.dart';

import 'package:iz_mobile/core/theme/glass_widgets.dart';
class DeleteAccountDialog extends ConsumerStatefulWidget {
  const DeleteAccountDialog({super.key});

  @override
  ConsumerState<DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends ConsumerState<DeleteAccountDialog> {
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _deleteAccount() async {
    final password = _passwordController.text.trim();
    if (password.isEmpty) {
      setState(() => _error = "Lütfen şifrenizi girin");
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await ref.read(authServiceProvider).deleteAccount(password);
      
      if (!mounted) return;
      // Logout and navigate to auth screen
      await ref.read(authProvider.notifier).logout();
      if (!mounted) return;
      context.go('/auth');
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: AppBackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.bgElevated.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.danger.withValues(alpha: 0.5), width: 1.5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 48),
                const SizedBox(height: 16),
                Text(
                  "Hesabımı Kalıcı Olarak Sil",
                  style: GoogleFonts.outfit(
                    color: AppColors.danger,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  "Bu işlem geri alınamaz. Profiliniz, mesajlarınız ve tüm kişisel verileriniz anonimleştirilerek sistemden kaldırılacaktır.\n\nLütfen devam etmek için şifrenizi girin.",
                  style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                IzTextField(
                  label: "Şifre",
                  hint: "Mevcut şifreniz",
                  isPassword: true,
                  controller: _passwordController,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: GoogleFonts.inter(color: AppColors.danger, fontSize: 13)),
                ],
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: IzButton(
                        label: "İptal",
                        isOutlined: true,
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: IzButton(
                        label: "Sil",
                        isLoading: _isLoading,
                        onPressed: _deleteAccount,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
