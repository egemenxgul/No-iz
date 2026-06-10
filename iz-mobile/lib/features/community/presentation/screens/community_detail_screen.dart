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
import 'package:iz_mobile/features/messages/providers/chat_provider.dart';

class CommunityDetailScreen extends ConsumerStatefulWidget {
  final String slug;

  const CommunityDetailScreen({
    super.key,
    required this.slug,
  });

  @override
  ConsumerState<CommunityDetailScreen> createState() => _CommunityDetailScreenState();
}

class _CommunityDetailScreenState extends ConsumerState<CommunityDetailScreen> {
  Map<String, dynamic>? _community;
  List<Map<String, dynamic>> _posts = [];
  List<Map<String, dynamic>> _groups = [];
  bool _isLoadingDetails = true;
  bool _isLoadingFeed = false;
  bool _isLoadingGroups = false;
  bool _isActionLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() {
      _isLoadingDetails = true;
      _errorMessage = null;
    });

    try {
      final service = ref.read(communityServiceProvider);
      final comm = await service.getCommunityBySlug(widget.slug);
      final communityId = comm['id'] as String;

      setState(() {
        _community = comm;
        _isLoadingDetails = false;
      });

      // Fetch Feed and Groups in parallel
      _loadFeed(communityId);
      _loadGroups(communityId);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoadingDetails = false;
      });
    }
  }

  Future<void> _loadFeed(String communityId) async {
    setState(() => _isLoadingFeed = true);
    try {
      final service = ref.read(communityServiceProvider);
      final feed = await service.listCommunityPosts(communityId);
      setState(() {
        _posts = feed;
      });
    } catch (e) {
      debugPrint('Error loading feed: $e');
    } finally {
      setState(() => _isLoadingFeed = false);
    }
  }

  Future<void> _loadGroups(String communityId) async {
    setState(() => _isLoadingGroups = true);
    try {
      final service = ref.read(communityServiceProvider);
      final grps = await service.listCommunityGroups(communityId);
      setState(() {
        _groups = grps;
      });
    } catch (e) {
      debugPrint('Error loading groups: $e');
    } finally {
      setState(() => _isLoadingGroups = false);
    }
  }

  String _getRelativeTime(String dateStr) {
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final diff = DateTime.now().difference(date);

      if (diff.inSeconds < 60) {
        return 'Şimdi';
      } else if (diff.inMinutes < 60) {
        return '${diff.inMinutes} dk önce';
      } else if (diff.inHours < 24) {
        return '${diff.inHours} sa önce';
      } else {
        return '${diff.inDays} gün önce';
      }
    } catch (_) {
      return '';
    }
  }

  void _onLikePost(Map<String, dynamic> post) async {
    final postId = post['id'] as String;
    final likedByMe = post['liked_by_me'] as bool? ?? false;
    final service = ref.read(communityServiceProvider);

    // Optimistic Update
    setState(() {
      post['liked_by_me'] = !likedByMe;
      post['like_count'] = (post['like_count'] as int? ?? 0) + (likedByMe ? -1 : 1);
    });

    try {
      if (likedByMe) {
        await service.unlikePost(postId);
      } else {
        await service.likePost(postId);
      }
    } catch (e) {
      // Revert if error
      setState(() {
        post['liked_by_me'] = likedByMe;
        post['like_count'] = (post['like_count'] as int? ?? 0) + (likedByMe ? 1 : -1);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('İşlem başarısız oldu: $e')),
        );
      }
    }
  }

  void _onJoinGroup(Map<String, dynamic> group) async {
    final groupName = group['group_name'] as String? ?? 'Grup';
    final groupId = group['group_id'] as String;
    final inviteLink = group['invite_link'] as String?;

    if (inviteLink == null || inviteLink.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Grup davet linki bulunamadı.')),
      );
      return;
    }

    setState(() => _isActionLoading = true);

    try {
      final msgService = ref.read(messageServiceProvider);
      await msgService.joinGroupByInvite(inviteLink);
      
      // Refresh local conversations
      await ref.read(conversationProvider.notifier).loadConversations();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"${groupName}" grubuna katıldınız!')),
        );
        context.push('/app/messages/$groupId');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gruba katılım hatası: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  void _onLeaveCommunity() async {
    if (_community == null) return;
    final communityId = _community!['id'] as String;
    final name = _community!['name'] as String;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: AppColors.bgSurface.withOpacity(0.85),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: BorderSide(color: AppColors.glassBorder, width: 0.5)),
          title: Text(
            'Topluluktan Ayrıl',
            style: GoogleFonts.outfit(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
          ),
          content: Text(
            '"${name}" topluluğundan ayrılmak istediğinize emin misiniz?',
            style: GoogleFonts.inter(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('İptal', style: GoogleFonts.inter(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Ayrıl', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    setState(() => _isActionLoading = true);

    try {
      final service = ref.read(communityServiceProvider);
      await service.leaveCommunity(communityId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"${name}" topluluğundan ayrıldınız.')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ayrılma hatası: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  void _showCreatePostDialog() {
    if (_community == null) return;
    final communityId = _community!['id'] as String;

    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: AlertDialog(
            backgroundColor: AppColors.bgSurface.withOpacity(0.9),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: AppColors.glassBorder, width: 0.5),
            ),
            title: Row(
              children: [
                const Icon(Icons.edit_note_rounded, color: AppColors.accent, size: 28),
                const SizedBox(width: 8),
                Text(
                  'Yeni Gönderi Paylaş',
                  style: GoogleFonts.outfit(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: titleController,
                      style: GoogleFonts.inter(color: AppColors.textPrimary),
                      validator: (val) => (val == null || val.trim().isEmpty) ? 'Başlık alanı boş bırakılamaz' : null,
                      decoration: InputDecoration(
                        hintText: 'Başlık',
                        hintStyle: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 14),
                        filled: true,
                        fillColor: AppColors.bgBase.withOpacity(0.5),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: bodyController,
                      style: GoogleFonts.inter(color: AppColors.textPrimary),
                      maxLines: 4,
                      validator: (val) => (val == null || val.trim().isEmpty) ? 'Gönderi içeriği boş bırakılamaz' : null,
                      decoration: InputDecoration(
                        hintText: 'Ne düşünüyorsun?',
                        hintStyle: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 14),
                        filled: true,
                        fillColor: AppColors.bgBase.withOpacity(0.5),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.of(context).pop(),
                child: Text('Vazgeç', style: GoogleFonts.inter(color: AppColors.textSecondary)),
              ),
              ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setModalState(() => isSubmitting = true);
                        try {
                          final service = ref.read(communityServiceProvider);
                          await service.createPost(
                            communityId: communityId,
                            title: titleController.text.trim(),
                            body: bodyController.text.trim(),
                          );
                          if (context.mounted) {
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Gönderi başarıyla paylaşıldı!')),
                            );
                            _loadFeed(communityId);
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Gönderi paylaşım hatası: $e')),
                            );
                          }
                        } finally {
                          setModalState(() => isSubmitting = false);
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: isSubmitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text('Paylaş', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final commName = _community != null ? _community!['name'] as String : 'Yükleniyor...';

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.bgBase,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
            onPressed: () => context.pop(),
          ),
          title: Text(
            commName,
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(50),
            child: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.glassDark.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.glassBorder, width: 0.5),
                  ),
                  child: TabBar(
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    indicator: BoxDecoration(
                      color: AppColors.accent.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.accentBorder.withOpacity(0.4),
                        width: 0.5,
                      ),
                    ),
                    labelColor: AppColors.textPrimary,
                    unselectedLabelColor: AppColors.textSecondary,
                    labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
                    unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 13),
                    tabs: const [
                      Tab(text: 'Akış'),
                      Tab(text: 'Gruplar'),
                      Tab(text: 'Hakkında'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        body: Stack(
          children: [
            // Background ambient blobs
            Positioned(
              top: -60,
              left: -40,
              child: _AmbientBlob(color: AppColors.accent.withOpacity(0.12), size: 300),
            ),
            Positioned(
              bottom: -60,
              right: -40,
              child: _AmbientBlob(color: AppColors.accentSecondary.withOpacity(0.08), size: 280),
            ),

            if (_isLoadingDetails)
              const Center(child: CircularProgressIndicator(color: AppColors.accent))
            else if (_errorMessage != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.danger),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: GoogleFonts.inter(color: AppColors.textPrimary),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadAllData,
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
                        child: const Text('Yeniden Dene'),
                      ),
                    ],
                  ),
                ),
              )
            else
              TabBarView(
                physics: const BouncingScrollPhysics(),
                children: [
                  _buildFeedTab(),
                  _buildGroupsTab(),
                  _buildAboutTab(),
                ],
              ),

            if (_isActionLoading)
              Container(
                color: Colors.black.withOpacity(0.55),
                child: const Center(child: CircularProgressIndicator(color: AppColors.accent)),
              ),
          ],
        ),
        floatingActionButton: (_community != null && !_isLoadingDetails)
            ? FloatingActionButton(
                onPressed: _showCreatePostDialog,
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                elevation: 4,
                child: const Icon(Icons.add_comment_rounded),
              )
            : null,
      ),
    );
  }

  Widget _buildFeedTab() {
    if (_isLoadingFeed && _posts.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accent));
    }

    if (_posts.isEmpty) {
      return RefreshIndicator(
        color: AppColors.accent,
        onRefresh: () => _loadFeed(_community!['id']),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.3),
            _buildEmptyState(
              icon: Icons.post_add_rounded,
              title: 'Henüz gönderi yok',
              subtitle: 'Bu toplulukta henüz bir paylaşım yapılmadı. İlk paylaşımı sen yap!',
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: () => _loadFeed(_community!['id']),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(16, 150, 16, 80),
        itemCount: _posts.length,
        itemBuilder: (context, index) {
          final post = _posts[index];
          final title = post['title'] as String? ?? '';
          final body = post['body'] as String? ?? '';
          final authorName = post['author_display_name'] as String? ?? post['author_username'] as String? ?? 'Kullanıcı';
          final authorUsername = post['author_username'] as String? ?? '';
          final likeCount = post['like_count'] as int? ?? 0;
          final likedByMe = post['liked_by_me'] as bool? ?? false;
          final relativeTime = _getRelativeTime(post['created_at'] as String? ?? '');
          final initial = authorName.isNotEmpty ? authorName[0].toUpperCase() : '?';

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.accent.withOpacity(0.15),
                        child: Text(
                          initial,
                          style: GoogleFonts.outfit(color: AppColors.accentLight, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              authorName,
                              style: GoogleFonts.inter(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            if (authorUsername.isNotEmpty)
                              Text(
                                '@$authorUsername',
                                style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 11),
                              ),
                          ],
                        ),
                      ),
                      Text(
                        relativeTime,
                        style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (title.isNotEmpty) ...[
                    Text(
                      title,
                      style: GoogleFonts.outfit(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 6),
                  ],
                  Text(
                    body,
                    style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 13.5, height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  const Divider(color: AppColors.glassBorder, height: 1, thickness: 0.5),
                  const SizedBox(height: 8),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _onLikePost(post),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            likedByMe ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            color: likedByMe ? AppColors.danger : AppColors.textSecondary,
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            likeCount.toString(),
                            style: GoogleFonts.inter(
                              color: likedByMe ? AppColors.danger : AppColors.textSecondary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGroupsTab() {
    if (_isLoadingGroups && _groups.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accent));
    }

    if (_groups.isEmpty) {
      return RefreshIndicator(
        color: AppColors.accent,
        onRefresh: () => _loadGroups(_community!['id']),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.3),
            _buildEmptyState(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'Grup bulunamadı',
              subtitle: 'Bu topluluğa bağlı herhangi bir sohbet grubu bulunmuyor.',
            ),
          ],
        ),
      );
    }

    // Access the conversations to check membership
    final conversations = ref.watch(conversationProvider);

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: () => _loadGroups(_community!['id']),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(16, 150, 16, 80),
        itemCount: _groups.length,
        itemBuilder: (context, index) {
          final group = _groups[index];
          final groupId = group['group_id'] as String;
          final groupName = group['group_name'] as String? ?? 'Grup';
          final initial = groupName.isNotEmpty ? groupName[0].toUpperCase() : '?';

          // Check if user is a member of this group chat
          final isMember = conversations.any((c) => c.isGroup && c.otherUserId == groupId);

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.accent.withOpacity(0.15),
                    child: Text(
                      initial,
                      style: GoogleFonts.outfit(color: AppColors.accentLight, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          groupName,
                          style: GoogleFonts.inter(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          isMember ? 'Katıldınız' : 'Topluluk Grubu',
                          style: GoogleFonts.inter(
                            color: isMember ? AppColors.accentLight : AppColors.textSecondary,
                            fontSize: 11,
                            fontWeight: isMember ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isMember)
                    _TextActionButton(
                      text: 'Sohbet',
                      textColor: AppColors.accentLight,
                      backgroundColor: Colors.transparent,
                      borderColor: AppColors.accentBorder.withOpacity(0.5),
                      onTap: () => context.push('/app/messages/$groupId'),
                    )
                  else
                    _TextActionButton(
                      text: 'Katıl',
                      textColor: Colors.white,
                      backgroundColor: AppColors.accent,
                      borderColor: Colors.transparent,
                      onTap: () => _onJoinGroup(group),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAboutTab() {
    if (_community == null) return const SizedBox.shrink();

    final name = _community!['name'] as String? ?? '';
    final slug = _community!['slug'] as String? ?? '';
    final desc = _community!['description'] as String? ?? '';
    final memberCount = _community!['member_count'] as int? ?? 0;
    final groupCount = _community!['group_count'] as int? ?? 0;

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 150, 16, 80),
      children: [
        GlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hakkında',
                style: GoogleFonts.outfit(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 12),
              Text(
                desc.isNotEmpty ? desc : 'Açıklama belirtilmemiş.',
                style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13.5, height: 1.4),
              ),
              const SizedBox(height: 20),
              const Divider(color: AppColors.glassBorder, height: 1, thickness: 0.5),
              const SizedBox(height: 16),
              
              // Statistics
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(label: 'Üye', value: memberCount.toString(), icon: Icons.people_outline_rounded),
                  _buildStatItem(label: 'Grup', value: groupCount.toString(), icon: Icons.chat_bubble_outline_rounded),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: AppColors.glassBorder, height: 1, thickness: 0.5),
              const SizedBox(height: 16),

              Text(
                'Topluluk Adresi',
                style: GoogleFonts.inter(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                'iz.app/c/$slug',
                style: GoogleFonts.inter(color: AppColors.accentLight, fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        
        // Leave Button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: ElevatedButton.icon(
            onPressed: _onLeaveCommunity,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger.withOpacity(0.15),
              foregroundColor: AppColors.danger,
              side: const BorderSide(color: AppColors.danger, width: 0.5),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            icon: const Icon(Icons.exit_to_app_rounded, size: 20),
            label: Text(
              'Topluluktan Ayrıl',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem({required String label, required String value, required IconData icon}) {
    return Column(
      children: [
        Icon(icon, color: AppColors.accentLight, size: 24),
        const SizedBox(height: 6),
        Text(
          value,
          style: GoogleFonts.outfit(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        Text(
          label,
          style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildEmptyState({required IconData icon, required String title, required String subtitle}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accent.withOpacity(0.08),
              border: Border.all(color: AppColors.accentBorder.withOpacity(0.15), width: 0.5),
            ),
            child: Icon(icon, size: 32, color: AppColors.accentLight),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12),
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(10),
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
