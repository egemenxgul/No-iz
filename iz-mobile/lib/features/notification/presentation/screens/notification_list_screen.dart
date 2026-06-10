import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iz_mobile/core/theme/app_colors.dart';
import 'package:iz_mobile/core/theme/glass_widgets.dart';
import '../models/notification_model.dart';
import '../providers/notification_provider.dart';

class NotificationListScreen extends ConsumerWidget {
  const NotificationListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsState = ref.watch(notificationsProvider);

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // ── Ambient background blobs ────────────────────────────────────
          Positioned(
            top: -80,
            right: -60,
            child: _AmbientBlob(
              color: AppColors.accent.withValues(alpha: 0.18),
              size: 280,
            ),
          ),
          Positioned(
            bottom: 120,
            left: -80,
            child: _AmbientBlob(
              color: AppColors.accentSecondary.withValues(alpha: 0.12),
              size: 240,
            ),
          ),

          // ── Scroll Content ──────────────────────────────────────────────
          RefreshIndicator(
            color: Colors.white,
            backgroundColor: AppColors.glassLight,
            onRefresh: () async {
              await ref.read(notificationsProvider.notifier).refreshNotifications();
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                _buildAppBar(context, ref, notificationsState),
                notificationsState.when(
                  data: (notifications) {
                    if (notifications.isEmpty) {
                      return SliverFillRemaining(
                        hasScrollBody: false,
                        child: _buildEmptyState(context),
                      );
                    }
                    return SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final notification = notifications[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _NotificationTile(notification: notification),
                            );
                          },
                          childCount: notifications.length,
                        ),
                      ),
                    );
                  },
                  loading: () => const SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  ),
                  error: (err, stack) => SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: Colors.redAccent,
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Yükleme hatası oluştu',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            err.toString(),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              ref.read(notificationsProvider.notifier).refreshNotifications();
                            },
                            child: const Text('Tekrar Dene'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<NotificationModel>> notificationsState,
  ) {
    final hasUnread = notificationsState.valueOrNull?.any((n) => !n.isRead) ?? false;

    return SliverAppBar(
      floating: true,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      expandedHeight: 110,
      collapsedHeight: 75,
      leading: Padding(
        padding: const EdgeInsets.only(left: 16, top: 12),
        child: Align(
          alignment: Alignment.centerLeft,
          child: _GlassIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => context.pop(),
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 72, bottom: 18),
        title: Text(
          'Bildirimler',
          style: GoogleFonts.outfit(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.6,
          ),
        ),
      ),
      actions: [
        if (hasUnread)
          Padding(
            padding: const EdgeInsets.only(right: 16, top: 12),
            child: Align(
              alignment: Alignment.centerRight,
              child: _GlassTextButton(
                label: 'Hepsini Okundu Yap',
                onPressed: () async {
                  try {
                    await ref.read(notificationsProvider.notifier).markAllAsRead();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Hata: $e')),
                    );
                  }
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.glassMedium,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.glassBorder, width: 0.5),
              ),
              child: Icon(
                Icons.notifications_none_rounded,
                color: AppColors.textSecondary.withValues(alpha: 0.5),
                size: 64,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Her şey temiz!',
          style: GoogleFonts.outfit(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Text(
            'Herhangi bir yeni bildiriminiz yok. Bildirimler geldiğinde burada görünecekler.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  final NotificationModel notification;

  const _NotificationTile({required this.notification});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) async {
        try {
          await ref.read(notificationsProvider.notifier).delete(notification.id);
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Silme başarısız oldu: $e')),
          );
        }
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: Colors.redAccent.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4), width: 0.5),
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: Colors.redAccent,
          size: 28,
        ),
      ),
      child: GestureDetector(
        onTap: () {
          if (!notification.isRead) {
            ref.read(notificationsProvider.notifier).markAsRead(notification.id);
          }
        },
        child: GlassCard(
          borderRadius: 22,
          tintOpacity: notification.isRead ? 0.04 : 0.08,
          tintColor: notification.isRead ? Colors.white : AppColors.accent,
          border: Border.all(
            color: notification.isRead 
                ? AppColors.glassBorder 
                : AppColors.accent.withValues(alpha: 0.3),
            width: 0.5,
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Unread Dot or Icon ──────────────────────────────────────
              Container(
                margin: const EdgeInsets.only(top: 4, right: 12),
                width: 12,
                height: 12,
                child: Center(
                  child: Container(
                    width: notification.isRead ? 4 : 10,
                    height: notification.isRead ? 4 : 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: notification.isRead
                          ? AppColors.textSecondary.withValues(alpha: 0.3)
                          : AppColors.accent,
                      boxShadow: notification.isRead
                          ? null
                          : [
                              BoxShadow(
                                color: AppColors.accent.withValues(alpha: 0.4),
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                            ],
                    ),
                  ),
                ),
              ),

              // ── Text Content ────────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: notification.isRead 
                                  ? AppColors.textPrimary.withValues(alpha: 0.8)
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatTime(notification.createdAt),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.textSecondary.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      notification.body,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: notification.isRead 
                            ? AppColors.textSecondary
                            : AppColors.textPrimary.withValues(alpha: 0.9),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
    return '${date.day}/${date.month}';
  }
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GlassIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.glassMedium,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.glassBorder, width: 0.5),
            ),
            child: Icon(icon, color: AppColors.textPrimary, size: 20),
          ),
        ),
      ),
    );
  }
}

class _GlassTextButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _GlassTextButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.glassLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.glassBorder, width: 0.5),
            ),
            child: Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.accent,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AmbientBlob extends StatelessWidget {
  final Color color;
  final double size;

  const _AmbientBlob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
        child: Container(color: color),
      ),
    );
  }
}
