import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iz_mobile/core/theme/app_colors.dart';
import 'package:iz_mobile/core/theme/glass_widgets.dart';
import 'package:iz_mobile/features/messages/providers/chat_provider.dart';
import 'package:iz_mobile/features/messages/providers/contacts_provider.dart';
import 'package:iz_mobile/features/auth/providers/auth_provider.dart';
import 'package:iz_mobile/features/notification/providers/notification_provider.dart';
import 'package:iz_mobile/features/story/presentation/screens/story_viewer_screen.dart';
import 'package:iz_mobile/features/story/presentation/screens/create_story_screen.dart';
import 'package:iz_mobile/features/story/providers/story_provider.dart';
import 'package:iz_mobile/features/story/models/story_model.dart';

class ConversationListScreen extends StatefulWidget {
  const ConversationListScreen({super.key});

  @override
  State<ConversationListScreen> createState() => _ConversationListScreenState();
}

class _ConversationListScreenState extends State<ConversationListScreen>
    with SingleTickerProviderStateMixin {
  int _selectedTab = 0;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();

    // Full edge-to-edge
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ));
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final conversations = ref.watch(conversationProvider);
        final myUserId = ref.watch(authProvider).userId ?? '';
        final notificationsState = ref.watch(notificationsProvider);
        final hasUnreadNotifications =
            notificationsState.valueOrNull?.any((n) => !n.isRead) ?? false;
        final storyFeed = ref.watch(storyProvider);

        Future.microtask(() {
          ref.read(contactsProvider.notifier).syncContacts();
        });

        final activeChats = conversations.where((conv) {
          return !conv.isArchived &&
              (conv.friendshipStatus == 'accepted' ||
                  conv.friendshipStatus == 'none' ||
                  (conv.friendshipStatus == 'pending' &&
                      conv.initiatorId == myUserId));
        }).toList();

        final messageRequests = conversations.where((conv) {
          return !conv.isArchived &&
              conv.friendshipStatus == 'pending' &&
              conv.initiatorId != myUserId;
        }).toList();

        final displayedList =
            _selectedTab == 0 ? activeChats : messageRequests;

        return Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: true,
          extendBody: true,
          body: Container(
            decoration: const BoxDecoration(
              gradient: AppColors.backgroundGradient,
            ),
            child: Stack(
              children: [
                // ── Ambient light blobs ──────────────────────────────────
                Positioned(
                  top: -100,
                  right: -80,
                  child: LiquidAmbientBlob(
                    color: AppColors.accent.withValues(alpha: 0.15),
                    size: 340,
                    blur: 70,
                  ),
                ),
                Positioned(
                  top: 200,
                  left: -100,
                  child: LiquidAmbientBlob(
                    color: AppColors.accentSecondary.withValues(alpha: 0.10),
                    size: 280,
                    blur: 65,
                  ),
                ),
                Positioned(
                  bottom: 160,
                  right: -60,
                  child: LiquidAmbientBlob(
                    color: const Color(0xFF06B6D4).withValues(alpha: 0.06),
                    size: 220,
                    blur: 60,
                  ),
                ),

                // ── Main scroll ────────────────────────────────────────
                FadeTransition(
                  opacity: _fadeAnim,
                  child: RefreshIndicator(
                    color: AppColors.accent,
                    backgroundColor: AppColors.bgElevated,
                    onRefresh: () async {
                      await Future.delayed(const Duration(milliseconds: 600));
                    },
                    child: CustomScrollView(
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      slivers: [
                        _LiquidSliverAppBar(
                          hasUnreadNotifications: hasUnreadNotifications,
                        ),
                        // ── Story halkaları ─────────────────────────────
                        if (storyFeed.isNotEmpty)
                          _buildStoryRings(context, storyFeed, myUserId),
                        _buildSearchBar(context),

                        _buildTabBar(messageRequests.length),
                        if (displayedList.isEmpty)
                          SliverFillRemaining(
                            child: _EmptyStateView(isRequests: _selectedTab == 1),
                          )
                        else

                        if (_selectedTab == 0) // Only in 'Tümü'
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              child: GestureDetector(
                                onTap: () => context.push('/archived'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: AppColors.bgHover,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.archive_outlined, color: AppColors.textSecondary, size: 22),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Arşivlenmiş Sohbetler',
                                        style: GoogleFonts.inter(
                                          color: AppColors.textPrimary,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const Spacer(),
                                      const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 20),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 6, 16, 120),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, i) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _ConversationTile(conv: displayedList[i]),
                                ),
                                childCount: displayedList.length,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          floatingActionButton: LiquidFAB(
            onTap: () => context.push('/search'),
          ),
        );
      },
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: AppBackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0x22FFFFFF), Color(0x0EFFFFFF)],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.glassBorderStrong, width: 0.6),
              ),
              child: Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 16),
                    child: Icon(Icons.search_rounded, color: AppColors.textMuted, size: 20),
                  ),
                  Expanded(
                    child: TextField(
                      style: GoogleFonts.inter(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Sohbetlerde ara...',
                        hintStyle: GoogleFonts.inter(
                          color: AppColors.textMuted,
                          fontSize: 15,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 15,
                        ),
                        filled: false,
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


  /// Story halkaları — yatay kaydırmalı avatar çemberleri
  Widget _buildStoryRings(
    BuildContext context,
    List<FriendStoryFeedModel> feed,
    String myUserId,
  ) {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 100,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: feed.length + 1, // +1 for own story button
          itemBuilder: (context, index) {
            if (index == 0) {
              // Kendi hikaye ekleme butonu
              return _StoryRingItem(
                label: 'Hikayem',
                avatarUrl: null,
                isOwn: true,
                hasStory: feed.any((f) => f.userId == myUserId),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateStoryScreen()),
                ),
              );
            }
            final feedItem = feed[index - 1];
            return _StoryRingItem(
              label: feedItem.displayName.isNotEmpty
                  ? feedItem.displayName
                  : feedItem.username,
              avatarUrl: feedItem.avatarUrl.isNotEmpty ? feedItem.avatarUrl : null,
              isOwn: false,
              hasStory: feedItem.stories.isNotEmpty,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StoryViewerScreen(feedItem: feedItem),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTabBar(int requestCount) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: LiquidPillTab(
          tabs: const ['Sohbetler', 'İstekler'],
          selectedIndex: _selectedTab,
          badgeCount: (i) => i == 1 ? requestCount : 0,
          onChanged: (i) => setState(() => _selectedTab = i),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Liquid Sliver App Bar
// ─────────────────────────────────────────────────────────────────────────────
class _LiquidSliverAppBar extends ConsumerWidget {
  final bool hasUnreadNotifications;
  const _LiquidSliverAppBar({required this.hasUnreadNotifications});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final top = MediaQuery.of(context).padding.top;

    return SliverPersistentHeader(
      floating: true,
      delegate: _LiquidAppBarDelegate(
        hasUnreadNotifications: hasUnreadNotifications,
        topPadding: top,
      ),
    );
  }
}

class _LiquidAppBarDelegate extends SliverPersistentHeaderDelegate {
  final bool hasUnreadNotifications;
  final double topPadding;

  _LiquidAppBarDelegate({
    required this.hasUnreadNotifications,
    required this.topPadding,
  });

  @override
  double get minExtent => topPadding + 62;
  @override
  double get maxExtent => topPadding + 110;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final progress = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);
    final titleScale = 1.0 - (progress * 0.28);
    final titleOpacity = 1.0 - (progress * 0.5);
    final blurAmount = progress * 28.0;

    return Stack(
      children: [
        // Frosted glass backdrop when collapsed
        if (blurAmount > 0)
          Positioned.fill(
            child: ClipRect(
              child: AppBackdropFilter(
                filter: ImageFilter.blur(sigmaX: blurAmount, sigmaY: blurAmount),
                child: Container(
                  color: AppColors.bgBase.withValues(alpha: progress * 0.65),
                ),
              ),
            ),
          ),

        // Bottom border when scrolled
        if (progress > 0.5)
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              height: 0.5,
              color: AppColors.glassBorder.withValues(alpha: (progress - 0.5) * 2),
            ),
          ),

        Padding(
          padding: EdgeInsets.only(top: topPadding),
          child: SizedBox(
            height: maxExtent - topPadding,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Title
                  Expanded(
                    child: Transform.scale(
                      scale: titleScale,
                      alignment: Alignment.centerLeft,
                      child: Opacity(
                        opacity: titleOpacity.clamp(0.0, 1.0),
                        child: Text(
                          'iz',
                          style: GoogleFonts.outfit(
                            fontSize: 38,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                            letterSpacing: -1.5,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Action buttons
                  Row(
                    children: [
                      LiquidIconButton(
                        icon: Icons.qr_code_scanner_rounded,
                        onTap: () => context.push('/qr-scanner'),
                      ),
                      const SizedBox(width: 8),
                      LiquidIconButton(
                        icon: Icons.notifications_none_rounded,
                        onTap: () => context.push('/notifications'),
                        glow: hasUnreadNotifications,
                        badge: hasUnreadNotifications
                            ? Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.accent,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.accent.withValues(alpha: 0.6),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : null,
                      ),

                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  bool shouldRebuild(covariant _LiquidAppBarDelegate old) =>
      old.hasUnreadNotifications != hasUnreadNotifications ||
      old.topPadding != topPadding;
}

// ─────────────────────────────────────────────────────────────────────────────
// Shortcut Chip
// ─────────────────────────────────────────────────────────────────────────────
class _ShortcutChip extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color iconColor;
  final LinearGradient gradient;
  final VoidCallback onTap;

  const _ShortcutChip({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.gradient,
    required this.onTap,
  });

  @override
  State<_ShortcutChip> createState() => _ShortcutChipState();
}

class _ShortcutChipState extends State<_ShortcutChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween<double>(begin: 1.0, end: 0.93).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) => _ctrl.reverse(),
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (ctx, child) => Transform.scale(scale: _scale.value, child: child),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: AppBackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0x20FFFFFF), Color(0x0CFFFFFF)],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppColors.glassBorderStrong,
                      width: 0.6,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          gradient: widget.gradient,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(widget.icon, color: Colors.white, size: 14),
                      ),
                      const SizedBox(width: 9),
                      Text(
                        widget.label,
                        style: GoogleFonts.inter(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Specular top
            Positioned(
              top: 0, left: 8, right: 8,
              child: Container(
                height: 0.7,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.transparent, AppColors.specularTop, Colors.transparent],
                  ),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty State
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyStateView extends StatelessWidget {
  final bool isRequests;
  const _EmptyStateView({required this.isRequests});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          LiquidGlassCard(
            padding: const EdgeInsets.all(26),
            borderRadius: 32,
            tintOpacity: 0.06,
            showPrismatic: true,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppColors.accent.withValues(alpha: 0.28),
                    AppColors.accentSecondary.withValues(alpha: 0.18),
                  ],
                ),
              ),
              child: Icon(
                isRequests
                    ? Icons.mark_email_unread_outlined
                    : Icons.chat_bubble_outline_rounded,
                size: 42,
                color: AppColors.accentGlow,
              ),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            isRequests ? 'Mesaj isteği yok' : 'Henüz sohbet yok',
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isRequests
                ? 'Yeni istekler burada görünecektir.'
                : 'Yeni bir sohbet başlatmak için + tıkla.',
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

// ─────────────────────────────────────────────────────────────────────────────
// Conversation Tile — Liquid Glass
// ─────────────────────────────────────────────────────────────────────────────
class _ConversationTile extends ConsumerStatefulWidget {
  final dynamic conv;
  const _ConversationTile({required this.conv});

  @override
  ConsumerState<_ConversationTile> createState() => _ConversationTileState();
}

class _ConversationTileState extends ConsumerState<_ConversationTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressCtrl;
  late Animation<double> _pressScale;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _pressScale = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final conv = widget.conv;
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

    return AnimatedBuilder(
      animation: _pressCtrl,
      builder: (ctx, child) => Transform.scale(scale: _pressScale.value, child: child),
      child: Dismissible(
        key: Key(conv.id),
        background: _DismissBackground(
          icon: Icons.volume_off_rounded,
          label: conv.isMuted ? 'Sesi Aç' : 'Sessize Al',
          color: const Color(0xFF0891B2),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 22),
        ),
        secondaryBackground: const _DismissBackground(
          icon: Icons.archive_outlined,
          label: 'Arşivle',
          color: Color(0xFF7C3AED),
          alignment: Alignment.centerRight,
          padding: EdgeInsets.only(right: 22),
        ),
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.endToStart) {
            await ref.read(conversationProvider.notifier).toggleArchive(conv.otherUserId);
            if (context.mounted) {
              _showLiquidSnackbar(context, '$displayName arşivlendi', () {
                ref.read(conversationProvider.notifier).toggleArchive(conv.otherUserId);
              });
            }
            return true;
          } else {
            await ref.read(conversationProvider.notifier).toggleMute(conv.otherUserId);
            final isMutedNow = !conv.isMuted;
            if (context.mounted) {
              _showLiquidSnackbar(
                context,
                '$displayName ${isMutedNow ? 'sessize alındı' : 'sesi açıldı'}',
                null,
              );
            }
            return false;
          }
        },
        child: GestureDetector(
          onTapDown: (_) {
            HapticFeedback.selectionClick();
            _pressCtrl.forward();
          },
          onTapUp: (_) {
            _pressCtrl.reverse();
            context.push('/app/messages/${conv.otherUserId}');
          },
          onTapCancel: () => _pressCtrl.reverse(),
          child: Stack(
            children: [
              // Glass tile body
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: AppBackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: hasUnread
                          ? LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppColors.accent.withValues(alpha: 0.16),
                                AppColors.accentSecondary.withValues(alpha: 0.08),
                              ],
                            )
                          : const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0x1AFFFFFF),
                                Color(0x08FFFFFF),
                              ],
                            ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: hasUnread
                            ? AppColors.accentBorder.withValues(alpha: 0.6)
                            : AppColors.glassBorder,
                        width: 0.6,
                      ),
                    ),
                    child: Row(
                      children: [
                        _LiquidAvatar(
                          initial: initial,
                          isGroup: conv.isGroup,
                          isOnline: !conv.isGroup && conv.isOnline,
                          hasUnread: hasUnread,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _TileContent(
                            displayName: displayName,
                            lastMessage: conv.lastMessage,
                            lastMessageAt: conv.lastMessageAt,
                            unreadCount: conv.unreadCount,
                            isMuted: conv.isMuted,
                            hasUnread: hasUnread,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Specular top edge
              Positioned(
                top: 0, left: 10, right: 10,
                child: Container(
                  height: 0.7,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.transparent, AppColors.specularTop, Colors.transparent],
                    ),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),

              // Unread glow pulse
              if (hasUnread)
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 22),
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: AppColors.accentGradient,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accent.withValues(alpha: 0.45),
                          blurRadius: 10,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: Text(
                      '${conv.unreadCount}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLiquidSnackbar(BuildContext context, String message, VoidCallback? onUndo) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        content: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AppBackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0x28FFFFFF), Color(0x10FFFFFF)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.glassBorderStrong, width: 0.6),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      message,
                      style: GoogleFonts.inter(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  if (onUndo != null)
                    GestureDetector(
                      onTap: onUndo,
                      child: Text(
                        'Geri Al',
                        style: GoogleFonts.inter(
                          color: AppColors.accentLight,
                          fontWeight: FontWeight.w700,
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Liquid Avatar
// ─────────────────────────────────────────────────────────────────────────────
class _LiquidAvatar extends StatelessWidget {
  final String initial;
  final bool isGroup;
  final bool isOnline;
  final bool hasUnread;

  const _LiquidAvatar({
    required this.initial,
    required this.isGroup,
    required this.isOnline,
    required this.hasUnread,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Outer glow for unread
        if (hasUnread)
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (isGroup ? const Color(0xFF7C3AED) : AppColors.accent)
                      .withValues(alpha: 0.35),
                  blurRadius: 16,
                  spreadRadius: 0,
                ),
              ],
            ),
          ),
        // Avatar body
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: isGroup
                  ? [
                      const Color(0xFF9333EA).withValues(alpha: 0.8),
                      const Color(0xFF6D28D9).withValues(alpha: 0.7),
                    ]
                  : [
                      AppColors.accent.withValues(alpha: 0.7),
                      AppColors.accentSecondary.withValues(alpha: 0.6),
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: hasUnread ? AppColors.accentBorder : AppColors.glassBorder,
              width: 1.0,
            ),
          ),
          child: Center(
            child: isGroup
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
        // Online dot
        if (isOnline)
          Positioned(
            right: 1,
            bottom: 1,
            child: Container(
              width: 13,
              height: 13,
              decoration: BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.bgBase, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.success.withValues(alpha: 0.5),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tile Content
// ─────────────────────────────────────────────────────────────────────────────
class _TileContent extends StatelessWidget {
  final String displayName;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final bool isMuted;
  final bool hasUnread;

  const _TileContent({
    required this.displayName,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.unreadCount,
    required this.isMuted,
    required this.hasUnread,
  });

  String _formatTime(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
    return '${date.day}/${date.month}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
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
                    fontSize: 15.5,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
                if (isMuted) ...[
                  const SizedBox(width: 5),
                  const Icon(Icons.volume_off_rounded,
                      color: AppColors.textMuted, size: 14),
                ],
              ],
            ),
            if (lastMessageAt != null)
              Text(
                _formatTime(lastMessageAt!),
                style: GoogleFonts.inter(
                  color: hasUnread ? AppColors.accentLight : AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          lastMessage ?? 'Henüz mesaj yok',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            color: hasUnread ? AppColors.textPrimary : AppColors.textSecondary,
            fontSize: 13.5,
            fontWeight: hasUnread ? FontWeight.w500 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dismiss Background
// ─────────────────────────────────────────────────────────────────────────────
class _DismissBackground extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Alignment alignment;
  final EdgeInsetsGeometry padding;

  const _DismissBackground({
    required this.icon,
    required this.label,
    required this.color,
    required this.alignment,
    required this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.85), color.withValues(alpha: 0.65)],
          begin: alignment == Alignment.centerLeft ? Alignment.centerLeft : Alignment.centerRight,
          end: alignment == Alignment.centerLeft ? Alignment.centerRight : Alignment.centerLeft,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      alignment: alignment,
      padding: padding,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Story Ring Item — Instagram tarzı yuvarlak story avatar
// ─────────────────────────────────────────────────────────────────────────────
class _StoryRingItem extends StatelessWidget {
  final String label;
  final String? avatarUrl;
  final bool isOwn;
  final bool hasStory;
  final VoidCallback onTap;

  const _StoryRingItem({
    required this.label,
    required this.avatarUrl,
    required this.isOwn,
    required this.hasStory,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                // Gradient ring
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: hasStory
                        ? const LinearGradient(
                            colors: [Color(0xFF6366F1), Color(0xFFEC4899), Color(0xFFF59E0B)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: hasStory ? null : AppColors.glassMedium,
                    border: hasStory
                        ? null
                        : Border.all(color: AppColors.glassBorder, width: 1.5),
                  ),
                  padding: const EdgeInsets.all(2.5),
                  child: ClipOval(
                    child: Container(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.bgElevated,
                      ),
                      padding: const EdgeInsets.all(2),
                      child: ClipOval(
                        child: avatarUrl != null && avatarUrl!.isNotEmpty
                            ? Image.network(
                                avatarUrl!,
                                width: 56,
                                height: 56,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _defaultAvatar(),
                              )
                            : _defaultAvatar(),
                      ),
                    ),
                  ),
                ),
                // Kendi hikaye butonu için + işareti
                if (isOwn)
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      ),
                      border: Border.all(color: AppColors.bgBase, width: 2),
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 12),
                  ),
              ],
            ),
            const SizedBox(height: 5),
            SizedBox(
              width: 64,
              child: Text(
                label,
                style: GoogleFonts.inter(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _defaultAvatar() {
    return Container(
      color: AppColors.bgElevated,
      child: const Icon(Icons.person_rounded, color: AppColors.textMuted, size: 28),
    );
  }
}
