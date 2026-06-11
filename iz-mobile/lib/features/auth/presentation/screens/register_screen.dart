import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:math' as math;
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

class _RegisterScreenState extends ConsumerState<RegisterScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _inviteCodeController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = false;

  late AnimationController _orbController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;
  late Animation<double> _slideAnim;

  // Step indicator
  int _currentStep = 0;
  final int _totalSteps = 2;

  @override
  void initState() {
    super.initState();
    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _slideAnim = Tween<double>(begin: 24, end: 0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic),
    );

    _fadeController.forward();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    _inviteCodeController.dispose();
    _phoneController.dispose();
    _orbController.dispose();
    _fadeController.dispose();
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
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.success.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      context.tr(ref, 'registration_success'),
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
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
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.danger.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Colors.white, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      errorMsg,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
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
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: Stack(
        children: [
          // ── Background ─────────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [
                  Color(0xFF050714),
                  Color(0xFF06070F),
                  Color(0xFF0C0916),
                ],
              ),
            ),
          ),

          // ── Animated Orbs ─────────────────────────────────────────
          AnimatedBuilder(
            animation: _orbController,
            builder: (_, __) {
              final t = _orbController.value;
              final o1 = math.sin(t * math.pi) * 30;
              final o2 = math.cos(t * math.pi * 1.3) * 25;
              return Stack(
                children: [
                  Positioned(
                    top: -60 + o1,
                    left: -80,
                    child: _Orb(
                      color: const Color(0xFF8B5CF6),
                      size: 320,
                      opacity: 0.18,
                    ),
                  ),
                  Positioned(
                    bottom: -40 + o2,
                    right: -60,
                    child: _Orb(
                      color: const Color(0xFF6366F1),
                      size: 280,
                      opacity: 0.15,
                    ),
                  ),
                  Positioned(
                    top: size.height * 0.4 + o1 * 0.5,
                    right: -20,
                    child: _Orb(
                      color: const Color(0xFF06B6D4),
                      size: 160,
                      opacity: 0.07,
                    ),
                  ),
                ],
              );
            },
          ),

          // ── Content ────────────────────────────────────────────────
          FadeTransition(
            opacity: _fadeAnim,
            child: AnimatedBuilder(
              animation: _slideAnim,
              builder: (_, child) => Transform.translate(
                offset: Offset(0, _slideAnim.value),
                child: child,
              ),
              child: SafeArea(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),

                        // ── Back + Header ────────────────────────
                        Row(
                          children: [
                            _BackButton(onTap: () => context.go('/login')),
                            const Spacer(),
                            // Step indicator
                            _StepIndicator(
                              current: _currentStep,
                              total: _totalSteps,
                            ),
                          ],
                        ),

                        const SizedBox(height: 28),

                        // ── Title ────────────────────────────────
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [Color(0xFFF4F7FF), Color(0xFFD4D9FF)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ).createShader(bounds),
                          child: Text(
                            context.tr(ref, 'create_new_account'),
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.7,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          context.tr(ref, 'security_keys_notice'),
                          style: GoogleFonts.inter(
                            color: AppColors.textSecondary,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w400,
                            height: 1.5,
                          ),
                        ),

                        const SizedBox(height: 32),

                        // ── Security notice banner ───────────────
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.accentDim,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.accentBorder,
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.lock_outline_rounded,
                                color: AppColors.accentGlow,
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Şifreleme anahtarlarınız yalnızca cihazınızda güvenli olarak saklanır.',
                                  style: GoogleFonts.inter(
                                    color: AppColors.accentGlow,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 28),

                        // ── Form Card ────────────────────────────
                        _RegisterCard(
                          children: [
                            _SectionLabel(label: 'Hesap Bilgileri', icon: Icons.person_outline_rounded),
                            const SizedBox(height: 16),
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
                            const SizedBox(height: 18),
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
                          ],
                        ),

                        const SizedBox(height: 16),

                        _RegisterCard(
                          children: [
                            _SectionLabel(label: 'İletişim', icon: Icons.mail_outline_rounded),
                            const SizedBox(height: 16),
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
                            const SizedBox(height: 18),
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
                          ],
                        ),

                        const SizedBox(height: 16),

                        _RegisterCard(
                          children: [
                            _SectionLabel(label: 'Güvenlik', icon: Icons.security_outlined),
                            const SizedBox(height: 16),
                            IzTextField(
                              label: context.tr(ref, 'password'),
                              hint: '••••••••',
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
                            const SizedBox(height: 18),
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

                        const SizedBox(height: 32),

                        IzButton(
                          label: context.tr(ref, 'register'),
                          isLoading: _isLoading,
                          onPressed: _handleRegister,
                        ),

                        const SizedBox(height: 24),

                        Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Zaten hesabın var mı?',
                                style: GoogleFonts.inter(
                                  color: AppColors.textSecondary,
                                  fontSize: 14,
                                ),
                              ),
                              GestureDetector(
                                onTap: () => context.go('/login'),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  child: Text(
                                    'Giriş Yap',
                                    style: GoogleFonts.inter(
                                      color: AppColors.accentLight,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 40),
                      ],
                    ),
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

// ── Orb ──────────────────────────────────────────────────────────────────────
class _Orb extends StatelessWidget {
  final Color color;
  final double size;
  final double opacity;
  const _Orb({required this.color, required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: opacity),
            color.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}

// ── Back Button ──────────────────────────────────────────────────────────────
class _BackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.glassMedium,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: AppColors.glassBorder, width: 0.5),
        ),
        child: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: AppColors.textPrimary,
          size: 17,
        ),
      ),
    );
  }
}

// ── Step Indicator ────────────────────────────────────────────────────────────
class _StepIndicator extends StatelessWidget {
  final int current;
  final int total;
  const _StepIndicator({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        final isActive = i <= current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: isActive ? 22 : 8,
          height: 8,
          margin: const EdgeInsets.only(left: 4),
          decoration: BoxDecoration(
            gradient: isActive
                ? AppColors.accentGradient
                : null,
            color: isActive ? null : AppColors.glassLight,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

// ── Register Card ─────────────────────────────────────────────────────────────
class _RegisterCard extends StatelessWidget {
  final List<Widget> children;
  const _RegisterCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0x20FFFFFF), Color(0x08FFFFFF)],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.10),
              width: 0.7,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ),
    );
  }
}

// ── Section Label ─────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  final IconData icon;
  const _SectionLabel({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.accentGlow, size: 16),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.outfit(
            color: AppColors.accentGlow,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
