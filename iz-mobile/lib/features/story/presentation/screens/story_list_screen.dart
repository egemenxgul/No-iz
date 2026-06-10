import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iz_mobile/core/theme/app_colors.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../providers/story_provider.dart';
import '../../models/story_model.dart';
import 'story_viewer_screen.dart';
import 'create_story_screen.dart';

class StoryListScreen extends ConsumerStatefulWidget {
  const StoryListScreen({super.key});

  @override
  ConsumerState<StoryListScreen> createState() => _StoryListScreenState();
}

class _StoryListScreenState extends ConsumerState<StoryListScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final myUserId = ref.watch(authProvider).userId ?? '';
    final feed = ref.watch(storyProvider);
    final myStoriesFeed = feed.where((f) => f.userId == myUserId).toList();
    final friendsFeed = feed.where((f) => f.userId != myUserId).toList();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.bgBase,
        extendBodyBehindAppBar: true,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: AppBar(
                backgroundColor: AppColors.bgBase.withValues(alpha: 0.75),
                elevation: 0,
                surfaceTintColor: Colors.transparent,
                title: Text(
                  'Durumlar',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    letterSpacing: -0.4,
                    color: AppColors.textPrimary,
                  ),
                ),
                actions: [
                  _GlassIconBtn(
                    icon: Icons.refresh_rounded,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      ref.read(storyProvider.notifier).loadFeed();
                    },
                  ),
                  const SizedBox(width: 8),
                ],
                systemOverlayStyle: SystemUiOverlayStyle.light,
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
              child: _blob(AppColors.accent.withValues(alpha: 0.12), 280),
            ),
            Positioned(
              bottom: 80,
              left: -80,
              child: _blob(AppColors.accentSecondary.withValues(alpha: 0.08), 240),
            ),

            FadeTransition(
              opacity: _fadeAnim,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 110, 16, 40),
                physics: const BouncingScrollPhysics(),
                children: [
                  // ── My Status Card ─────────────────────────────────
                  _MyStatusCard(
                    myStoriesFeed: myStoriesFeed,
                    onView: myStoriesFeed.isNotEmpty &&
                            myStoriesFeed.first.stories.isNotEmpty
                        ? () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => StoryViewerScreen(
                                  feedItem: myStoriesFeed.first,
                                ),
                              ),
                            )
                        : null,
                    onAdd: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CreateStoryScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── Friends Feed ────────────────────────────────────
                  if (friendsFeed.isEmpty)
                    _EmptyState()
                  else ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 14),
                      child: Text(
                        'ARKADAŞ GÜNCELLEMELERİ',
                        style: GoogleFonts.outfit(
                          color: AppColors.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ),
                    ...friendsFeed.map(
                      (feedItem) => _StoryTile(
                        feedItem: feedItem,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                StoryViewerScreen(feedItem: feedItem),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: _AddStoryFAB(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateStoryScreen()),
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

// ─── My Status Card ──────────────────────────────────────────────────────────
class _MyStatusCard extends StatelessWidget {
  final List<FriendStoryFeedModel> myStoriesFeed;
  final VoidCallback? onView;
  final VoidCallback onAdd;

  const _MyStatusCard({
    required this.myStoriesFeed,
    this.onView,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final hasStory =
        myStoriesFeed.isNotEmpty && myStoriesFeed.first.stories.isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.glassLight.withValues(alpha: 0.9),
                AppColors.glassMedium.withValues(alpha: 0.6),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.glassBorder, width: 0.6),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 24,
                spreadRadius: -4,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              // Avatar with ring
              GestureDetector(
                onTap: hasStory ? onView : onAdd,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: hasStory
                            ? LinearGradient(
                                colors: [
                                  AppColors.accent,
                                  AppColors.accentSecondary,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        color: hasStory ? null : AppColors.glassMedium,
                      ),
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.bgElevated,
                        ),
                        child: const Icon(
                          Icons.person_outline_rounded,
                          color: AppColors.textSecondary,
                          size: 30,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: onAdd,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [AppColors.accent, AppColors.accentSecondary],
                          ),
                          border: Border.all(
                            color: AppColors.bgBase,
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.add,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Benim Durumum',
                      style: GoogleFonts.outfit(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      hasStory
                          ? 'Durumunuzu görüntülemek için dokunun'
                          : 'Bugününü arkadaşlarınla paylaş',
                      style: GoogleFonts.inter(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              if (hasStory)
                GestureDetector(
                  onTap: onView,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [AppColors.accent, AppColors.accentSecondary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accent.withValues(alpha: 0.4),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                )
              else
                GestureDetector(
                  onTap: onAdd,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.glassLight,
                      border: Border.all(
                        color: AppColors.glassBorder,
                        width: 0.8,
                      ),
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      color: AppColors.textSecondary,
                      size: 22,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Friend Story Tile ────────────────────────────────────────────────────────
class _StoryTile extends StatelessWidget {
  final FriendStoryFeedModel feedItem;
  final VoidCallback onTap;

  const _StoryTile({required this.feedItem, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final initial = feedItem.displayName.isNotEmpty
        ? feedItem.displayName[0].toUpperCase()
        : '?';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.glassLight,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.glassBorder, width: 0.5),
              ),
              child: Row(
                children: [
                  // Avatar with gradient ring
                  Container(
                    padding: const EdgeInsets.all(2.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [AppColors.accent, AppColors.accentSecondary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accent.withValues(alpha: 0.3),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.bgElevated,
                      ),
                      child: Center(
                        child: Text(
                          initial,
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          feedItem.displayName,
                          style: GoogleFonts.outfit(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${feedItem.stories.length} durum paylaştı',
                          style: GoogleFonts.inter(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textMuted,
                    size: 20,
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

// ─── Empty State ──────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 300,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.glassLight,
                border: Border.all(color: AppColors.glassBorder, width: 0.5),
              ),
              child: const Icon(
                Icons.auto_stories_outlined,
                color: AppColors.textMuted,
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Henüz durum güncellemesi yok',
              style: GoogleFonts.outfit(
                color: AppColors.textSecondary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Arkadaşlarının paylaşımları burada görünecek',
              style: GoogleFonts.inter(
                color: AppColors.textMuted,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── FAB ─────────────────────────────────────────────────────────────────────
class _AddStoryFAB extends StatelessWidget {
  final VoidCallback onTap;
  const _AddStoryFAB({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6366F1).withValues(alpha: 0.45),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 24),
      ),
    );
  }
}

// ─── Glass Icon Button ────────────────────────────────────────────────────────
class _GlassIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GlassIconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.glassMedium,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.glassBorder, width: 0.5),
            ),
            child: Icon(icon, color: AppColors.textSecondary, size: 20),
          ),
        ),
      ),
    );
  }
}
