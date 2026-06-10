// Copyright (c) 2026 Egemen GÜL (github.com/egemenxgul)
// Licensed under the GNU Affero General Public License v3.0 (AGPL-3.0)
// See LICENSE in the project root for license information.

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iz_mobile/core/theme/app_colors.dart';
import 'package:iz_mobile/core/theme/glass_widgets.dart';
import 'package:iz_mobile/features/messages/providers/chat_provider.dart';
import 'package:iz_mobile/features/auth/providers/auth_provider.dart';

class GroupSettingsScreen extends ConsumerStatefulWidget {
  final String groupId;
  const GroupSettingsScreen({super.key, required this.groupId});

  @override
  ConsumerState<GroupSettingsScreen> createState() => _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends ConsumerState<GroupSettingsScreen> {
  Map<String, dynamic>? _groupDetails;
  List<Map<String, dynamic>> _members = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final service = ref.read(messageServiceProvider);
      final details = await service.getGroupDetails(widget.groupId);
      final members = await service.listGroupMembers(widget.groupId);

      setState(() {
        _groupDetails = details;
        _members = members;
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

  void _onLeaveGroup() async {
    final name = _groupDetails?['name'] ?? 'Grup';
    final myUserId = ref.read(authProvider).userId ?? '';
    final myMemberRecord = _members.firstWhere((m) => m['user_id'] == myUserId, orElse: () => {});
    final isOwner = myMemberRecord['role'] == 'owner';

    if (isOwner) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Grup sahibi gruptan ayrılmadan önce sahipliği devretmelidir.')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgElevated,
        title: const Text('Gruptan Ayrıl'),
        content: Text('"$name" grubundan ayrılmak istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('İptal', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Ayrıl', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final service = ref.read(messageServiceProvider);
      await service.leaveGroup(widget.groupId);
      
      // Force reload conversations locally
      await ref.read(conversationProvider.notifier).loadConversations();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gruptan başarıyla ayrıldınız.')),
        );
        // Pop back to main app screen
        context.go('/app');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ayrılma hatası: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onKickMember(String userId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgElevated,
        title: const Text('Üyeyi Çıkar'),
        content: Text('$name kullanıcısını gruptan çıkarmak istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('İptal', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Çıkar', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final service = ref.read(messageServiceProvider);
      await service.kickGroupMember(widget.groupId, userId);
      _loadData(); // reload members list
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$name gruptan çıkarıldı.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onChangeRole(String userId, String name, String currentRole) async {
    final nextRole = currentRole == 'admin' ? 'member' : 'admin';
    final actionText = nextRole == 'admin' ? 'Yönetici Yap' : 'Yöneticiliği Kaldır';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgElevated,
        title: Text(actionText),
        content: Text('$name kullanıcısının yetkisini "$nextRole" olarak değiştirmek istiyor musunuz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('İptal', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(actionText, style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final service = ref.read(messageServiceProvider);
      await service.promoteGroupMember(widget.groupId, userId, nextRole);
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kullanıcı yetkileri güncellendi.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onCopyInviteLink() {
    final token = _groupDetails?['invite_link'];
    if (token == null) return;
    
    // Format full link or just share code
    final link = 'https://no-iz.app/join/$token';
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Grup davet linki kopyalandı!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myUserId = ref.watch(authProvider).userId ?? '';
    
    // Find my membership role
    final myMemberRecord = _members.firstWhere((m) => m['user_id'] == myUserId, orElse: () => {});
    final myRole = myMemberRecord['role'] as String? ?? 'member';
    
    final isOwner = myRole == 'owner';
    final isAdmin = myRole == 'admin' || isOwner;

    return Scaffold(
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
          'Grup Ayarları',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: Stack(
        children: [
          // Ambient blobs
          Positioned(
            top: -80,
            left: -40,
            child: _AmbientBlob(color: AppColors.accent.withValues(alpha: 0.1), size: 300),
          ),
          Positioned(
            bottom: -80,
            right: -40,
            child: _AmbientBlob(color: AppColors.accentSecondary.withValues(alpha: 0.08), size: 280),
          ),

          if (_isLoading && _groupDetails == null)
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
                  ElevatedButton(onPressed: _loadData, child: const Text('Yeniden Dene')),
                ],
              ),
            )
          else
            SafeArea(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                children: [
                  // Group Header Card
                  GlassCard(
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 44,
                          backgroundColor: AppColors.accent.withValues(alpha: 0.2),
                          child: const Icon(Icons.group_rounded, color: AppColors.accentLight, size: 40),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _groupDetails?['name'] ?? 'Grup Adı',
                          style: GoogleFonts.outfit(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 22,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _groupDetails?['description']?.isNotEmpty == true 
                              ? _groupDetails!['description'] 
                              : 'Açıklama girilmemiş.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Invite Link Card
                  GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.link_rounded, color: AppColors.accentLight, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Grup Davet Linki',
                                style: GoogleFonts.inter(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'https://no-iz.app/join/${_groupDetails?['invite_link'] ?? ''}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, color: AppColors.accent),
                          onPressed: _onCopyInviteLink,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Members Section Title
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'ÜYELER (${_members.length})',
                        style: GoogleFonts.inter(
                          color: AppColors.accent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Members List
                  ..._members.map((member) {
                    final memberId = member['user_id'] as String;
                    final memberName = member['display_name']?.isNotEmpty == true 
                        ? member['display_name'] 
                        : member['username'];
                    final memberRole = member['role'] as String;
                    final initial = memberName.isNotEmpty ? memberName[0].toUpperCase() : '?';

                    final isSelf = memberId == myUserId;
                    final targetIsOwner = memberRole == 'owner';
                    final targetIsAdmin = memberRole == 'admin';

                    // Determine permissions
                    bool canKick = false;
                    bool canPromote = false;

                    if (!isSelf && !targetIsOwner) {
                      if (isOwner) {
                        canKick = true;
                        canPromote = true; // Owner can manage everyone
                      } else if (isAdmin && !targetIsAdmin) {
                        canKick = true; // Admin can kick regular members
                      }
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: AppColors.bgSurface.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border.withValues(alpha: 0.05), width: 0.5),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.bgHover,
                          child: Text(
                            initial,
                            style: GoogleFonts.outfit(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Row(
                          children: [
                            Text(
                              memberName,
                              style: GoogleFonts.inter(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                            if (isSelf) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.accent.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Siz',
                                  style: TextStyle(color: AppColors.accentLight, fontSize: 9, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Text(
                          '@${member['username']}',
                          style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Role Badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: targetIsOwner
                                    ? Colors.orange.withValues(alpha: 0.15)
                                    : (targetIsAdmin 
                                        ? AppColors.accent.withValues(alpha: 0.15)
                                        : AppColors.bgHover),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                targetIsOwner ? 'Sahip' : (targetIsAdmin ? 'Yönetici' : 'Üye'),
                                style: TextStyle(
                                  color: targetIsOwner 
                                      ? Colors.orangeAccent 
                                      : (targetIsAdmin ? AppColors.accentLight : AppColors.textSecondary),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),

                            // Admin Actions Popup
                            if (canKick || canPromote)
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert_rounded, color: AppColors.textSecondary),
                                color: AppColors.bgElevated,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                onSelected: (val) {
                                  if (val == 'kick') {
                                    _onKickMember(memberId, memberName);
                                  } else if (val == 'promote') {
                                    _onChangeRole(memberId, memberName, memberRole);
                                  }
                                },
                                itemBuilder: (context) => [
                                  if (canPromote)
                                    PopupMenuItem(
                                      value: 'promote',
                                      child: Row(
                                        children: [
                                          Icon(targetIsAdmin ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_up_rounded, color: AppColors.accent, size: 18),
                                          const SizedBox(width: 8),
                                          Text(
                                            targetIsAdmin ? 'Yetkiyi Düşür' : 'Yönetici Yap',
                                            style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600),
                                          ),
                                        ],
                                      ),
                                    ),
                                  if (canKick)
                                    PopupMenuItem(
                                      value: 'kick',
                                      child: Row(
                                        children: [
                                          const Icon(Icons.person_remove_rounded, color: AppColors.danger, size: 18),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Gruptan Çıkar',
                                            style: GoogleFonts.inter(color: AppColors.danger, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 24),

                  // Leave Group Button
                  GestureDetector(
                    onTap: _onLeaveGroup,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3), width: 0.5),
                      ),
                      child: Center(
                        child: Text(
                          'Gruptan Ayrıl',
                          style: GoogleFonts.inter(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),

          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.4),
              child: const Center(child: CircularProgressIndicator(color: AppColors.accent)),
            ),
        ],
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
