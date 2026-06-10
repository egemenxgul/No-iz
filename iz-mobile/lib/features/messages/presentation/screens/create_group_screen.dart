// Copyright (c) 2026 Egemen GÜL (github.com/egemenxgul)
// Licensed under the GNU Affero General Public License v3.0 (AGPL-3.0)
// See LICENSE in the project root for license information.

import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import 'package:iz_mobile/core/theme/app_colors.dart';
import 'package:iz_mobile/core/theme/glass_widgets.dart';
import 'package:iz_mobile/features/messages/providers/chat_provider.dart';
import 'package:iz_mobile/features/auth/providers/auth_provider.dart';
import 'package:iz_mobile/features/messages/providers/message_model.dart';
import 'package:iz_mobile/features/messages/providers/contacts_provider.dart';

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  final Set<String> _selectedUserIds = {};
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _onCreateGroup() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedUserIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen gruba davet etmek için en az bir kişi seçin.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final service = ref.read(messageServiceProvider);
      final myUserId = ref.read(authProvider).userId ?? '';
      
      final groupName = _nameController.text.trim();
      final groupDesc = _descController.text.trim();

      // 1. Create group on Backend
      final groupResult = await service.createGroup(groupName, groupDesc);
      final newGroupId = groupResult['id'] as String;
      final inviteToken = groupResult['invite_link'] as String;

      // 2. Send E2EE group invite message to each selected friend
      for (final friendId in _selectedUserIds) {
        final inviteMsg = MessageModel(
          id: const Uuid().v4(),
          conversationId: friendId,
          senderId: myUserId,
          recipientId: friendId,
          ciphertext: '...', // will be encrypted locally in addMessage
          plaintext: jsonEncode({
            'type': 'group_invite',
            'group_id': newGroupId,
            'group_name': groupName,
            'invite_token': inviteToken,
          }),
          msgType: 'group_invite',
          createdAt: DateTime.now(),
        );
        
        await ref.read(chatProvider(friendId).notifier).addMessage(inviteMsg);
      }

      // 3. Force reload local conversations
      await ref.read(conversationProvider.notifier).loadConversations();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Grup başarıyla oluşturuldu!')),
        );
        // Navigate to the newly created group chat screen
        context.pushReplacement('/app/messages/$newGroupId');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Grup oluşturma hatası: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final conversations = ref.watch(conversationProvider);
    final contactsState = ref.watch(contactsProvider);

    // List confirmed friends (accepted conversations that are not groups)
    final friendsList = conversations.where((c) {
      return !c.isGroup && c.friendshipStatus == 'accepted';
    }).toList();

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
          'Yeni Grup',
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
          // ── Ambient background blobs ──────────────────────────────────────
          Positioned(
            top: -60,
            right: -60,
            child: _AmbientBlob(
              color: AppColors.accent.withValues(alpha: 0.12),
              size: 280,
            ),
          ),
          Positioned(
            bottom: 60,
            left: -80,
            child: _AmbientBlob(
              color: AppColors.accentSecondary.withValues(alpha: 0.08),
              size: 240,
            ),
          ),

          // ── Form & Content ──────────────────────────────────────────────
          SafeArea(
            child: Form(
              key: _formKey,
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                children: [
                  // Group Name & Desc Details
                  GlassCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Grup Bilgileri',
                          style: GoogleFonts.inter(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Name Field
                        TextFormField(
                          controller: _nameController,
                          style: GoogleFonts.inter(color: AppColors.textPrimary),
                          validator: (val) {
                            if (val == null || val.trim().length < 2) {
                              return 'Grup adı en az 2 karakter olmalıdır';
                            }
                            return null;
                          },
                          decoration: InputDecoration(
                            hintText: 'Grup Adı',
                            hintStyle: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 14),
                            filled: true,
                            fillColor: AppColors.bgSurface.withValues(alpha: 0.3),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.1)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.1)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Description Field
                        TextFormField(
                          controller: _descController,
                          style: GoogleFonts.inter(color: AppColors.textPrimary),
                          maxLines: 2,
                          decoration: InputDecoration(
                            hintText: 'Grup Açıklaması (İsteğe bağlı)',
                            hintStyle: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 14),
                            filled: true,
                            fillColor: AppColors.bgSurface.withValues(alpha: 0.3),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.1)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.1)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Friends Selector Section
                  Text(
                    'KATILIMCILARI SEÇ (${_selectedUserIds.length})',
                    style: GoogleFonts.inter(
                      color: AppColors.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),

                  if (friendsList.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'Gruba davet edilebilecek arkadaşınız yok.',
                          style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 14),
                        ),
                      ),
                    )
                  else
                    ...friendsList.map((friend) {
                      final name = friend.otherDisplayName?.isNotEmpty == true ? friend.otherDisplayName! : friend.otherUsername;
                      final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
                      final isSelected = _selectedUserIds.contains(friend.otherUserId);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: AppColors.bgSurface.withValues(alpha: isSelected ? 0.45 : 0.25),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? AppColors.accentBorder : AppColors.border.withValues(alpha: 0.05),
                            width: 0.5,
                          ),
                        ),
                        child: CheckboxListTile(
                          value: isSelected,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedUserIds.add(friend.otherUserId);
                              } else {
                                _selectedUserIds.remove(friend.otherUserId);
                              }
                            });
                          },
                          secondary: CircleAvatar(
                            backgroundColor: isSelected ? AppColors.accent : AppColors.bgHover,
                            child: Text(
                              initial,
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            name,
                            style: GoogleFonts.inter(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            '@${friend.otherUsername}',
                            style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12),
                          ),
                          activeColor: AppColors.accent,
                          checkColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          controlAffinity: ListTileControlAffinity.trailing,
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),

          // Loading overlay
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              ),
            ),
        ],
      ),
      floatingActionButton: _isLoading
          ? null
          : FloatingActionButton.extended(
              onPressed: _onCreateGroup,
              label: Text(
                'Grup Oluştur',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, letterSpacing: 0.2),
              ),
              icon: const Icon(Icons.check),
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              elevation: 4,
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
