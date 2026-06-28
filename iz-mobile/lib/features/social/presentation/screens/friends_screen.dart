// Copyright (c) 2026 Egemen GÜL (github.com/egemenxgul)
// Licensed under the GNU Affero General Public License v3.0 (AGPL-3.0)
// See LICENSE in the project root for license information.

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iz_mobile/core/theme/app_colors.dart';
import 'package:iz_mobile/core/theme/glass_widgets.dart';
import 'package:iz_mobile/core/localization/locale_provider.dart';
import 'package:iz_mobile/features/messages/providers/chat_provider.dart';
import 'package:iz_mobile/features/auth/providers/auth_provider.dart';
import 'package:iz_mobile/features/messages/providers/message_model.dart';

class FriendsScreen extends ConsumerWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversations = ref.watch(conversationProvider);
    final myUserId = ref.watch(authProvider).userId ?? '';

    // Filter conversations for the three tabs
    final friendsList = conversations.where((c) {
      return !c.isGroup && c.friendshipStatus == 'accepted';
    }).toList();

    final requestsList = conversations.where((c) {
      return !c.isGroup && c.friendshipStatus == 'pending' && c.initiatorId != myUserId;
    }).toList();

    final blockedList = conversations.where((c) {
      return !c.isGroup && c.friendshipStatus == 'blocked';
    }).toList();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.bgBase,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: Text(
            context.tr(ref, 'social_hub'),
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: IconButton(
                icon: const Icon(Icons.person_add_alt_1_rounded, color: AppColors.accent, size: 24),
                onPressed: () => context.push('/search'),
              ),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(50),
            child: ClipRRect(
              child: AppBackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.glassDark.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.glassBorder, width: 0.5),
                  ),
                  child: TabBar(
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    indicator: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.accentBorder.withValues(alpha: 0.4),
                        width: 0.5,
                      ),
                    ),
                    labelColor: AppColors.textPrimary,
                    unselectedLabelColor: AppColors.textSecondary,
                    labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
                    unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 13),
                    tabs: [
                      Tab(text: '${context.tr(ref, 'friends')} (${friendsList.length})'),
                      Tab(text: '${context.tr(ref, 'requests')} (${requestsList.length})'),
                      Tab(text: '${context.tr(ref, 'blocked')} (${blockedList.length})'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        body: Stack(
          children: [
            // ── Background Ambient Blobs ──────────────────────────────────────
            Positioned(
              top: -60,
              left: -40,
              child: _AmbientBlob(
                color: AppColors.accent.withValues(alpha: 0.15),
                size: 300,
              ),
            ),
            Positioned(
              bottom: -60,
              right: -40,
              child: _AmbientBlob(
                color: AppColors.accentSecondary.withValues(alpha: 0.1),
                size: 280,
              ),
            ),

            // ── Tab Views ───────────────────────────────────────────────────
            TabBarView(
              physics: const BouncingScrollPhysics(),
              children: [
                _FriendsListTab(friends: friendsList),
                _RequestsListTab(requests: requestsList),
                _BlockedListTab(blocked: blockedList),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FriendsListTab extends ConsumerWidget {
  final List<ConversationModel> friends;
  const _FriendsListTab({required this.friends});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      color: Colors.white,
      backgroundColor: AppColors.glassLight,
      onRefresh: () async {
        await ref.read(conversationProvider.notifier).loadConversations();
      },
      child: friends.isEmpty
          ? LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(16, 150, 16, 80),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 230,
                  ),
                  child: Center(
                    child: _buildEmptyState(
                      context,
                      ref,
                      icon: Icons.people_outline_rounded,
                      titleKey: 'no_friends_yet',
                    ),
                  ),
                ),
              ),
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(16, 150, 16, 80),
              itemCount: friends.length,
              itemBuilder: (context, index) {
                final item = friends[index];
                final name = item.otherDisplayName?.isNotEmpty == true ? item.otherDisplayName! : item.otherUsername;
                final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GlassCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        // Avatar with online status
                        Stack(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.accent.withValues(alpha: 0.6),
                                    AppColors.accentSecondary.withValues(alpha: 0.5),
                                  ],
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  initial,
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                            if (item.isOnline)
                              Positioned(
                                right: 1,
                                bottom: 1,
                                child: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: AppColors.success,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: AppColors.bgSurface, width: 2),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 14),

                        // Name & Username
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: GoogleFonts.inter(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '@${item.otherUsername}',
                                style: GoogleFonts.inter(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Action Buttons
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Chat button
                            _GlassActionButton(
                              icon: Icons.chat_bubble_outline_rounded,
                              color: AppColors.accent,
                              onTap: () {
                                context.push('/app/messages/${item.otherUserId}');
                              },
                            ),
                            const SizedBox(width: 8),
                            // More options (Block)
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert_rounded, color: AppColors.textSecondary),
                              color: AppColors.bgElevated,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              onSelected: (value) async {
                                if (value == 'block') {
                                  final confirm = await _showBlockConfirmDialog(context, ref, name);
                                  if (confirm == true) {
                                    await ref.read(chatProvider(item.otherUserId).notifier).blockUser();
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(context.tr(ref, 'user_blocked'))),
                                      );
                                    }
                                  }
                                }
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'block',
                                  child: Row(
                                    children: [
                                      const Icon(Icons.block_flipped, color: AppColors.danger, size: 18),
                                      const SizedBox(width: 8),
                                      Text(
                                        context.tr(ref, 'block'),
                                        style: GoogleFonts.inter(color: AppColors.danger, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _RequestsListTab extends ConsumerWidget {
  final List<ConversationModel> requests;
  const _RequestsListTab({required this.requests});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      color: Colors.white,
      backgroundColor: AppColors.glassLight,
      onRefresh: () async {
        await ref.read(conversationProvider.notifier).loadConversations();
      },
      child: requests.isEmpty
          ? LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(16, 150, 16, 80),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 230,
                  ),
                  child: Center(
                    child: _buildEmptyState(
                      context,
                      ref,
                      icon: Icons.mark_email_unread_outlined,
                      titleKey: 'no_requests_yet',
                    ),
                  ),
                ),
              ),
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(16, 150, 16, 80),
              itemCount: requests.length,
              itemBuilder: (context, index) {
                final item = requests[index];
                final name = item.otherDisplayName?.isNotEmpty == true ? item.otherDisplayName! : item.otherUsername;
                final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GlassCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: AppColors.accentDim,
                          child: Text(
                            initial,
                            style: GoogleFonts.outfit(
                              color: AppColors.accentLight,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: GoogleFonts.inter(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '@${item.otherUsername}',
                                style: GoogleFonts.inter(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),

                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Accept request
                            _TextActionButton(
                              text: context.tr(ref, 'accept'),
                              textColor: AppColors.success,
                              backgroundColor: AppColors.success.withValues(alpha: 0.15),
                              borderColor: AppColors.success.withValues(alpha: 0.3),
                              onTap: () async {
                                await ref.read(chatProvider(item.otherUserId).notifier).acceptRequest();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(context.tr(ref, 'friendship_accepted'))),
                                  );
                                }
                              },
                            ),
                            const SizedBox(width: 8),
                            // Reject request
                            _TextActionButton(
                              text: context.tr(ref, 'reject'),
                              textColor: AppColors.danger,
                              backgroundColor: AppColors.danger.withValues(alpha: 0.15),
                              borderColor: AppColors.danger.withValues(alpha: 0.3),
                              onTap: () async {
                                await ref.read(chatProvider(item.otherUserId).notifier).rejectRequest();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(context.tr(ref, 'friendship_rejected'))),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _BlockedListTab extends ConsumerWidget {
  final List<ConversationModel> blocked;
  const _BlockedListTab({required this.blocked});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      color: Colors.white,
      backgroundColor: AppColors.glassLight,
      onRefresh: () async {
        await ref.read(conversationProvider.notifier).loadConversations();
      },
      child: blocked.isEmpty
          ? LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(16, 150, 16, 80),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 230,
                  ),
                  child: Center(
                    child: _buildEmptyState(
                      context,
                      ref,
                      icon: Icons.block_rounded,
                      titleKey: 'no_blocked_yet',
                    ),
                  ),
                ),
              ),
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(16, 150, 16, 80),
              itemCount: blocked.length,
              itemBuilder: (context, index) {
                final item = blocked[index];
                final name = item.otherDisplayName?.isNotEmpty == true ? item.otherDisplayName! : item.otherUsername;
                final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GlassCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: AppColors.bgHover,
                          child: Text(
                            initial,
                            style: GoogleFonts.outfit(
                              color: AppColors.textSecondary,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: GoogleFonts.inter(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '@${item.otherUsername}',
                                style: GoogleFonts.inter(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Unblock Button
                        _TextActionButton(
                          text: context.tr(ref, 'unblock'),
                          textColor: AppColors.textPrimary,
                          backgroundColor: AppColors.accent.withValues(alpha: 0.25),
                          borderColor: AppColors.accentBorder,
                          onTap: () async {
                            await ref.read(chatProvider(item.otherUserId).notifier).unblockUser();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(context.tr(ref, 'user_unblocked'))),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// ─── Helper Widgets ──────────────────────────────────────────────────────────

Widget _buildEmptyState(BuildContext context, WidgetRef ref, {required IconData icon, required String titleKey}) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GlassCard(
          padding: const EdgeInsets.all(28),
          borderRadius: 30,
          tintOpacity: 0.05,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  AppColors.accent.withValues(alpha: 0.25),
                  AppColors.accentSecondary.withValues(alpha: 0.15),
                ],
              ),
            ),
            child: Icon(
              icon,
              size: 40,
              color: AppColors.accentLight,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          context.tr(ref, titleKey),
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
      ],
    ),
  );
}

Future<bool?> _showBlockConfirmDialog(BuildContext context, WidgetRef ref, String name) {
  return showDialog<bool>(
    context: context,
    builder: (context) {
      return AppBackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: AppColors.bgElevated,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: AppColors.glassBorder, width: 0.5)),
          title: Text(
            context.tr(ref, 'block'),
            style: GoogleFonts.outfit(color: AppColors.textPrimary, fontWeight: FontWeight.w800),
          ),
          content: Text(
            '$name kullanıcısını engellemek istediğinize emin misiniz? Bu işlemden sonra size mesaj gönderemez.',
            style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Vazgeç',
                style: GoogleFonts.inter(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                context.tr(ref, 'block'),
                style: GoogleFonts.inter(color: AppColors.danger, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _GlassActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _GlassActionButton({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }
}

class _TextActionButton extends StatelessWidget {
  final String text;
  final Color textColor;
  final Color backgroundColor;
  final Color borderColor;
  final VoidCallback onTap;

  const _TextActionButton({
    required this.text,
    required this.textColor,
    required this.backgroundColor,
    required this.borderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 0.5),
        ),
        child: Text(
          text,
          style: GoogleFonts.inter(
            color: textColor,
            fontWeight: FontWeight.w700,
            fontSize: 12,
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
