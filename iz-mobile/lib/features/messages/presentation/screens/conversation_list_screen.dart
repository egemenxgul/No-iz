import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iz_mobile/core/theme/app_colors.dart';
import 'package:iz_mobile/core/theme/glass_widgets.dart';
import 'package:iz_mobile/features/messages/providers/chat_provider.dart';
import 'package:iz_mobile/features/messages/providers/contacts_provider.dart';
import 'package:iz_mobile/features/auth/providers/auth_provider.dart';
import 'package:iz_mobile/features/notification/providers/notification_provider.dart';
import 'package:iz_mobile/features/story/presentation/screens/story_list_screen.dart';
import 'archived_conversations_screen.dart';

class ConversationListScreen extends StatefulWidget {
  const ConversationListScreen({super.key});

  @override
  State<ConversationListScreen> createState() => _ConversationListScreenState();
}

class _ConversationListScreenState extends State<ConversationListScreen> {
  int _selectedTab = 0; // 0: Sohbetler, 1: Mesaj İstekleri

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final conversations = ref.watch(conversationProvider);
        final myUserId = ref.watch(authProvider).userId ?? '';
        final notificationsState = ref.watch(notificationsProvider);
        final hasUnreadNotifications = notificationsState.valueOrNull?.any((n) => !n.isRead) ?? false;

        Future.microtask(() {
          ref.read(contactsProvider.notifier).syncContacts();
        });

        // Dynamic Filtering (excluding archived conversations)
        final activeChats = conversations.where((conv) {
          return !conv.isArchived && (conv.friendshipStatus == 'accepted' ||
                 conv.friendshipStatus == 'none' ||
                 (conv.friendshipStatus == 'pending' && conv.initiatorId == myUserId));
        }).toList();

        final messageRequests = conversations.where((conv) {
          return !conv.isArchived && conv.friendshipStatus == 'pending' && conv.initiatorId != myUserId;
        }).toList();

        final displayedList = _selectedTab == 0 ? activeChats : messageRequests;

        return Scaffold(
          backgroundColor: AppColors.bgBase,
          extendBodyBehindAppBar: true,
          body: Stack(
            children: [
              // ── Ambient gradient blobs ─────────────────────────────────────
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

              // ── Main scroll content ────────────────────────────────────────
              CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  _buildAppBar(context),
                  _buildSearchBox(context),
                  _buildShortcuts(context),
                  _buildTabs(context, messageRequests.length),
                  if (displayedList.isEmpty)
                    SliverFillRemaining(child: _buildEmptyState(context))
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final conv = displayedList[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _ConversationTile(conv: conv),
                            );
                          },
                          childCount: displayedList.length,
                         ),
                      ),
                    ),
                ],
              ),
            ],
          ),

          // ── Floating Action Button ─────────────────────────────────────────
          floatingActionButton: _GlassFAB(
            onPressed: () => context.push('/search'),
          ),
        );
      },
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      floating: true,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      expandedHeight: 100,
      collapsedHeight: 70,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
        title: Text(
          'Sohbetler',
          style: GoogleFonts.outfit(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.8,
          ),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8, top: 8),
          child: _GlassIconButton(
            icon: Icons.explore_outlined,
            onTap: () => context.push('/communities'),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 8, top: 8),
          child: _GlassIconButton(
            icon: Icons.people_outline_rounded,
            onTap: () => context.push('/social'),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 8, top: 8),
          child: _GlassIconButton(
            icon: Icons.notifications_none_rounded,
            onTap: () => context.push('/notifications'),
            badge: hasUnreadNotifications
                ? Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.accent,
                      ),
                    ),
                  )
                : null,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 16, top: 8),
          child: _GlassIconButton(
            icon: Icons.settings_outlined,
            onTap: () => context.push('/settings'),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBox(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.glassMedium,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.glassBorder, width: 0.5),
              ),
              child: TextField(
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Sohbetlerde ara...',
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted, size: 22),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  filled: false,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShortcuts(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const StoryListScreen()),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E38).withOpacity(0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.cyanAccent.withOpacity(0.15)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.camera_alt, color: Colors.cyanAccent, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Durumlar',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ArchivedConversationsScreen()),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E38).withOpacity(0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.purpleAccent.withOpacity(0.15)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.archive, color: Colors.purpleAccent, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Arşiv',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabs(BuildContext context, int requestCount) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.glassDark.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.glassBorder, width: 0.5),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _TabButton(
                      title: 'Sohbetler',
                      isActive: _selectedTab == 0,
                      onTap: () => setState(() => _selectedTab = 0),
                    ),
                  ),
                  Expanded(
                    child: _TabButton(
                      title: 'Mesaj İstekleri',
                      isActive: _selectedTab == 1,
                      badgeCount: requestCount,
                      onTap: () => setState(() => _selectedTab = 1),
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

  Widget _buildEmptyState(BuildContext context) {
    final isRequests = _selectedTab == 1;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GlassCard(
            padding: const EdgeInsets.all(28),
            borderRadius: 30,
            tintOpacity: 0.07,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppColors.accent.withValues(alpha: 0.3),
                    AppColors.accentSecondary.withValues(alpha: 0.2),
                  ],
                ),
              ),
              child: Icon(
                isRequests ? Icons.mark_email_unread_outlined : Icons.chat_bubble_outline_rounded,
                size: 44,
                color: AppColors.accentLight,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            isRequests ? 'Mesaj isteği yok' : 'Henüz mesajınız yok',
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isRequests ? 'Yeni istekler burada görünecektir.' : 'Yeni bir sohbet başlatmak için tıkla.',
            style: GoogleFonts.inter(
              color: AppColors.textSecondary,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String title;
  final bool isActive;
  final int badgeCount;
  final VoidCallback onTap;

  const _TabButton({
    required this.title,
    required this.isActive,
    this.badgeCount = 0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? AppColors.accent.withValues(alpha: 0.25) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isActive
              ? Border.all(color: AppColors.accentBorder.withValues(alpha: 0.5), width: 0.5)
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: GoogleFonts.inter(
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? AppColors.textPrimary : AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            if (badgeCount > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.4),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Text(
                  '$badgeCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Conversation Tile ────────────────────────────────────────────────────────

class _ConversationTile extends ConsumerWidget {
  final dynamic conv;
  const _ConversationTile({required this.conv});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contactsState = ref.watch(contactsProvider);

    String displayName = conv.otherDisplayName ?? conv.otherUsername;
    for (var contact in contactsState.localContacts) {
      if (contact.isActive && contact.userId == conv.otherUserId) {
        displayName = contact.name;
        break;
      }
    }

    final hasUnread = conv.unreadCount > 0;
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

    return Dismissible(
      key: Key(conv.id),
      background: Container(
        decoration: BoxDecoration(
          color: Colors.teal.withOpacity(0.8),
          borderRadius: BorderRadius.circular(22),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: Row(
          children: const [
            Icon(Icons.volume_off, color: Colors.white),
            SizedBox(width: 8),
            Text('Sessize Al / Aç', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      secondaryBackground: Container(
        decoration: BoxDecoration(
          color: Colors.purple.withOpacity(0.8),
          borderRadius: BorderRadius.circular(22),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: const [
            Text('Arşivle', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            SizedBox(width: 8),
            Icon(Icons.archive, color: Colors.white),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          // Archive
          await ref.read(conversationProvider.notifier).toggleArchive(conv.otherUserId);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${displayName} arşivlendi'),
              action: SnackBarAction(
                label: 'Geri Al',
                textColor: Colors.cyanAccent,
                onPressed: () {
                  ref.read(conversationProvider.notifier).toggleArchive(conv.otherUserId);
                },
              ),
            ),
          );
          return true;
        } else {
          // Mute
          await ref.read(conversationProvider.notifier).toggleMute(conv.otherUserId);
          final isMutedNow = !conv.isMuted;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${displayName} ${isMutedNow ? 'sessize alındı' : 'sesi açıldı'}'),
            ),
          );
          return false; // Do not dismiss from view
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => context.push('/app/messages/${conv.otherUserId}'),
              borderRadius: BorderRadius.circular(22),
              splashColor: AppColors.accent.withValues(alpha: 0.06),
              highlightColor: AppColors.glassLight,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: hasUnread
                      ? AppColors.accentDim.withValues(alpha: 0.25)
                      : AppColors.glassLight,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: hasUnread ? AppColors.accentBorder : AppColors.glassBorder,
                    width: 0.5,
                  ),
                ),
                child: Row(
                  children: [
                    // Avatar with status dot
                    Stack(
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: conv.isGroup
                                  ? [
                                      Colors.purpleAccent.withValues(alpha: 0.7),
                                      Colors.deepPurple.withValues(alpha: 0.6),
                                    ]
                                  : [
                                      AppColors.accent.withValues(alpha: 0.6),
                                      AppColors.accentSecondary.withValues(alpha: 0.5),
                                    ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: (conv.isGroup ? Colors.deepPurple : AppColors.accent).withValues(alpha: 0.25),
                                blurRadius: 12,
                                spreadRadius: 0,
                              ),
                            ],
                          ),
                          child: Center(
                            child: conv.isGroup
                                ? const Icon(Icons.group_rounded, color: Colors.white, size: 26)
                                : Text(
                                    initial,
                                    style: GoogleFonts.outfit(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 22,
                                    ),
                                  ),
                          ),
                        ),
                        if (!conv.isGroup && conv.isOnline)
                          Positioned(
                            right: 2,
                            bottom: 2,
                            child: Container(
                              width: 13,
                              height: 13,
                              decoration: BoxDecoration(
                                color: AppColors.success,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.bgBase, width: 2),
                              ),
                            ),
                          ),
                      ],
                    ),
 
                    const SizedBox(width: 14),
 
                    // Name & preview
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    displayName,
                                    style: GoogleFonts.inter(
                                      fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w600,
                                      fontSize: 16,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  if (conv.isMuted) ...[
                                    const SizedBox(width: 6),
                                    const Icon(Icons.volume_off, color: AppColors.textMuted, size: 16),
                                  ],
                                ],
                              ),
                              if (conv.lastMessageAt != null)
                                Text(
                                  _formatTime(conv.lastMessageAt),
                                  style: TextStyle(
                                    color: hasUnread ? AppColors.accentLight : AppColors.textMuted,
                                    fontSize: 12,
                                    fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  conv.lastMessage ?? 'Henüz mesaj yok',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: hasUnread
                                        ? AppColors.textPrimary
                                        : AppColors.textSecondary,
                                    fontSize: 14,
                                    fontWeight: hasUnread ? FontWeight.w500 : FontWeight.normal,
                                  ),
                                ),
                              ),
                              if (hasUnread) ...[
                                const SizedBox(width: 8),
                                Container(
                                  constraints: const BoxConstraints(minWidth: 22),
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [AppColors.accent, AppColors.accentSecondary],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.accent.withValues(alpha: 0.4),
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    '${conv.unreadCount}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
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

// ─── Supporting Widgets ───────────────────────────────────────────────────────

class _GlassFAB extends StatelessWidget {
  final VoidCallback onPressed;
  const _GlassFAB({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.accent, AppColors.accentSecondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.45),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(Icons.edit_note_rounded, color: Colors.white, size: 26),
          ),
        ),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Widget? badge;
  const _GlassIconButton({required this.icon, required this.onTap, this.badge});

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
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(icon, color: AppColors.textSecondary, size: 21),
                if (badge != null) badge!,
              ],
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
