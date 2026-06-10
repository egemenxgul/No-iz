import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iz_mobile/core/theme/app_colors.dart';
import 'package:iz_mobile/core/theme/glass_widgets.dart';
import 'package:iz_mobile/core/localization/locale_provider.dart';
import 'package:iz_mobile/features/auth/providers/account_provider.dart';
import 'package:iz_mobile/features/auth/providers/auth_provider.dart';
import 'package:iz_mobile/features/auth/presentation/widgets/change_email_dialog.dart';

class ProfileDetailScreen extends ConsumerStatefulWidget {
  final String accountId;
  const ProfileDetailScreen({super.key, required this.accountId});

  @override
  ConsumerState<ProfileDetailScreen> createState() => _ProfileDetailScreenState();
}

class _ProfileDetailScreenState extends ConsumerState<ProfileDetailScreen>
    with SingleTickerProviderStateMixin {
  late TextEditingController _displayNameController;
  late TextEditingController _bioController;
  String _avatarUrl = '';
  bool _isLoading = false;
  bool _isInit = false;

  late AnimationController _fadeIn;
  late Animation<double> _fadeAnim;

  final List<String> _presetAvatars = [
    'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?auto=format&fit=crop&w=150&q=80',
    'https://images.unsplash.com/photo-1620641788421-7a1c342ea42e?auto=format&fit=crop&w=150&q=80',
    'https://images.unsplash.com/photo-1579783900882-c0d3dad7b119?auto=format&fit=crop&w=150&q=80',
    'https://images.unsplash.com/photo-1550684848-fac1c5b4e853?auto=format&fit=crop&w=150&q=80',
    'https://images.unsplash.com/photo-1634017839464-5c339ebe3cb4?auto=format&fit=crop&w=150&q=80',
  ];

  @override
  void initState() {
    super.initState();
    _fadeIn = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeIn, curve: Curves.easeOut);
    _fadeIn.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      final accountState = ref.read(accountProvider);
      final account = accountState.accounts.firstWhere(
        (acc) => acc.id == widget.accountId,
        orElse: () => AccountInfo(id: '', username: ''),
      );
      _displayNameController = TextEditingController(text: account.displayName ?? '');
      _bioController = TextEditingController(text: account.bio ?? '');
      _avatarUrl = account.avatarUrl ?? '';
      _isInit = true;
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    _fadeIn.dispose();
    super.dispose();
  }

  Future<void> _saveProfileChanges() async {
    setState(() => _isLoading = true);
    try {
      final displayName = _displayNameController.text.trim();
      final bio = _bioController.text.trim();

      if (displayName.isEmpty) throw context.tr(ref, 'err_display_name_length');

      await ref.read(authServiceProvider).updateProfile(
            displayName: displayName,
            bio: bio,
            avatarUrl: _avatarUrl,
          );

      await ref.read(accountProvider.notifier).updateProfileLocal(
            widget.accountId,
            displayName: displayName,
            bio: bio,
            avatarUrl: _avatarUrl,
          );

      if (mounted) _showSnackBar(context.tr(ref, 'saved_successfully'), isError: false);
    } catch (e) {
      if (mounted) _showSnackBar(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSwitchAccount() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(accountProvider.notifier).switchAccount(widget.accountId);
      if (mounted) {
        _showSnackBar(context.tr(ref, 'success'), isError: false);
        context.go('/app');
      }
    } catch (e) {
      if (mounted) _showSnackBar(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleLogout() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(accountProvider.notifier).removeAccount(widget.accountId);
      if (mounted) context.go('/settings');
    } catch (e) {
      if (mounted) _showSnackBar(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.all(16),
        content: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: (isError ? AppColors.danger : AppColors.success).withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: (isError ? AppColors.danger : AppColors.success).withValues(alpha: 0.6),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      message,
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
        ),
      ),
    );
  }

  void _showAvatarPicker() {
    final textController = TextEditingController(text: _avatarUrl);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.bgElevated.withValues(alpha: 0.95),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                border: Border.all(color: AppColors.glassBorder, width: 0.5),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 32,
                top: 8,
                left: 24,
                right: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: AppColors.textMuted.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  Text(
                    context.tr(ref, 'choose_avatar'),
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Preset grid
                  Text(
                    context.tr(ref, 'avatar_presets'),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 68,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _presetAvatars.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (_, index) {
                        final preset = _presetAvatars[index];
                        final isSelected = _avatarUrl == preset;
                        return GestureDetector(
                          onTap: () {
                            setState(() => _avatarUrl = preset);
                            Navigator.pop(ctx);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? AppColors.accent : Colors.transparent,
                                width: 3,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: AppColors.accent.withValues(alpha: 0.4),
                                        blurRadius: 12,
                                      )
                                    ]
                                  : null,
                            ),
                            child: ClipOval(
                              child: Image.network(preset, fit: BoxFit.cover),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Custom URL
                  Text(
                    context.tr(ref, 'avatar_url'),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: TextField(
                        controller: textController,
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'https://...',
                          hintStyle: const TextStyle(color: AppColors.textMuted),
                          filled: true,
                          fillColor: AppColors.glassLight,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(color: AppColors.glassBorder, width: 0.5),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(color: AppColors.glassBorder, width: 0.5),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: _GradientButton(
                      label: context.tr(ref, 'save_changes'),
                      onTap: () {
                        setState(() => _avatarUrl = textController.text.trim());
                        Navigator.pop(ctx);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final accountState = ref.watch(accountProvider);
    final isActive = accountState.activeAccountId == widget.accountId;
    final account = accountState.accounts.firstWhere(
      (acc) => acc.id == widget.accountId,
      orElse: () => AccountInfo(id: '', username: ''),
    );

    if (account.id.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.bgBase,
        body: Center(
          child: Text(
            'Account not found',
            style: GoogleFonts.inter(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    final avatarChar = account.username.isNotEmpty ? account.username[0].toUpperCase() : '?';

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          context.tr(ref, 'profile_details'),
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(color: AppColors.bgBase.withValues(alpha: 0.6)),
          ),
        ),
      ),
      body: Stack(
        children: [
          // Ambient blobs
          Positioned(
            top: -100,
            left: -60,
            child: _blob(
              isActive ? AppColors.accent.withValues(alpha: 0.15) : AppColors.bgHover,
              280,
            ),
          ),
          Positioned(
            bottom: 80,
            right: -80,
            child: _blob(AppColors.accentSecondary.withValues(alpha: 0.1), 220),
          ),

          FadeTransition(
            opacity: _fadeAnim,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 110, 20, 40),
              physics: const BouncingScrollPhysics(),
              children: [
                // ── Avatar ──────────────────────────────────────────────
                Center(
                  child: Stack(
                    children: [
                      GlowRing(
                        color: isActive ? AppColors.accent : AppColors.bgHover,
                        blurRadius: 30,
                        spreadRadius: 2,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: isActive
                                  ? [
                                      AppColors.accent.withValues(alpha: 0.7),
                                      AppColors.accentSecondary.withValues(alpha: 0.6),
                                    ]
                                  : [AppColors.bgHover, AppColors.bgElevated],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            border: Border.all(
                              color: isActive ? AppColors.accentBorder : AppColors.glassBorder,
                              width: 2,
                            ),
                          ),
                          child: ClipOval(
                            child: _avatarUrl.isNotEmpty
                                ? Image.network(
                                    _avatarUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Center(
                                      child: Text(
                                        avatarChar,
                                        style: GoogleFonts.outfit(
                                          fontSize: 48,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  )
                                : Center(
                                    child: Text(
                                      avatarChar,
                                      style: GoogleFonts.outfit(
                                        fontSize: 48,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      if (isActive)
                        Positioned(
                          bottom: 2,
                          right: 2,
                          child: GestureDetector(
                            onTap: _showAvatarPicker,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [AppColors.accent, AppColors.accentSecondary],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.accent.withValues(alpha: 0.5),
                                    blurRadius: 10,
                                  ),
                                ],
                                border: Border.all(color: AppColors.bgBase, width: 2),
                              ),
                              child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Status badge ──────────────────────────────────────
                Center(
                  child: GlassBadge(
                    label: isActive
                        ? context.tr(ref, 'active_account')
                        : context.tr(ref, 'switch_account_tap'),
                    color: isActive ? AppColors.success : AppColors.textMuted,
                    icon: isActive ? Icons.verified_rounded : Icons.swap_horiz_rounded,
                  ),
                ),
                const SizedBox(height: 36),

                // ── Display name ──────────────────────────────────────
                _fieldLabel(context.tr(ref, 'display_name')),
                _GlassField(
                  controller: _displayNameController,
                  enabled: isActive && !_isLoading,
                  hintText: 'John Doe',
                  prefixIcon: Icons.person_outline_rounded,
                ),
                const SizedBox(height: 20),

                // ── Username (read-only) ───────────────────────────────
                _fieldLabel(context.tr(ref, 'username')),
                _GlassField(
                  controller: TextEditingController(text: account.username),
                  enabled: false,
                  prefixIcon: Icons.alternate_email_rounded,
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_outline_rounded, size: 11, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        context.tr(ref, 'username_readonly'),
                        style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Change Email ───────────────────────────────────────
                if (isActive) ...[
                  _fieldLabel(context.tr(ref, 'email_address') ?? 'E-posta Adresi'),
                  GestureDetector(
                    onTap: _isLoading
                        ? null
                        : () {
                            showDialog(
                              context: context,
                              builder: (_) => const ChangeEmailDialog(),
                            );
                          },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                        color: AppColors.glassLight,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.glassBorder, width: 0.5),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.email_outlined, color: AppColors.accent, size: 20),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              context.tr(ref, 'change_email') ?? 'E-posta Adresimi Değiştir',
                              style: GoogleFonts.inter(
                                color: AppColors.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 20),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // ── Bio ────────────────────────────────────────────────
                _fieldLabel(context.tr(ref, 'about')),
                _GlassField(
                  controller: _bioController,
                  enabled: isActive && !_isLoading,
                  hintText: 'Hey there! I am using iz.',
                  prefixIcon: Icons.info_outline_rounded,
                  maxLines: 3,
                  maxLength: 150,
                ),
                const SizedBox(height: 40),

                // ── Action buttons ─────────────────────────────────────
                if (isActive) ...[
                  _GradientButton(
                    label: context.tr(ref, 'save_changes'),
                    isLoading: _isLoading,
                    onTap: _isLoading ? null : _saveProfileChanges,
                  ),
                  const SizedBox(height: 14),
                  _DangerButton(
                    label: context.tr(ref, 'logout'),
                    onTap: _isLoading ? null : _handleLogout,
                  ),
                ] else ...[
                  _GradientButton(
                    label: context.tr(ref, 'switch_to_account'),
                    isLoading: _isLoading,
                    onTap: _isLoading ? null : _handleSwitchAccount,
                  ),
                  const SizedBox(height: 14),
                  _DangerButton(
                    label: context.tr(ref, 'logout_this_account'),
                    onTap: _isLoading ? null : _handleLogout,
                  ),
                ],
              ],
            ),
          ),

          // Loading overlay
          if (_isLoading)
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
              child: Container(
                color: Colors.black.withValues(alpha: 0.4),
                child: const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.accentLight,
                    strokeWidth: 2.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _fieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.outfit(
          color: AppColors.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
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

// ─── Shared Widgets ──────────────────────────────────────────────────────────

class _GlassField extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final String? hintText;
  final IconData prefixIcon;
  final int maxLines;
  final int? maxLength;

  const _GlassField({
    required this.controller,
    required this.enabled,
    this.hintText,
    required this.prefixIcon,
    this.maxLines = 1,
    this.maxLength,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: TextField(
          controller: controller,
          enabled: enabled,
          maxLines: maxLines,
          maxLength: maxLength,
          style: TextStyle(
            color: enabled ? AppColors.textPrimary : AppColors.textSecondary,
            fontSize: 16,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(color: AppColors.textMuted),
            filled: true,
            fillColor: enabled ? AppColors.glassMedium : AppColors.glassDark,
            prefixIcon: Padding(
              padding: maxLines > 1 ? const EdgeInsets.only(bottom: 50) : EdgeInsets.zero,
              child: Icon(prefixIcon,
                  color: enabled ? AppColors.accent : AppColors.textMuted, size: 20),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: AppColors.glassBorder, width: 0.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: AppColors.glassBorder, width: 0.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: AppColors.glassDark, width: 0.5),
            ),
            counterStyle: const TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
        ),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool isLoading;

  const _GradientButton({
    required this.label,
    this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8E2DE2).withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.2,
                  ),
                ),
        ),
      ),
    );
  }
}

class _DangerButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _DangerButton({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            width: double.infinity,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.dangerDim,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppColors.danger.withValues(alpha: 0.3),
                width: 0.5,
              ),
            ),
            child: Center(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.danger,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
