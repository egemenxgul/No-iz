import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iz_mobile/core/theme/app_colors.dart';
import 'package:iz_mobile/core/localization/locale_provider.dart';
import 'package:iz_mobile/core/crypto/crypto_service.dart';
import 'package:iz_mobile/core/crypto/identity_manager.dart';
import 'package:iz_mobile/features/auth/providers/auth_provider.dart';
import '../widgets/auth_widgets.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _inviteCodeController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    _inviteCodeController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isLoading) return;
    
    setState(() => _isLoading = true);
    
    try {
      final crypto = CryptoService();
      final storage = const FlutterSecureStorage();
      final identityManager = IdentityManager(crypto, storage);
      
      // 1. Generate Signal Keys for the new user locally
      await identityManager.generateAndStoreIdentity();
      
      // 2. Prepare Public Bundle for Server
      final identityKeyPair = await identityManager.getIdentityKeyPair();
      if (identityKeyPair == null) throw 'secure_keys_fail';
      
      final publicBundle = await identityManager.getPublicBundle();
      final signedPreKeyPub = crypto.fromBase64(publicBundle['signed_prekey']!);
      
      // Sign SignedPreKey with IdentityKey (Ed25519)
      final signature = await crypto.sign(identityKeyPair, signedPreKeyPub);

      // 3. Register via API
      final auth = ref.read(authServiceProvider);
      await auth.register(
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        displayName: _displayNameController.text.trim(),
        inviteCode: _inviteCodeController.text.trim().toUpperCase(),
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        signalKeys: {
          'identity_key': publicBundle['identity_key'],
          'signed_prekey': publicBundle['signed_prekey'],
          'signed_prekey_sig': signature,
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.transparent,
            elevation: 0,
            content: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.success, width: 1),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      context.tr(ref, 'registration_success'),
                      style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        context.go('/login');
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = e.toString() == 'secure_keys_fail'
            ? context.tr(ref, 'secure_keys_fail')
            : e.toString();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.transparent,
            elevation: 0,
            content: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.danger, width: 1),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      errorMsg,
                      style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient & Orbs
          Positioned(
            top: -100,
            left: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent.withValues(alpha: 0.15),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            right: -50,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent.withValues(alpha: 0.1),
              ),
            ),
          ),
          
          // Blur layer
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
            child: Container(color: Colors.transparent),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    // Back arrow
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios, color: AppColors.textPrimary),
                      onPressed: () => context.go('/login'),
                    ),
                    const SizedBox(height: 10),
                    
                    Text(
                      context.tr(ref, 'create_new_account'),
                      style: GoogleFonts.inter(
                        color: AppColors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.tr(ref, 'security_keys_notice'),
                      style: GoogleFonts.inter(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 36),

                    // Inputs inside Glassmorphic Card
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.bgSurface.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: AppColors.border.withValues(alpha: 0.1),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          IzTextField(
                            label: context.tr(ref, 'username'),
                            hint: 'izmobile',
                            controller: _usernameController,
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return context.tr(ref, 'please_enter_username');
                              }
                              if (val.trim().length < 3) {
                                return context.tr(ref, 'username_min_length');
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          IzTextField(
                            label: context.tr(ref, 'email'),
                            hint: 'info@no-iz.app',
                            controller: _emailController,
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return context.tr(ref, 'please_enter_email');
                              }
                              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(val.trim())) {
                                return context.tr(ref, 'valid_email_error');
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          IzTextField(
                            label: context.tr(ref, 'display_name'),
                            hint: 'İz Mobil',
                            controller: _displayNameController,
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return context.tr(ref, 'please_enter_display_name');
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          IzTextField(
                            label: context.tr(ref, 'phone_number_optional'),
                            hint: '+905321112233',
                            controller: _phoneController,
                            validator: (val) {
                              if (val != null && val.trim().isNotEmpty) {
                                if (!RegExp(r'^\+?[1-9]\d{1,14}$').hasMatch(val.trim())) {
                                  return context.tr(ref, 'phone_number_invalid');
                                }
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          IzTextField(
                            label: context.tr(ref, 'password'),
                            hint: context.tr(ref, 'password'),
                            isPassword: true,
                            controller: _passwordController,
                            validator: (val) {
                              if (val == null || val.isEmpty) {
                                return context.tr(ref, 'please_enter_password');
                              }
                              if (val.length < 8) {
                                return context.tr(ref, 'password_min_length');
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          IzTextField(
                            label: context.tr(ref, 'invite_code'),
                            hint: 'HELLO / MERHABA',
                            controller: _inviteCodeController,
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                  return context.tr(ref, 'please_enter_invite_code');
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    
                    IzButton(
                      label: context.tr(ref, 'register'),
                      isLoading: _isLoading,
                      onPressed: _handleRegister,
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

