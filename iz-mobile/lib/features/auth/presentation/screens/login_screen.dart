import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:math' as math;
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

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _passwordController = TextEditingController();
  final _twoFAController = TextEditingController();

  late AnimationController _orbController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;
  late Animation<double> _orb1Anim;
  late Animation<double> _orb2Anim;
  late Animation<double> _slideAnim;

  @override
  void initState() {
    super.initState();
    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _orb1Anim = CurvedAnimation(parent: _orbController, curve: Curves.easeInOut);
    _orb2Anim = CurvedAnimation(
      parent: _orbController,
      curve: const Interval(0.3, 1.0, curve: Curves.easeInOut),
    );
    _slideAnim = Tween<double>(begin: 30, end: 0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic),
    );

    _fadeController.forward();
  }

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    _twoFAController.dispose();
    _orbController.dispose();
    _fadeController.dispose();
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
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppColors.danger.withValues(alpha: 0.5),
                width: 1,
              ),
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
                    newState.error!,
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
    } else if (newState.isAuthenticated) {
      context.go('/app');
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: Stack(
        children: [
          // ── Deep space background ───────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF050714),
                  Color(0xFF06070F),
                  Color(0xFF0A0818),
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),

          // ── Animated orb 1 (top-right) ─────────────────────────────
          AnimatedBuilder(
            animation: _orb1Anim,
            builder: (_, __) {
              final offset = math.sin(_orb1Anim.value * math.pi) * 30;
              return Positioned(
                top: -80 + offset,
                right: -60,
                child: Container(
                  width: 340,
                  height: 340,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF6366F1).withValues(alpha: 0.22),
                        const Color(0xFF6366F1).withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          // ── Animated orb 2 (bottom-left) ───────────────────────────
          AnimatedBuilder(
            animation: _orb2Anim,
            builder: (_, __) {
              final offset = math.cos(_orb2Anim.value * math.pi) * 25;
              return Positioned(
                bottom: -60 + offset,
                left: -80,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF8B5CF6).withValues(alpha: 0.16),
                        const Color(0xFF8B5CF6).withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          // ── Orb 3 — center-left accent ──────────────────────────────
          Positioned(
            top: size.height * 0.35,
            left: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF06B6D4).withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // ── Grid noise overlay ──────────────────────────────────────
          Opacity(
            opacity: 0.03,
            child: CustomPaint(
              painter: _GridPainter(),
              child: SizedBox(width: size.width, height: size.height),
            ),
          ),

          // ── Main content ────────────────────────────────────────────
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
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 26.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 56),

                          // ── Logo ──────────────────────────────────
                          Center(
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Outer glow ring
                                Container(
                                  width: 88,
                                  height: 88,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.accent.withValues(alpha: 0.35),
                                        blurRadius: 40,
                                        spreadRadius: 4,
                                      ),
                                    ],
                                  ),
                                ),
                                // Logo container
                                Container(
                                  width: 74,
                                  height: 74,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF5558EA), Color(0xFF8B5CF6)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(24),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.accent.withValues(alpha: 0.5),
                                        blurRadius: 24,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.15),
                                      width: 1,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'iz',
                                      style: GoogleFonts.outfit(
                                        color: Colors.white,
                                        fontSize: 36,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -1.5,
                                      ),
                                    ),
                                  ),
                                ),
                                // Specular highlight on logo
                                Positioned(
                                  top: 7,
                                  child: Container(
                                    width: 40,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.white.withValues(alpha: 0.25),
                                          Colors.transparent,
                                        ],
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 36),

                          // ── Titles ────────────────────────────────
                          Center(
                            child: Column(
                              children: [
                                ShaderMask(
                                  shaderCallback: (bounds) => const LinearGradient(
                                    colors: [Color(0xFFF4F7FF), Color(0xFFD4D9FF)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ).createShader(bounds),
                                  child: Text(
                                    context.tr(ref, 'welcome_back'),
                                    style: GoogleFonts.outfit(
                                      color: Colors.white,
                                      fontSize: 30,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.8,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  context.tr(ref, 'tagline'),
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    color: AppColors.textSecondary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 44),

                          // ── Input Glass Card ──────────────────────
                          _IzGlassCard(
                            child: Column(
                              children: ref.watch(authProvider).requires2FA
                                  ? [
                                      // 2FA header
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: AppColors.accentDim,
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: const Icon(
                                              Icons.shield_outlined,
                                              color: AppColors.accent,
                                              size: 18,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '2FA Doğrulama',
                                                style: GoogleFonts.outfit(
                                                  color: AppColors.textPrimary,
                                                  fontSize: 17,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              Text(
                                                'Google Authenticator kodunu girin',
                                                style: GoogleFonts.inter(
                                                  color: AppColors.textSecondary,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 20),
                                      IzTextField(
                                        label: '6 Haneli Kod',
                                        hint: '000 000',
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
                                      const SizedBox(height: 20),
                                      IzTextField(
                                        label: context.tr(ref, 'password'),
                                        hint: '••••••••',
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

                          const SizedBox(height: 28),

                          // ── Login Button ─────────────────────────
                          IzButton(
                            label: context.tr(ref, 'login'),
                            isLoading: ref.watch(authProvider).isLoading,
                            onPressed: _handleLogin,
                          ),

                          const SizedBox(height: 28),

                          // ── Register Link ─────────────────────────
                          Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  context.tr(ref, 'no_account'),
                                  style: GoogleFonts.inter(
                                    color: AppColors.textSecondary,
                                    fontSize: 14,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => context.push('/register'),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    child: Text(
                                      context.tr(ref, 'register'),
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

                          // ── Security badges ───────────────────────
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _SecurityBadge(icon: Icons.lock_outline_rounded, label: 'E2E Şifreli'),
                              const SizedBox(width: 16),
                              _SecurityBadge(icon: Icons.visibility_off_outlined, label: 'Gizlilik'),
                              const SizedBox(width: 16),
                              _SecurityBadge(icon: Icons.shield_outlined, label: 'Signal Protokol'),
                            ],
                          ),

                          const SizedBox(height: 32),
                        ],
                      ),
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

// ── Glass Card ────────────────────────────────────────────────────────────────
class _IzGlassCard extends StatelessWidget {
  final Widget child;
  const _IzGlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0x24FFFFFF), Color(0x0CFFFFFF)],
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 40,
                    spreadRadius: -8,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: child,
            ),
          ),
        ),
        // Specular top rim
        Positioned(
          top: 0,
          left: 20,
          right: 20,
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Colors.white.withValues(alpha: 0.45),
                  Colors.transparent,
                ],
              ),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Security Badge ────────────────────────────────────────────────────────────
class _SecurityBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SecurityBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.glassMedium,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.glassBorder, width: 0.5),
          ),
          child: Icon(icon, color: AppColors.accentGlow, size: 18),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: GoogleFonts.inter(
            color: AppColors.textMuted,
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

// ── Grid Painter (subtle background texture) ──────────────────────────────────
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 0.5;

    const spacing = 40.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
