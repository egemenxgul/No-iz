import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iz_mobile/core/theme/app_colors.dart';
import 'package:iz_mobile/core/network/dio_provider.dart';
import 'package:iz_mobile/core/localization/locale_provider.dart';
import 'package:iz_mobile/features/auth/presentation/widgets/change_password_dialog.dart';
import 'package:iz_mobile/features/auth/presentation/widgets/two_fa_setup_dialog.dart';
import 'package:iz_mobile/features/auth/presentation/widgets/export_data_dialog.dart';
import 'package:iz_mobile/features/auth/presentation/widgets/delete_account_dialog.dart';

class PrivacySettingsScreen extends ConsumerStatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  ConsumerState<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends ConsumerState<PrivacySettingsScreen> {
  bool _isLoading = true;
  bool _hideLastSeen = false;
  bool _hideOnline = false;
  bool _hideTyping = false;
  bool _hideReadReceipts = false;

  @override
  void initState() {
    super.initState();
    _fetchPrivacySettings();
  }

  Future<void> _fetchPrivacySettings() async {
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get('/api/users/privacy');
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        setState(() {
          _hideLastSeen = data['hide_last_seen'] ?? false;
          _hideOnline = data['hide_online'] ?? false;
          _hideTyping = data['hide_typing'] ?? false;
          _hideReadReceipts = data['hide_read_receipts'] ?? false;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr(ref, 'error_occurred')),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _updateSetting(String key, bool value, {required VoidCallback rollback}) async {
    // Optimistic UI update is already handled by switches calling setState,
    // we just perform the server call.
    try {
      final dio = ref.read(dioProvider);
      final payload = {
        'hide_last_seen': _hideLastSeen,
        'hide_online': _hideOnline,
        'hide_typing': _hideTyping,
        'hide_read_receipts': _hideReadReceipts,
      };
      await dio.put('/api/users/privacy', data: payload);
    } catch (e) {
      rollback();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr(ref, 'error_occurred')),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          context.tr(ref, 'privacy_security'),
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
          // Background blobs
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

          _isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 110, 16, 40),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _sectionTitle(context.tr(ref, 'privacy_security')),
                    _GlassSection(
                      children: [
                        _SwitchTile(
                          icon: Icons.visibility_off_outlined,
                          iconGradient: const LinearGradient(
                            colors: [Color(0xFFF59E0B), Color(0xFFF97316)],
                          ),
                          title: context.tr(ref, 'hide_last_seen'),
                          subtitle: context.tr(ref, 'hide_last_seen_sub'),
                          value: _hideLastSeen,
                          onChanged: (v) {
                            setState(() => _hideLastSeen = v);
                            _updateSetting('hide_last_seen', v, rollback: () {
                              setState(() => _hideLastSeen = !v);
                            });
                          },
                        ),
                        const _Divider(),
                        _SwitchTile(
                          icon: Icons.ring_volume_outlined,
                          iconGradient: const LinearGradient(
                            colors: [Color(0xFF3B82F6), Color(0xFF06B6D4)],
                          ),
                          title: context.tr(ref, 'hide_online'),
                          subtitle: context.tr(ref, 'hide_online_sub'),
                          value: _hideOnline,
                          onChanged: (v) {
                            setState(() => _hideOnline = v);
                            _updateSetting('hide_online', v, rollback: () {
                              setState(() => _hideOnline = !v);
                            });
                          },
                        ),
                        const _Divider(),
                        _SwitchTile(
                          icon: Icons.edit_note_outlined,
                          iconGradient: const LinearGradient(
                            colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                          ),
                          title: context.tr(ref, 'hide_typing'),
                          subtitle: context.tr(ref, 'hide_typing_sub'),
                          value: _hideTyping,
                          onChanged: (v) {
                            setState(() => _hideTyping = v);
                            _updateSetting('hide_typing', v, rollback: () {
                              setState(() => _hideTyping = !v);
                            });
                          },
                        ),
                        const _Divider(),
                        _SwitchTile(
                          icon: Icons.done_all_rounded,
                          iconGradient: const LinearGradient(
                            colors: [Color(0xFF10B981), Color(0xFF34D399)],
                          ),
                          title: context.tr(ref, 'hide_read'),
                          subtitle: context.tr(ref, 'hide_read_sub'),
                          value: _hideReadReceipts,
                          onChanged: (v) {
                            setState(() => _hideReadReceipts = v);
                            _updateSetting('hide_read_receipts', v, rollback: () {
                              setState(() => _hideReadReceipts = !v);
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    _sectionTitle(context.tr(ref, 'account_security')),
                    _GlassSection(
                      children: [
                        _GlassTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
                              ),
                            ),
                            child: const Icon(Icons.password_outlined, color: Colors.white, size: 20),
                          ),
                          title: context.tr(ref, 'change_password'),
                          subtitle: context.tr(ref, 'change_password_sub'),
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (_) => const ChangePasswordDialog(),
                            );
                          },
                        ),
                        const _Divider(),
                        _GlassTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                              ),
                            ),
                            child: const Icon(Icons.security, color: Colors.white, size: 20),
                          ),
                          title: "İki Aşamalı Doğrulama (2FA)",
                          subtitle: "Hesabınızı Google Authenticator ile koruyun.",
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (_) => const TwoFASetupDialog(),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    _sectionTitle("Veri Yönetimi (GDPR)"),
                    _GlassSection(
                      children: [
                        _GlassTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [Color(0xFF10B981), Color(0xFF059669)],
                              ),
                            ),
                            child: const Icon(Icons.download, color: Colors.white, size: 20),
                          ),
                          title: "Verilerimi İndir",
                          subtitle: "Sistemdeki tüm kişisel verilerinizi JSON olarak dışa aktarın.",
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (_) => const ExportDataDialog(),
                            );
                          },
                        ),
                        const _Divider(),
                        _GlassTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                              ),
                            ),
                            child: const Icon(Icons.delete_forever, color: Colors.white, size: 20),
                          ),
                          title: "Hesabımı Sil",
                          subtitle: "Tüm verilerinizi siler ve sizi sistemden tamamen anonimleştirir.",
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (_) => const DeleteAccountDialog(),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        context.tr(ref, 'privacy_mutuality_note'),
                        style: GoogleFonts.inter(
                          color: AppColors.textMuted,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
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
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.accent,
            activeTrackColor: AppColors.accentDim,
          ),
        ],
      ),
    );
  }
}

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

class _GlassTile extends StatelessWidget {
  final Widget? leading;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  const _GlassTile({
    this.leading,
    required this.title,
    this.subtitle,
    this.onTap,
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
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subtitle!,
                        style: GoogleFonts.inter(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}

