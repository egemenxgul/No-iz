import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iz_mobile/core/theme/app_colors.dart';
import 'package:iz_mobile/core/localization/locale_provider.dart';
import 'package:iz_mobile/features/auth/providers/auth_provider.dart';
import '../widgets/auth_widgets.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _passwordController = TextEditingController();
  final _twoFAController = TextEditingController();

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    _twoFAController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = ref.read(authProvider.notifier);
    final state = ref.read(authProvider);

    if (state.requires2FA) {
      await auth.login2FA(_twoFAController.text);
    } else {
      await auth.login(_idController.text, _passwordController.text);
    }
    
    if (!mounted) return;
    final newState = ref.read(authProvider);
    if (newState.error != null) {
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
                    newState.error!,
                    style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else if (newState.isAuthenticated) {
      context.go('/app');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Orbs with rich gradients
          Positioned(
            top: -120,
            right: -80,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent.withValues(alpha: 0.15),
              ),
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                child: Container(color: AppColors.accent.withValues(alpha: 0.15)),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -80,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accentSecondary.withValues(alpha: 0.1),
              ),
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 55, sigmaY: 55),
                child: Container(color: AppColors.accentSecondary.withValues(alpha: 0.1)),
              ),
            ),
          ),
          
          // Blur layer for deep space glassmorphism
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
            child: Container(color: Colors.transparent),
          ),

          // Core Scrollable Content
          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 50),
                      // Brand Logo Icon
                      Center(
                        child: Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.accent.withValues(alpha: 0.45),
                                blurRadius: 28,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              'iz',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 34,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.8,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                      
                      // Welcome Titles
                      Center(
                        child: Text(
                          context.tr(ref, 'welcome_back'),
                          style: GoogleFonts.inter(
                            color: AppColors.textPrimary,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          context.tr(ref, 'tagline'),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            color: AppColors.textSecondary,
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                      const SizedBox(height: 48),

                      // Input Glassmorphic Card
                      ClipRRect(
                        borderRadius: BorderRadius.circular(26),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: AppColors.glassMedium,
                              borderRadius: BorderRadius.circular(26),
                              border: Border.all(
                                color: AppColors.glassBorder,
                                width: 0.5,
                              ),
                            ),
                            child: Column(
                              children: ref.watch(authProvider).requires2FA 
                              ? [
                                  Text(
                                    "2FA Doğrulama",
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  IzTextField(
                                    label: "6 Haneli Kod",
                                    hint: "Google Authenticator kodu",
                                    controller: _twoFAController,
                                    validator: (val) {
                                      if (val == null || val.trim().isEmpty) {
                                        return context.tr(ref, 'please_fill_field');
                                      }
                                      return null;
                                    },
                                  ),
                                ]
                              : [
                                  IzTextField(
                                    label: context.tr(ref, 'username'),
                                    hint: context.tr(ref, 'username'),
                                    controller: _idController,
                                    validator: (val) {
                                      if (val == null || val.trim().isEmpty) {
                                        return context.tr(ref, 'please_fill_field');
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 24),
                                  IzTextField(
                                    label: context.tr(ref, 'password'),
                                    hint: context.tr(ref, 'password'),
                                    isPassword: true,
                                    controller: _passwordController,
                                    validator: (val) {
                                      if (val == null || val.trim().isEmpty) {
                                        return context.tr(ref, 'please_enter_password');
                                      }
                                      return null;
                                    },
                                  ),
                                ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                      
                      // Action Buttons
                      IzButton(
                        label: context.tr(ref, 'login'),
                        isLoading: ref.watch(authProvider).isLoading,
                        onPressed: _handleLogin,
                      ),
                      const SizedBox(height: 24),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            context.tr(ref, 'no_account'),
                            style: GoogleFonts.inter(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                          TextButton(
                            onPressed: () => context.push('/register'),
                            child: Text(
                              context.tr(ref, 'register'),
                              style: GoogleFonts.inter(
                                color: AppColors.accentLight,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

