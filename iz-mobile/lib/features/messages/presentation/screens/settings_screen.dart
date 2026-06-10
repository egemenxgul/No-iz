import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iz_mobile/core/theme/app_colors.dart';
import 'package:iz_mobile/core/localization/locale_provider.dart';
import 'package:iz_mobile/features/auth/providers/account_provider.dart';
import 'package:iz_mobile/features/auth/providers/auth_provider.dart';
import 'package:iz_mobile/features/backup/presentation/screens/backup_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _autoBackup = true;
  bool _includeMedia = false;

  @override
  Widget build(BuildContext context) {
    final accountState = ref.watch(accountProvider);
    final activeId = accountState.activeAccountId;

    final activeAcc = accountState.accounts.firstWhere(
      (acc) => acc.id == activeId,
      orElse: () => AccountInfo(id: '', username: ''),
    );
    final otherAccs = accountState.accounts.where((acc) => acc.id != activeId).toList();
    final orderedAccounts = [
      if (activeAcc.id.isNotEmpty) activeAcc,
      ...otherAccs,
    ];

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          context.tr(ref, 'settings'),
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            letterSpacing: -0.4,
          ),
        ),
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(color: AppColors.bgBase.withValues(alpha: 0.7)),
          ),
        ),
      ),
      body: Stack(
        children: [
          // Ambient blobs
          Positioned(
            top: -60,
            right: -60,
            child: _blob(AppColors.accent.withValues(alpha: 0.12), 260),
          ),
          Positioned(
            bottom: 100,
            left: -80,
            child: _blob(AppColors.accentSecondary.withValues(alpha: 0.08), 220),
          ),

          ListView(
            padding: const EdgeInsets.fromLTRB(16, 110, 16, 40),
            physics: const BouncingScrollPhysics(),
            children: [
              // ── Accounts ────────────────────────────────────────────
              _sectionTitle(context.tr(ref, 'accounts')),
              _GlassSection(
                children: [
                  ...orderedAccounts.map((acc) => _AccountTile(
                        acc: acc,
                        isActive: acc.id == activeId,
                        ref: ref,
                      )),
                  if (accountState.accounts.length < 2)
                    _GlassTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.accentDim,
                        ),
                        child: const Icon(Icons.add, color: AppColors.accent, size: 22),
                      ),
                      title: context.tr(ref, 'add_account'),
                      titleColor: AppColors.accentLight,
                      onTap: () => context.push('/login?adding=true'),
                    ),
                ],
              ),
              const SizedBox(height: 28),

              // ── Language ────────────────────────────────────────────
              _sectionTitle(context.tr(ref, 'language_setting')),
              _GlassSection(
                children: [
                  _GlassTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF06B6D4), Color(0xFF3B82F6)],
                        ),
                      ),
                      child: const Icon(Icons.language, color: Colors.white, size: 20),
                    ),
                    title: context.tr(ref, 'language_setting'),
                    subtitle: context.tr(ref, 'language_current'),
                    trailing: const Icon(Icons.swap_horiz_rounded, color: AppColors.textMuted),
                    onTap: () => ref.read(localeProvider.notifier).toggleLanguage(),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // ── Profile ────────────────────────────────────────────
              _sectionTitle(context.tr(ref, 'profile')),
              _GlassSection(
                children: [
                  _GlassTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                        ),
                      ),
                      child: const Icon(Icons.person_outline, color: Colors.white, size: 20),
                    ),
                    title: context.tr(ref, 'profile_info'),
                    subtitle: activeAcc.id.isNotEmpty
                        ? '${activeAcc.displayName ?? activeAcc.username} (@${activeAcc.username})'
                        : context.tr(ref, 'profile_info_sub'),
                    onTap: activeAcc.id.isNotEmpty
                        ? () => context.push('/settings/profile?id=${activeAcc.id}')
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // ── Web Login ────────────────────────────────────────────
              _sectionTitle('Web Bağlantısı'),
              _GlassSection(
                children: [
                  _GlassTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF10B981), Color(0xFF047857)],
                        ),
                      ),
                      child: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 20),
                    ),
                    title: 'Web\'e Bağlan',
                    subtitle: 'QR kod okutarak web üzerinden giriş yapın',
                    onTap: () => context.push('/qr-scanner'),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // ── Backup ─────────────────────────────────────────────
              _sectionTitle(context.tr(ref, 'backup_cloud')),
              _GlassSection(
                children: [
                  _SwitchTile(
                    icon: Icons.cloud_upload_outlined,
                    iconGradient: const LinearGradient(
                      colors: [Color(0xFF34D399), Color(0xFF10B981)],
                    ),
                    title: context.tr(ref, 'auto_backup'),
                    subtitle: context.tr(ref, 'auto_backup_sub'),
                    value: _autoBackup,
                    onChanged: (v) => setState(() => _autoBackup = v),
                  ),
                  const _Divider(),
                  _SwitchTile(
                    icon: Icons.image_outlined,
                    iconGradient: const LinearGradient(
                      colors: [Color(0xFFF59E0B), Color(0xFFF97316)],
                    ),
                    title: context.tr(ref, 'include_media'),
                    subtitle: context.tr(ref, 'include_media_sub'),
                    value: _includeMedia,
                    onChanged: (v) => setState(() => _includeMedia = v),
                  ),
                  const _Divider(),
                  _GlassTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.bgHover,
                      ),
                      child: const Icon(Icons.history, color: AppColors.textSecondary, size: 20),
                    ),
                    title: context.tr(ref, 'backup_now'),
                    subtitle: context.tr(ref, 'last_backup'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const BackupScreen()),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // ── iz Settings ─────────────────────────────────────────
              _sectionTitle('iz'),
              _GlassSection(
                children: [
                  _GlassTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                        ),
                      ),
                      child: const Icon(Icons.lock_outline, color: Colors.white, size: 20),
                    ),
                    title: context.tr(ref, 'privacy_security'),
                    subtitle: context.tr(ref, 'privacy_sub'),
                    onTap: () => context.push('/settings/privacy'),
                  ),
                  const _Divider(),
                  _GlassTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.dangerDim,
                      ),
                      child: const Icon(Icons.logout, color: AppColors.danger, size: 20),
                    ),
                    title: context.tr(ref, 'logout'),
                    titleColor: AppColors.danger,
                    showChevron: false,
                    onTap: () => ref.read(authProvider.notifier).logout(),
                  ),
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 6, bottom: 10),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.outfit(
          color: AppColors.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
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
        imageFilter: ImageFilter.blur(sigmaX: 55, sigmaY: 55),
        child: Container(color: color),
      ),
    );
  }
}

// ─── Account Tile ──────────────────────────────────────────────────────────

class _AccountTile extends StatelessWidget {
  final AccountInfo acc;
  final bool isActive;
  final WidgetRef ref;

  const _AccountTile({required this.acc, required this.isActive, required this.ref});

  @override
  Widget build(BuildContext context) {
    final avatarChar = acc.username.isNotEmpty ? acc.username[0].toUpperCase() : '?';
    final hasCustomAvatar = acc.avatarUrl != null && acc.avatarUrl!.isNotEmpty;

    return _GlassTile(
      leading: Stack(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: isActive
                  ? const LinearGradient(
                      colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: isActive ? null : AppColors.bgHover,
              border: Border.all(
                color: isActive ? AppColors.accentBorder : AppColors.glassBorder,
                width: 1.5,
              ),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: AppColors.accentSecondary.withValues(alpha: 0.4),
                        blurRadius: 12,
                      )
                    ]
                  : null,
            ),
            child: ClipOval(
              child: hasCustomAvatar
                  ? Image.network(
                      acc.avatarUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Center(
                        child: Text(
                          avatarChar,
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    )
                  : Center(
                      child: Text(
                        avatarChar,
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w800,
                          color: isActive ? Colors.white : AppColors.textSecondary,
                          fontSize: 18,
                        ),
                      ),
                    ),
            ),
          ),
          if (isActive)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 13,
                height: 13,
                decoration: BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.bgSurface, width: 2),
                ),
              ),
            ),
        ],
      ),
      title: acc.displayName ?? acc.username,
      subtitle: isActive ? context.tr(ref, 'active') : context.tr(ref, 'switch_account_tap'),
      subtitleColor: isActive ? AppColors.success : null,
      onTap: () => context.push('/settings/profile?id=${acc.id}'),
    );
  }
}

// ─── Reusable Section Container ───────────────────────────────────────────────

class _GlassSection extends StatelessWidget {
  final List<Widget> children;
  const _GlassSection({required this.children});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.glassLight,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.glassBorder, width: 0.5),
          ),
          child: Column(children: children),
        ),
      ),
    );
  }
}

// ─── Glass Tile ───────────────────────────────────────────────────────────────

class _GlassTile extends StatelessWidget {
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Color? titleColor;
  final Color? subtitleColor;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showChevron;

  const _GlassTile({
    this.leading,
    required this.title,
    this.subtitle,
    this.titleColor,
    this.subtitleColor,
    this.trailing,
    this.onTap,
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      splashColor: AppColors.accent.withValues(alpha: 0.05),
      highlightColor: AppColors.glassLight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: titleColor ?? AppColors.textPrimary,
                    ),
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subtitle!,
                        style: GoogleFonts.inter(
                          color: subtitleColor ?? AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            trailing ?? (showChevron
                ? const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 20)
                : const SizedBox()),
          ],
        ),
      ),
    );
  }
}

// ─── Switch Tile ──────────────────────────────────────────────────────────────

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final LinearGradient iconGradient;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.icon,
    required this.iconGradient,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: iconGradient,
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

// ─── Divider ──────────────────────────────────────────────────────────────────

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 68),
      height: 0.5,
      color: AppColors.glassBorder,
    );
  }
}
