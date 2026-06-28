import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iz_mobile/core/theme/app_colors.dart';
import '../../providers/backup_provider.dart';

import 'package:iz_mobile/core/theme/glass_widgets.dart';
class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen>
    with SingleTickerProviderStateMixin {
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _showPasswordDialog({required bool isBackup}) {
    _passwordController.clear();
    _obscurePassword = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModal) => AppBackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: AlertDialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            contentPadding: EdgeInsets.zero,
            content: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: AppBackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.glassMedium,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                        color: AppColors.glassBorder, width: 0.6),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 40,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title row
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: isBackup
                                    ? [AppColors.accent, AppColors.accentSecondary]
                                    : [const Color(0xFF10B981), const Color(0xFF059669)],
                              ),
                            ),
                            child: Icon(
                              isBackup ? Icons.cloud_upload_rounded : Icons.cloud_download_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Text(
                            isBackup ? 'Yedekle' : 'Geri Yükle',
                            style: GoogleFonts.outfit(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 20,
                              letterSpacing: -0.4,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Description
                      Text(
                        isBackup
                            ? 'Yedeklerinizi şifrelemek için bir anahtar şifre belirleyin. Bu şifre olmadan verilerinizi geri yükleyemezsiniz.'
                            : 'Yedeğinizi çözmek için belirlediğiniz anahtar şifreyi girin.',
                        style: GoogleFonts.inter(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Password field
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: AppBackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                          child: TextField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            style: GoogleFonts.inter(color: AppColors.textPrimary),
                            decoration: InputDecoration(
                              hintText: 'Yedekleme Şifresi',
                              hintStyle: GoogleFonts.inter(
                                  color: AppColors.textMuted),
                              filled: true,
                              fillColor: AppColors.glassDark,
                              prefixIcon: const Icon(
                                Icons.lock_outline_rounded,
                                color: AppColors.accent,
                                size: 20,
                              ),
                              suffixIcon: GestureDetector(
                                onTap: () => setModal(() =>
                                    _obscurePassword = !_obscurePassword),
                                child: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: AppColors.textMuted,
                                  size: 20,
                                ),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                    color: AppColors.glassBorder, width: 0.5),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                    color: AppColors.glassBorder, width: 0.5),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                    color: AppColors.accent, width: 1.5),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => Navigator.pop(ctx),
                              child: Container(
                                height: 48,
                                decoration: BoxDecoration(
                                  color: AppColors.glassDark,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color: AppColors.glassBorder, width: 0.5),
                                ),
                                child: Center(
                                  child: Text(
                                    'İptal',
                                    style: GoogleFonts.inter(
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                final pwd = _passwordController.text.trim();
                                if (pwd.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Lütfen şifre alanını doldurun')),
                                  );
                                  return;
                                }
                                Navigator.pop(ctx);
                                if (isBackup) {
                                  _runBackup(pwd);
                                } else {
                                  _runRestore(pwd);
                                }
                              },
                              child: Container(
                                height: 48,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: isBackup
                                        ? [AppColors.accent, AppColors.accentSecondary]
                                        : [const Color(0xFF10B981), const Color(0xFF059669)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (isBackup
                                              ? AppColors.accent
                                              : const Color(0xFF10B981))
                                          .withValues(alpha: 0.35),
                                      blurRadius: 12,
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    isBackup ? 'Şifrele & Yedekle' : 'Çöz & Yükle',
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _runBackup(String password) async {
    try {
      await ref.read(backupProvider.notifier).exportAndUploadBackup(password);
      if (mounted) {
        _showSnack('Sıfır-Bilgi bulut yedeklemesi başarıyla tamamlandı!',
            isError: false);
      }
    } catch (e) {
      if (mounted) _showSnack('Yedekleme hatası: $e', isError: true);
    }
  }

  Future<void> _runRestore(String password) async {
    try {
      await ref
          .read(backupProvider.notifier)
          .downloadAndRestoreBackup(password);
      if (mounted) {
        _showSnack(
            'Sohbet geçmişiniz ve oturum anahtarlarınız başarıyla geri yüklendi!',
            isError: false);
      }
    } catch (e) {
      if (mounted) _showSnack('Geri yükleme hatası: $e', isError: true);
    }
  }

  void _showSnack(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.all(16),
        content: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: AppBackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: (isError ? AppColors.danger : AppColors.success)
                    .withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Icon(
                    isError
                        ? Icons.error_outline
                        : Icons.check_circle_outline,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      msg,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final backupState = ref.watch(backupProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.bgBase,
        extendBodyBehindAppBar: true,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: ClipRect(
            child: AppBackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: AppBar(
                backgroundColor: AppColors.bgBase.withValues(alpha: 0.75),
                elevation: 0,
                surfaceTintColor: Colors.transparent,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new,
                      size: 20, color: AppColors.textPrimary),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Text(
                  'Yedekleme',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    letterSpacing: -0.4,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        ),
        body: Stack(
          children: [
            // Ambient blobs
            Positioned(
              top: -80,
              right: -60,
              child: _blob(AppColors.accent.withValues(alpha: 0.10), 260),
            ),
            Positioned(
              bottom: 60,
              left: -80,
              child: _blob(const Color(0xFF10B981).withValues(alpha: 0.07), 220),
            ),

            FadeTransition(
              opacity: _fadeAnim,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 110, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Zero-Knowledge Banner ───────────────────────────
                    ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: AppBackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.glassLight.withValues(alpha: 0.9),
                                AppColors.glassMedium.withValues(alpha: 0.6),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                                color: AppColors.glassBorder, width: 0.6),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 24,
                                spreadRadius: -4,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              // Icon
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    colors: [
                                      AppColors.accent,
                                      AppColors.accentSecondary
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.accent
                                          .withValues(alpha: 0.4),
                                      blurRadius: 20,
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.shield_outlined,
                                    color: Colors.white, size: 36),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Sıfır-Bilgi Bulut Yedeklemesi',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(
                                  color: AppColors.textPrimary,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Verileriniz yerel cihazınızda AES-256-GCM ile şifrelendikten sonra sunucuya yüklenir. Şifreleme anahtarınız hiçbir zaman sunucuya gönderilmez.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  color: AppColors.textSecondary,
                                  fontSize: 12.5,
                                  height: 1.6,
                                ),
                              ),
                              const SizedBox(height: 20),
                              const Divider(
                                  color: AppColors.glassBorder, height: 1),
                              const SizedBox(height: 16),

                              // Last backup row
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.history_rounded,
                                          color: AppColors.textMuted, size: 16),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Son Yedekleme',
                                        style: GoogleFonts.inter(
                                          color: AppColors.textSecondary,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    backupState.lastBackupAt != null
                                        ? '${backupState.lastBackupAt!.day}.${backupState.lastBackupAt!.month}.${backupState.lastBackupAt!.year} ${backupState.lastBackupAt!.hour}:${backupState.lastBackupAt!.minute.toString().padLeft(2, '0')}'
                                        : 'Kayıt Yok',
                                    style: GoogleFonts.inter(
                                      color: AppColors.accentLight,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ── Action Buttons ──────────────────────────────────
                    if (backupState.isLoading)
                      _buildLoadingState()
                    else ...[
                      _ActionButton(
                        label: 'Şimdi Şifreli Yedekle',
                        icon: Icons.cloud_upload_rounded,
                        gradientColors: const [AppColors.accent, AppColors.accentSecondary],
                        glowColor: AppColors.accent,
                        onTap: () => _showPasswordDialog(isBackup: true),
                      ),
                      const SizedBox(height: 14),
                      _ActionButton(
                        label: 'Yedekten Geri Yükle',
                        icon: Icons.cloud_download_rounded,
                        gradientColors: const [
                          Color(0xFF10B981),
                          Color(0xFF059669)
                        ],
                        glowColor: const Color(0xFF10B981),
                        onTap: () => _showPasswordDialog(isBackup: false),
                      ),
                    ],

                    // Error
                    if (backupState.error != null) ...[
                      const SizedBox(height: 24),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: AppBackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.danger.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: AppColors.danger
                                      .withValues(alpha: 0.3),
                                  width: 0.5),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline,
                                    color: AppColors.danger, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    backupState.error!,
                                    style: GoogleFonts.inter(
                                      color: AppColors.danger,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: AppBackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
          decoration: BoxDecoration(
            color: AppColors.glassMedium,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.glassBorder, width: 0.5),
          ),
          child: Column(
            children: [
              const CircularProgressIndicator(
                color: AppColors.accent,
                strokeWidth: 2.5,
              ),
              const SizedBox(height: 16),
              Text(
                'İşlem yapılıyor, lütfen bekleyin...',
                style: GoogleFonts.inter(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _blob(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
        child: Container(color: color),
      ),
    );
  }
}

// ─── Action Button ────────────────────────────────────────────────────────────
class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final List<Color> gradientColors;
  final Color glowColor;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.gradientColors,
    required this.glowColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: glowColor.withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 12),
            Text(
              label,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
