import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iz_mobile/core/theme/app_colors.dart';
import 'package:iz_mobile/core/localization/locale_provider.dart';
import 'package:iz_mobile/features/auth/providers/auth_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'auth_widgets.dart';

class TwoFASetupDialog extends ConsumerStatefulWidget {
  const TwoFASetupDialog({super.key});

  @override
  ConsumerState<TwoFASetupDialog> createState() => _TwoFASetupDialogState();
}

class _TwoFASetupDialogState extends ConsumerState<TwoFASetupDialog> {
  final _codeController = TextEditingController();
  bool _isLoading = true;
  String? _error;
  String? _secret;
  String? _qrUrl;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _generate2FA();
  }

  Future<void> _generate2FA() async {
    try {
      final data = await ref.read(authServiceProvider).generate2FA();
      setState(() {
        _secret = data['secret'];
        _qrUrl = data['qr_url'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _verify2FA() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _error = "Lütfen 6 haneli kodu girin");
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await ref.read(authServiceProvider).verify2FA(code);
      setState(() {
        _isSuccess = true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.bgElevated.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "İki Aşamalı Doğrulama (2FA)",
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                if (_isLoading && _secret == null)
                  const CircularProgressIndicator(color: AppColors.accentLight)
                else if (_isSuccess)
                  Column(
                    children: [
                      const Icon(Icons.check_circle_outline, color: AppColors.success, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        "2FA başarıyla etkinleştirildi! Artık giriş yaparken Google Authenticator kodunu kullanmanız gerekecek.",
                        style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      IzButton(
                        label: "Tamam",
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  )
                else if (_secret != null)
                  Column(
                    children: [
                      Text(
                        "Lütfen aşağıdaki QR kodu Google Authenticator uygulaması ile tarayın veya manuel olarak kodu girin.",
                        style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: QrImageView(
                          data: _qrUrl!,
                          version: QrVersions.auto,
                          size: 160.0,
                          backgroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: _secret!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Kod kopyalandı!')),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.glassMedium,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.glassBorder),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _secret!,
                                style: GoogleFonts.robotoMono(color: Colors.white, fontSize: 18, letterSpacing: 2),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.copy, color: Colors.white70, size: 18),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      IzTextField(
                        label: "Doğrulama Kodu",
                        hint: "Uygulamadaki 6 haneli kod",
                        controller: _codeController,
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
                              label: "Doğrula",
                              isLoading: _isLoading,
                              onPressed: _verify2FA,
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                else if (_error != null)
                  Column(
                    children: [
                      Text(_error!, style: GoogleFonts.inter(color: AppColors.danger)),
                      const SizedBox(height: 16),
                      IzButton(
                        label: "Kapat",
                        onPressed: () => Navigator.pop(context),
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
