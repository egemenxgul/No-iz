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
import 'package:iz_mobile/features/community/data/community_service.dart';

class CommunityListScreen extends ConsumerStatefulWidget {
  const CommunityListScreen({super.key});

  @override
  ConsumerState<CommunityListScreen> createState() => _CommunityListScreenState();
}

class _CommunityListScreenState extends ConsumerState<CommunityListScreen> {
  List<Map<String, dynamic>> _myCommunities = [];
  List<Map<String, dynamic>> _discoverCommunities = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCommunities();
  }

  Future<void> _loadCommunities() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final service = ref.read(communityServiceProvider);
      final my = await service.getMyCommunities();
      final discover = await service.discoverCommunities();

      setState(() {
        _myCommunities = my;
        _discoverCommunities = discover;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onJoinCommunity(String communityId, String name) async {
    setState(() => _isLoading = true);
    try {
      final service = ref.read(communityServiceProvider);
      await service.joinCommunity(communityId);
      
      // Reload lists
      final my = await service.getMyCommunities();
      final discover = await service.discoverCommunities();

      setState(() {
        _myCommunities = my;
        _discoverCommunities = discover;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"$name" topluluğuna katıldınız!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Topluluğa katılım hatası: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.bgBase,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: Text(
            'Topluluklar',
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
                icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.accent, size: 24),
                onPressed: () => context.push('/communities/create'),
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
                    tabs: const [
                      Tab(text: 'Topluluklarım'),
                      Tab(text: 'Keşfet'),
                    ],
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
              top: -60,
              left: -40,
              child: _AmbientBlob(color: AppColors.accent.withValues(alpha: 0.12), size: 300),
            ),
            Positioned(
              bottom: -60,
              right: -40,
              child: _AmbientBlob(color: AppColors.accentSecondary.withValues(alpha: 0.08), size: 280),
            ),

            if (_isLoading && _myCommunities.isEmpty && _discoverCommunities.isEmpty)
              const Center(child: CircularProgressIndicator(color: AppColors.accent))
            else if (_errorMessage != null)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.danger),
                    const SizedBox(height: 16),
                    Text(_errorMessage!, style: GoogleFonts.inter(color: AppColors.textPrimary)),
                    const SizedBox(height: 16),
                    ElevatedButton(onPressed: _loadCommunities, child: const Text('Yeniden Dene')),
                  ],
                ),
              )
            else
              TabBarView(
                physics: const BouncingScrollPhysics(),
                children: [
                  _buildMyTab(),
                  _buildDiscoverTab(),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyTab() {
    if (_myCommunities.isEmpty) {
      return _buildEmptyState(
        icon: Icons.public_off_rounded,
        title: 'Topluluk yok',
        subtitle: 'Henüz hiçbir topluluğa katılmadınız.',
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 150, 16, 80),
      itemCount: _myCommunities.length,
      itemBuilder: (context, index) {
        final item = _myCommunities[index];
        final name = item['name'] as String? ?? 'Topluluk';
        final slug = item['slug'] as String? ?? '';
        final desc = item['description'] as String? ?? '';
        final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.accent.withValues(alpha: 0.2),
                  child: Text(
                    initial,
                    style: GoogleFonts.outfit(color: AppColors.accentLight, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
                const SizedBox(width: 14),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.inter(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        desc.isNotEmpty ? desc : 'Açıklama girilmemiş.',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),

                IconButton(
                  icon: const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.accent, size: 18),
                  onPressed: () {
                    // Navigate to details
                    context.push('/communities/detail/$slug');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDiscoverTab() {
    // Filter discover list so it does not contain joined communities
    final joinedIds = _myCommunities.map((c) => c['id'] as String).toSet();
    final list = _discoverCommunities.where((c) => !joinedIds.contains(c['id'] as String)).toList();

    if (list.isEmpty) {
      return _buildEmptyState(
        icon: Icons.explore_off_rounded,
        title: 'Keşfedilecek topluluk yok',
        subtitle: 'Tüm mevcut topluluklara katıldınız veya hiç topluluk yok.',
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 150, 16, 80),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final item = list[index];
        final id = item['id'] as String;
        final name = item['name'] as String? ?? 'Topluluk';
        final desc = item['description'] as String? ?? '';
        final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.bgHover,
                  child: Text(
                    initial,
                    style: GoogleFonts.outfit(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
                const SizedBox(width: 14),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.inter(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        desc.isNotEmpty ? desc : 'Açıklama girilmemiş.',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),

                // Join Button
                _TextActionButton(
                  text: 'Katıl',
                  textColor: Colors.white,
                  backgroundColor: AppColors.accent,
                  borderColor: Colors.transparent,
                  onTap: () => _onJoinCommunity(id, name),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState({required IconData icon, required String title, required String subtitle}) {
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
              child: Icon(icon, size: 40, color: AppColors.accentLight),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
        ],
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 0.5),
        ),
        child: Text(
          text,
          style: GoogleFonts.inter(
            color: textColor,
            fontWeight: FontWeight.bold,
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
