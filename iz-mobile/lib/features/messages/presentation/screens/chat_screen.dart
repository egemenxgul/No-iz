import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iz_mobile/core/theme/app_colors.dart';
import 'package:iz_mobile/features/auth/providers/auth_provider.dart';
import 'package:iz_mobile/features/messages/providers/chat_provider.dart';
import 'package:iz_mobile/features/messages/providers/message_model.dart';
import 'package:iz_mobile/features/messages/providers/contacts_provider.dart';
import 'package:iz_mobile/core/network/websocket_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:file_picker/file_picker.dart';
import 'package:iz_mobile/features/messages/providers/media_upload_service.dart';
import 'package:iz_mobile/features/social/presentation/widgets/report_dialog.dart';
import 'package:iz_mobile/features/call/providers/call_provider.dart';
import 'package:iz_mobile/features/call/models/call_session.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'dart:ui';
import 'dart:math';
import 'dart:io';
import 'package:go_router/go_router.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String otherUserId;
  const ChatScreen({super.key, required this.otherUserId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  bool _isTyping = false;
  DateTime? _lastTypingSent;

  // Sabitlenmiş mesaj navigasyonu — birden fazla pin varsa döngüsel gezinme
  int _pinnedMessageIndex = 0;
  final Map<String, GlobalKey> _messageKeys = {};

  @override
  void initState() {
    super.initState();
    // Register this conversation as active so incoming messages are auto-marked read
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(activeChatConversationId.notifier).set(widget.otherUserId);
      _markAllUnreadMessagesRead();
    });
  }

  @override
  void dispose() {
    if (_isTyping) {
      final ws = ref.read(webSocketProvider);
      ws?.sendMessage('user_typing', {
        'recipient_id': widget.otherUserId,
        'is_typing': false,
      });
    }
    // Clear active conversation so background messages are NOT auto-marked read
    ref.read(activeChatConversationId.notifier).set(null);
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged(String text) {
    final hasText = text.trim().isNotEmpty;
    final ws = ref.read(webSocketProvider);
    if (ws == null) return;

    if (hasText && !_isTyping) {
      setState(() {
        _isTyping = true;
      });
      ws.sendMessage('user_typing', {
        'recipient_id': widget.otherUserId,
        'is_typing': true,
      });
      _lastTypingSent = DateTime.now();
    } else if (!hasText && _isTyping) {
      setState(() {
        _isTyping = false;
      });
      ws.sendMessage('user_typing', {
        'recipient_id': widget.otherUserId,
        'is_typing': false,
      });
      _lastTypingSent = null;
    } else if (hasText && _isTyping) {
      final now = DateTime.now();
      if (_lastTypingSent == null || now.difference(_lastTypingSent!).inSeconds > 3) {
        ws.sendMessage('user_typing', {
          'recipient_id': widget.otherUserId,
          'is_typing': true,
        });
        _lastTypingSent = now;
      }
    }
  }

  String _formatLastSeen(DateTime? lastSeen) {
    if (lastSeen == null) return 'Çevrimdışı';
    final now = DateTime.now();
    final difference = now.difference(lastSeen);

    if (difference.inMinutes < 1) {
      return 'Son görülme: Az önce';
    } else if (difference.inHours < 1) {
      return 'Son görülme: ${difference.inMinutes} dk. önce';
    } else if (lastSeen.day == now.day && lastSeen.month == now.month && lastSeen.year == now.year) {
      final hour = lastSeen.hour.toString().padLeft(2, '0');
      final minute = lastSeen.minute.toString().padLeft(2, '0');
      return 'Son görülme: Bugün $hour:$minute';
    } else {
      final yesterday = now.subtract(const Duration(days: 1));
      if (lastSeen.day == yesterday.day && lastSeen.month == yesterday.month && lastSeen.year == yesterday.year) {
        final hour = lastSeen.hour.toString().padLeft(2, '0');
        final minute = lastSeen.minute.toString().padLeft(2, '0');
        return 'Son görülme: Dün $hour:$minute';
      } else {
        final day = lastSeen.day.toString().padLeft(2, '0');
        final month = lastSeen.month.toString().padLeft(2, '0');
        final hour = lastSeen.hour.toString().padLeft(2, '0');
        final minute = lastSeen.minute.toString().padLeft(2, '0');
        final year = lastSeen.year.toString();
        return 'Son görülme: $day.$month.$year $hour:$minute';
      }
    }
  }

  Widget _buildSubHeader(ConversationModel conv, bool isTyping) {
    if (conv.isGroup) {
      return Text(
        conv.otherDisplayName ?? 'Grup',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.inter(
          fontSize: 12,
          color: AppColors.textSecondary,
        ),
      );
    }

    if (isTyping) {
      return const _PulsingTypingIndicator();
    }

    if (conv.isOnline) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.success.withValues(alpha: 0.5),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
          const SizedBox(width: 5),
          Text(
            'Çevrimiçi',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.success,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    return Text(
      _formatLastSeen(conv.lastSeenAt),
      style: GoogleFonts.inter(
        fontSize: 12,
        color: AppColors.textSecondary,
      ),
    );
  }

  /// Sends read receipts for every message from the other user that is not yet read.
  void _markAllUnreadMessagesRead() {
    final myUserId = ref.read(authProvider).userId ?? '';
    final messages = ref.read(chatProvider(widget.otherUserId));
    final ws = ref.read(webSocketProvider);
    if (ws == null) return;

    for (final msg in messages) {
      // Only send read receipt for messages THEY sent TO us that we haven't read
      if (msg.senderId != myUserId && msg.readAt == null) {
        ws.sendMessage('message_read', {'message_id': msg.id});
      }
    }
  }

  void _sendMessage() {
    if (_controller.text.trim().isEmpty) return;
    
    // Read the real authenticated user ID from the auth provider
    final myUserId = ref.read(authProvider).userId ?? '';
    
    final msg = MessageModel(
      id: const Uuid().v4(),
      conversationId: widget.otherUserId, 
      senderId: myUserId, 
      recipientId: widget.otherUserId,
      ciphertext: '...', 
      plaintext: _controller.text.trim(),
      msgType: 'text',
      createdAt: DateTime.now(),
    );

    ref.read(chatProvider(widget.otherUserId).notifier).addMessage(msg);
    _controller.clear();
    HapticFeedback.lightImpact();

    if (_isTyping) {
      _isTyping = false;
      _lastTypingSent = null;
      final ws = ref.read(webSocketProvider);
      ws?.sendMessage('user_typing', {
        'recipient_id': widget.otherUserId,
        'is_typing': false,
      });
    }
    
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatProvider(widget.otherUserId));
    final conversations = ref.watch(conversationProvider);
    final contactsState = ref.watch(contactsProvider);
    final isTyping = ref.watch(typingProvider(widget.otherUserId));
    // Get the real user ID for isMe detection
    final myUserId = ref.watch(authProvider).userId ?? '';

    // 1. Find default conversation username
    final conv = conversations.firstWhere(
      (c) => c.otherUserId == widget.otherUserId,
      orElse: () => ConversationModel(
        id: '',
        otherUserId: widget.otherUserId,
        otherUsername: 'Kullanıcı',
      ),
    );

    // 2. Recessive name override lookup in address book
    String displayName = conv.otherDisplayName ?? conv.otherUsername;
    for (var contact in contactsState.localContacts) {
      if (contact.isActive && contact.userId == widget.otherUserId) {
        displayName = contact.name;
        break;
      }
    }

    final isPendingRequest = conv.friendshipStatus == 'pending' && conv.initiatorId != myUserId;
    final isBlockedByMe = conv.friendshipStatus == 'blocked' && conv.initiatorId == myUserId;
    final isBlockedByThem = conv.friendshipStatus == 'blocked' && conv.initiatorId != myUserId;

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: _buildAppBar(displayName, conv, isTyping),
      body: Column(
        children: [
          if (messages.any((m) => m.isPinned))
            _buildPinnedMessageBanner(
              messages.where((m) => m.isPinned).toList(),
            ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final m = messages[index];
                final isMe = m.senderId == myUserId;
                final showDate = index == 0 ||
                    m.createdAt.difference(messages[index - 1].createdAt).inMinutes > 30;

                // Her mesaj için bir GlobalKey — scroll-to-message için
                _messageKeys[m.id] ??= GlobalKey();

                return Column(
                  key: _messageKeys[m.id],
                  children: [
                    if (showDate) _buildDateChip(m.createdAt),
                    _MessageBubble(message: m, isMe: isMe),
                  ],
                );
              },
            ),
          ),
          if (isBlockedByMe)
            _buildBlockedByMeBar()
          else if (isBlockedByThem)
            _buildBlockedByThemBar()
          else if (isPendingRequest)
            _buildAcceptDeclineBar()
          else
            _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildPinnedMessageBanner(List<MessageModel> pinnedMsgs) {
    if (pinnedMsgs.isEmpty) return const SizedBox.shrink();

    // Döngüsel index güvencesi
    final safeIndex = _pinnedMessageIndex.clamp(0, pinnedMsgs.length - 1);
    final msg = pinnedMsgs[safeIndex];
    final hasMultiple = pinnedMsgs.length > 1;

    return GestureDetector(
      onTap: () {
        // Banner'a tıklanınca o mesaja kaydır
        final key = _messageKeys[msg.id];
        if (key?.currentContext != null) {
          Scrollable.ensureVisible(
            key!.currentContext!,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            alignment: 0.3,
          );
        }
        // Birden fazla pin varsa sonrakine geç
        if (hasMultiple) {
          setState(() {
            _pinnedMessageIndex = (_pinnedMessageIndex + 1) % pinnedMsgs.length;
          });
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: const BoxDecoration(
          color: AppColors.bgElevated,
          border: Border(bottom: BorderSide(color: AppColors.glassBorder, width: 0.5)),
        ),
        child: Row(
          children: [
            // Çoklu pin göstergesi — dikey çizgiler
            if (hasMultiple)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(pinnedMsgs.length.clamp(0, 4), (i) {
                    return Container(
                      width: 3,
                      height: 8,
                      margin: const EdgeInsets.symmetric(vertical: 1),
                      decoration: BoxDecoration(
                        color: i == safeIndex
                            ? AppColors.accent
                            : AppColors.textMuted.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    );
                  }),
                ),
              ),
            const Icon(Icons.push_pin, color: AppColors.accent, size: 16),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasMultiple
                        ? 'Sabitlenmiş Mesaj ${safeIndex + 1}/${pinnedMsgs.length}'
                        : 'Sabitlenmiş Mesaj',
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    msg.plaintext ?? 'Medya Mesajı',
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () {
                ref.read(chatProvider(msg.conversationId).notifier).unpinMessage(msg.id);
                // Kalan pin sayısını güncelle
                if (_pinnedMessageIndex >= pinnedMsgs.length - 1) {
                  setState(() => _pinnedMessageIndex = 0);
                }
              },
              child: const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.close, color: AppColors.textMuted, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAcceptDeclineBar() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(context).padding.bottom + 20,
          ),
          decoration: BoxDecoration(
            color: AppColors.glassDark.withValues(alpha: 0.8),
            border: const Border(
              top: BorderSide(color: AppColors.glassBorder, width: 0.5),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Bu kullanıcıdan gelen mesaj isteğini kabul etmek istiyor musunuz?',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () async {
                  await ref.read(chatProvider(widget.otherUserId).notifier).acceptRequest();
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.accent, AppColors.accentSecondary],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      'Kabul Et',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        await ref.read(chatProvider(widget.otherUserId).notifier).rejectRequest();
                        if (mounted) {
                          Navigator.pop(context);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.glassMedium,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.glassBorder, width: 0.5),
                        ),
                        child: Center(
                          child: Text(
                            'Reddet',
                            style: GoogleFonts.inter(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        await ref.read(chatProvider(widget.otherUserId).notifier).blockUser();
                        if (mounted) {
                          Navigator.pop(context);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.withValues(alpha: 0.3), width: 0.5),
                        ),
                        child: Center(
                          child: Text(
                            'Engelle',
                            style: GoogleFonts.inter(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBlockedByMeBar() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(context).padding.bottom + 20,
          ),
          decoration: BoxDecoration(
            color: AppColors.glassDark.withValues(alpha: 0.8),
            border: const Border(
              top: BorderSide(color: AppColors.glassBorder, width: 0.5),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Bu kullanıcıyı engellediniz. Mesaj gönderebilmek için engeli kaldırmanız gerekmektedir.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () async {
                  await ref.read(chatProvider(widget.otherUserId).notifier).unblockUser();
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.accent, AppColors.accentSecondary],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      'Engeli Kaldır',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
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

  Widget _buildBlockedByThemBar() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            20,
            24,
            20,
            MediaQuery.of(context).padding.bottom + 24,
          ),
          decoration: BoxDecoration(
            color: AppColors.glassDark.withValues(alpha: 0.8),
            border: const Border(
              top: BorderSide(color: AppColors.glassBorder, width: 0.5),
            ),
          ),
          child: Center(
            child: Text(
              'Bu kullanıcıya mesaj gönderemezsiniz.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: AppColors.textMuted,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(String displayName, ConversationModel conv, bool isTyping) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: AppBar(
            backgroundColor: AppColors.bgBase.withValues(alpha: 0.75),
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            centerTitle: false,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: AppColors.textPrimary),
              onPressed: () => Navigator.pop(context),
            ),
            title: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: conv.isGroup
                          ? [const Color(0xFFA855F7), const Color(0xFF6B21A8)]
                          : [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (conv.isGroup ? const Color(0xFF6B21A8) : const Color(0xFF6366F1)).withValues(alpha: 0.3),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Center(
                    child: conv.isGroup
                        ? const Icon(Icons.group_rounded, color: Colors.white, size: 20)
                        : Text(
                            displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                    _buildSubHeader(conv, isTyping),
                  ],
                ),
              ],
            ),
            actions: [
              if (conv.isGroup) ...[
                _GlassIconBtn(
                  icon: Icons.info_outline_rounded,
                  onTap: () => context.push('/app/groups/${conv.id}/settings'),
                ),
              ] else ...[
                _GlassIconBtn(
                  icon: conv.disappearingDuration > 0
                      ? Icons.timer_rounded
                      : Icons.timer_outlined,
                  onTap: () => _showDisappearingMessagesSelector(conv),
                ),
                const SizedBox(width: 6),
                _GlassIconBtn(
                  icon: Icons.videocam_rounded,
                  onTap: () => ref.read(callProvider.notifier).startCall(
                    peerId: widget.otherUserId,
                    peerName: displayName,
                    type: CallType.video,
                  ),
                ),
                const SizedBox(width: 6),
                _GlassIconBtn(
                  icon: Icons.call_rounded,
                  onTap: () => ref.read(callProvider.notifier).startCall(
                    peerId: widget.otherUserId,
                    peerName: displayName,
                    type: CallType.audio,
                  ),
                ),
              ],
              const SizedBox(width: 4),
              if (!conv.isGroup)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: AppColors.textPrimary),
                  color: AppColors.bgElevated,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  onSelected: (value) async {
                    if (value == 'unmute') {
                      await ref.read(messageServiceProvider).unmuteChat(widget.otherUserId);
                      // Refresh conversation list to update UI
                      ref.read(conversationProvider.notifier).loadConversations();
                    } else {
                      await ref.read(messageServiceProvider).muteChat(widget.otherUserId, value);
                      ref.read(conversationProvider.notifier).loadConversations();
                    }
                  },
                  itemBuilder: (context) {
                    if (conv.isMuted) {
                      return [
                        PopupMenuItem(
                          value: 'unmute',
                          child: Row(
                            children: [
                              const Icon(Icons.notifications_active, color: AppColors.accent, size: 20),
                              const SizedBox(width: 12),
                              Text("Sessizden Çıkar", style: GoogleFonts.inter(color: Colors.white)),
                            ],
                          ),
                        ),
                      ];
                    }
                    return [
                      PopupMenuItem(
                        value: '8_hours',
                        child: Row(
                          children: [
                            const Icon(Icons.notifications_off, color: Colors.white70, size: 20),
                            const SizedBox(width: 12),
                            Text("8 Saat Sessize Al", style: GoogleFonts.inter(color: Colors.white)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: '1_week',
                        child: Row(
                          children: [
                            const Icon(Icons.notifications_off, color: Colors.white70, size: 20),
                            const SizedBox(width: 12),
                            Text("1 Hafta Sessize Al", style: GoogleFonts.inter(color: Colors.white)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'forever',
                        child: Row(
                          children: [
                            const Icon(Icons.notifications_off, color: Colors.white70, size: 20),
                            const SizedBox(width: 12),
                            Text("Süresiz Sessize Al", style: GoogleFonts.inter(color: Colors.white)),
                          ],
                        ),
                      ),
                    ];
                  },
                ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _showDisappearingMessagesSelector(ConversationModel conv) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              color: AppColors.bgBase.withValues(alpha: 0.85),
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.glassBorder,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Süreli Mesajlar',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Bu sohbetteki yeni mesajlar seçtiğiniz süre sonunda iki taraftan da otomatik olarak silinir.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _disappearingOption(context, 'Kapat', 0, conv.disappearingDuration),
                  const _BottomSheetDivider(),
                  _disappearingOption(context, '24 Saat', 86400, conv.disappearingDuration),
                  const _BottomSheetDivider(),
                  _disappearingOption(context, '7 Gün', 604800, conv.disappearingDuration),
                  const _BottomSheetDivider(),
                  _disappearingOption(context, '90 Gün', 7776000, conv.disappearingDuration),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _disappearingOption(BuildContext context, String label, int seconds, int current) {
    final isSelected = current == seconds;
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        ref.read(chatProvider(widget.otherUserId).notifier).updateDisappearingDuration(seconds);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppColors.accentLight : AppColors.textPrimary,
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, color: AppColors.accent, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDateChip(DateTime date) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.glassMedium,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.glassBorder, width: 0.5),
              ),
              child: Text(
                'Bugün ${date.hour.toString().padLeft(2,'0')}:${date.minute.toString().padLeft(2, '0')}',
                style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showAttachmentMenu() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.bgElevated.withValues(alpha: 0.92),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                border: Border.all(color: AppColors.glassBorder, width: 0.5),
              ),
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: AppColors.textMuted.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Text(
                    'Dosya Ekle',
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildAttachmentOption(
                        icon: Icons.image_rounded,
                        label: 'Galeri',
                        gradient: const LinearGradient(
                          colors: [Color(0xFF3B82F6), Color(0xFF6366F1)],
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          _pickAndSendFile(FileType.image);
                        },
                      ),
                      const SizedBox(width: 24),
                      _buildAttachmentOption(
                        icon: Icons.insert_drive_file_rounded,
                        label: 'Belge',
                        gradient: const LinearGradient(
                          colors: [Color(0xFF10B981), Color(0xFF06B6D4)],
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          _pickAndSendFile(FileType.any);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required String label,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: gradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: GoogleFonts.inter(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndSendFile(FileType type) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: type,
        withData: true,
      );

      if (!mounted) return;
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final fileBytes = file.bytes;
      if (fileBytes == null) {
        throw 'Dosya okunamadı';
      }

      final filename = file.name;
      final ext = filename.split('.').last.toLowerCase();
      
      int maxSize = 10 * 1024 * 1024; // Default 10MB
      if (ext == 'mp4' || ext == 'mov' || ext == 'avi') {
        maxSize = 50 * 1024 * 1024; // 50MB for video
      } else if (ext == 'pdf' || ext == 'doc' || ext == 'docx' || ext == 'txt') {
        maxSize = 20 * 1024 * 1024; // 20MB for documents
      }

      if (fileBytes.length > maxSize) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Dosya boyutu limitleri aşıyor (Maks: ${maxSize ~/ (1024 * 1024)}MB)')),
        );
        return;
      }

      String mimeType = 'application/octet-stream';
      if (type == FileType.image) {
        final ext = filename.split('.').last.toLowerCase();
        if (ext == 'png') {
          mimeType = 'image/png';
        } else if (ext == 'jpg' || ext == 'jpeg') {
          mimeType = 'image/jpeg';
        } else if (ext == 'gif') {
          mimeType = 'image/gif';
        } else if (ext == 'webp') {
          mimeType = 'image/webp';
        } else {
          mimeType = 'image/jpeg';
        }
      } else {
        if (ext == 'pdf') {
          mimeType = 'application/pdf';
        } else if (ext == 'doc' || ext == 'docx') {
          mimeType = 'application/msword';
        } else if (ext == 'txt') {
          mimeType = 'text/plain';
        } else if (ext == 'mp4') {
          mimeType = 'video/mp4';
        }
      }

      await ref.read(chatProvider(widget.otherUserId).notifier).sendMediaMessage(
        fileBytes: fileBytes,
        filename: filename,
        mimeType: mimeType,
        fileSize: fileBytes.length,
      );

      if (!mounted) return;
      _scrollToBottom();
    } catch (e) {
      debugPrint('Dosya seçme/gönderme hatası: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dosya gönderilemedi: $e')),
      );
    }
  }

  Widget _buildInputArea() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            12,
            10,
            12,
            MediaQuery.of(context).padding.bottom + 10,
          ),
          decoration: BoxDecoration(
            color: AppColors.bgBase.withValues(alpha: 0.8),
            border: const Border(top: BorderSide(color: AppColors.glassBorder, width: 0.5)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Attachment button
              GestureDetector(
                onTap: _showAttachmentMenu,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.glassMedium,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.glassBorder, width: 0.5),
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        color: AppColors.textSecondary,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Text input
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.glassMedium,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: AppColors.glassBorder, width: 0.5),
                      ),
                      child: TextField(
                        controller: _controller,
                        maxLines: null,
                        onChanged: _onTextChanged,
                        style: GoogleFonts.inter(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Mesaj yaz...',
                          hintStyle: TextStyle(color: AppColors.textMuted),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Send button
              GestureDetector(
                onTap: _sendMessage,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.arrow_upward_rounded, size: 22, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends ConsumerWidget {
  final MessageModel message;
  final bool isMe;

  const _MessageBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plaintext = message.plaintext;
    final msgType = message.msgType;

    Widget bubbleContent;

    if (msgType == 'deleted') {
      bubbleContent = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.delete_outline,
            size: 16,
            color: isMe ? Colors.white.withValues(alpha: 0.6) : AppColors.textMuted,
          ),
          const SizedBox(width: 6),
          Text(
            'Bu mesaj silindi',
            style: GoogleFonts.inter(
              color: isMe ? Colors.white.withValues(alpha: 0.6) : AppColors.textMuted,
              fontSize: 14,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      );
    } else if (msgType == 'call_log') {
      bubbleContent = _buildCallLogBubble(context, plaintext);
    } else if (msgType == 'group_invite') {
      bubbleContent = _buildGroupInviteBubble(context, ref, plaintext);
    } else if ((msgType == 'image' || msgType == 'file') && plaintext != null && plaintext.trim().startsWith('{')) {
      try {
        final mediaData = jsonDecode(plaintext);
        final status = mediaData['status'] as String?;

        if (status == 'uploading') {
          final progressMap = ref.watch(uploadProgressProvider);
          final progress = progressMap[message.id] ?? 0.0;
          bubbleContent = _buildUploadingBubble(context, mediaData['filename'] ?? 'Dosya', progress);
        } else if (status == 'failed') {
          bubbleContent = _buildFailedBubble(context, mediaData['filename'] ?? 'Dosya', mediaData['error']);
        } else {
          final filename = mediaData['filename'] as String? ?? 'Dosya';
          final mediaUrl = mediaData['media_url'] as String? ?? '';
          final mediaKey = mediaData['media_key'] as String? ?? '';
          final mimeType = mediaData['mime_type'] as String? ?? 'application/octet-stream';
          final size = mediaData['size'] as int? ?? 0;

          if (mimeType.startsWith('image/')) {
            bubbleContent = _buildImageBubble(context, ref, mediaUrl, mediaKey, filename, size);
          } else {
            bubbleContent = _buildFileBubble(context, ref, mediaUrl, mediaKey, filename, size);
          }
        }
      } catch (e) {
        bubbleContent = _buildTextBubble(plaintext);
      }
    } else {
      bubbleContent = _buildTextBubble(plaintext ?? '[Şifreli]');
    }

    final reactionsRow = _buildReactionsRow(context, message);

    Widget? senderHeader;
    if (!isMe) {
      final conversations = ref.watch(conversationProvider);
      final conv = conversations.firstWhere(
        (c) => c.otherUserId == message.conversationId,
        orElse: () => ConversationModel(id: '', otherUserId: message.conversationId, otherUsername: ''),
      );
      if (conv.isGroup) {
        final contactsState = ref.watch(contactsProvider);
        String name = message.senderName ?? 'Kullanıcı';
        for (var contact in contactsState.localContacts) {
          if (contact.isActive && contact.userId == message.senderId) {
            name = contact.name;
            break;
          }
        }
        final colorHash = message.senderId.hashCode.abs();
        final colors = [
          Colors.blueAccent,
          Colors.tealAccent,
          Colors.orangeAccent,
          Colors.purpleAccent,
          Colors.pinkAccent,
          Colors.amberAccent,
          Colors.lightBlueAccent,
          Colors.deepOrangeAccent,
        ];
        final senderColor = colors[colorHash % colors.length];
        senderHeader = Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            name,
            style: GoogleFonts.inter(
              color: senderColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        );
      }
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showBubbleMenu(context, ref, message, isMe),
        child: ClipRRect(
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(22),
            topRight: const Radius.circular(22),
            bottomLeft: Radius.circular(isMe ? 22 : 6),
            bottomRight: Radius.circular(isMe ? 6 : 22),
          ),
          child: BackdropFilter(
            filter: isMe
                ? ImageFilter.blur(sigmaX: 0, sigmaY: 0)
                : ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
              decoration: BoxDecoration(
                gradient: isMe
                    ? const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isMe ? null : AppColors.glassMedium,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(22),
                  topRight: const Radius.circular(22),
                  bottomLeft: Radius.circular(isMe ? 22 : 6),
                  bottomRight: Radius.circular(isMe ? 6 : 22),
                ),
                border: isMe
                    ? null
                    : Border.all(color: AppColors.glassBorder, width: 0.5),
                boxShadow: isMe
                    ? [
                        BoxShadow(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        )
                      ]
                    : null,
              ),
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (senderHeader != null) senderHeader,
                  bubbleContent,
                  if (reactionsRow != null) reactionsRow,
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 📌 Sabitlenmiş mesaj ikonu
                      if (message.isPinned) ...[
                        Icon(
                          Icons.push_pin,
                          size: 11,
                          color: isMe
                              ? Colors.white.withValues(alpha: 0.65)
                              : AppColors.accent.withValues(alpha: 0.8),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        '${message.createdAt.hour.toString().padLeft(2, '0')}:${message.createdAt.minute.toString().padLeft(2, '0')}',
                        style: GoogleFonts.inter(
                          color: isMe ? Colors.white.withValues(alpha: 0.5) : AppColors.textMuted,
                          fontSize: 10,
                        ),
                      ),
                      if (message.editedAt != null) ...[
                        const SizedBox(width: 4),
                        Text(
                          '(düzenlendi)',
                          style: GoogleFonts.inter(
                            color: isMe ? Colors.white.withValues(alpha: 0.5) : AppColors.textMuted,
                            fontSize: 9,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                      if (message.expiresAt != null) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.timer_outlined,
                          size: 11,
                          color: isMe ? Colors.white.withValues(alpha: 0.5) : AppColors.textMuted,
                        ),
                      ],
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        _buildStatusTicks(),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Renders WhatsApp-style status ticks for messages sent by the current user.
  /// ✓      = sent (no deliveredAt, no readAt)
  /// ✓✓ gray = delivered (has deliveredAt, no readAt)
  /// ✓✓ blue = read    (has readAt)
  Widget _buildStatusTicks() {
    if (message.readAt != null) {
      // ✓✓ blue — read
      return const Icon(Icons.done_all_rounded, size: 15, color: Color(0xFF60A5FA));
    } else if (message.deliveredAt != null) {
      // ✓✓ gray — delivered
      return Icon(Icons.done_all_rounded, size: 15, color: Colors.white.withValues(alpha: 0.55));
    } else {
      // ✓ — sent/saving
      return Icon(Icons.done_rounded, size: 15, color: Colors.white.withValues(alpha: 0.45));
    }
  }

  Widget _buildGroupInviteBubble(BuildContext context, WidgetRef ref, String? plaintext) {
    if (plaintext == null) return const SizedBox();
    try {
      final data = jsonDecode(plaintext);
      final groupId = data['group_id'] as String;
      final groupName = data['group_name'] as String;
      final token = data['invite_token'] as String;

      final conversations = ref.watch(conversationProvider);
      final isMember = conversations.any((c) => c.isGroup && c.otherUserId == groupId);

      return Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.group_add_rounded, color: AppColors.accentLight, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Grup Daveti',
                    style: GoogleFonts.inter(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'You are invited to join the group "$groupName".',
              style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            isMember
                ? Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                    ),
                    child: Center(
                      child: Text(
                        'Katılındı',
                        style: GoogleFonts.inter(
                          color: AppColors.success,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  )
                : GestureDetector(
                    onTap: () async {
                      try {
                        final service = ref.read(messageServiceProvider);
                        await service.joinGroupByInvite(token);
                        // Refresh conversations
                        ref.read(conversationProvider.notifier).loadConversations();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Gruba başarıyla katıldınız!')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Hata: $e')),
                          );
                        }
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.accent, AppColors.accentSecondary],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          'Gruba Katıl',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
          ],
        ),
      );
    } catch (_) {
      return const Text('[Geçersiz Grup Daveti]');
    }
  }

  Widget _buildCallLogBubble(BuildContext context, String? plaintext) {
    if (plaintext == null) return const SizedBox();
    try {
      final payload = jsonDecode(plaintext);
      final isVideo = payload['type'] == 'video';
      final duration = payload['duration'] as int? ?? 0;
      final status = payload['status'] as String? ?? 'ended';
      final direction = payload['direction'] as String? ?? 'incoming';

      final isMissed = status == 'missed';
      final isOutgoing = direction == 'outgoing';

      final IconData callIcon;
      if (isVideo) {
        callIcon = isMissed 
            ? Icons.missed_video_call_rounded 
            : Icons.video_call_rounded;
      } else {
        callIcon = isMissed 
            ? Icons.phone_missed_rounded 
            : (isOutgoing ? Icons.phone_forwarded_rounded : Icons.phone_callback_rounded);
      }

      final Color iconColor;
      if (isMissed) {
        iconColor = AppColors.danger;
      } else {
        iconColor = AppColors.success;
      }

      final String statusText;
      if (isMissed) {
        statusText = 'Cevapsız Arama';
      } else {
        final minutes = duration ~/ 60;
        final seconds = duration % 60;
        final durationStr = minutes > 0 ? '$minutes dk $seconds sn' : '$seconds sn';
        statusText = isOutgoing ? 'Giden Arama ($durationStr)' : 'Gelen Arama ($durationStr)';
      }

      return Container(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: iconColor.withValues(alpha: 0.15),
              ),
              child: Icon(callIcon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isVideo ? 'Görüntülü Arama' : 'Sesli Arama',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: isMe ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  statusText,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: isMe ? Colors.white.withValues(alpha: 0.7) : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    } catch (e) {
      return _buildTextBubble('[Arama Kaydı]');
    }
  }

  Widget? _buildReactionsRow(BuildContext context, MessageModel message) {
    final reactions = message.reactionsMap;
    if (reactions.isEmpty) return null;

    return Container(
      margin: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: reactions.entries.map((entry) {
          final emoji = entry.key;
          final userList = entry.value;
          final count = userList.length;

          return ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isMe ? Colors.white.withValues(alpha: 0.15) : AppColors.glassLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isMe ? Colors.white.withValues(alpha: 0.2) : AppColors.glassBorder,
                    width: 0.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 11)),
                    if (count > 1) ...[
                      const SizedBox(width: 3),
                      Text(
                        '$count',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: isMe ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showBubbleMenu(BuildContext context, WidgetRef ref, MessageModel msg, bool isMe) {
    if (msg.msgType == 'deleted') return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isWithin15Mins = DateTime.now().difference(msg.createdAt).inMinutes < 15;
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.bgElevated.withValues(alpha: 0.92),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                border: Border.all(color: AppColors.glassBorder, width: 0.5),
              ),
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: AppColors.textMuted.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: ['👍', '❤️', '😂', '😮', '😢', '🙏'].map((emoji) {
                      return GestureDetector(
                        onTap: () {
                          Navigator.pop(ctx);
                          ref.read(chatProvider(msg.conversationId).notifier).toggleReaction(msg.id, emoji);
                        },
                        child: Text(emoji, style: const TextStyle(fontSize: 28)),
                      );
                    }).toList(),
                  ),
                  const Divider(height: 32, color: Colors.white12),
                  if (!isMe) ...[
                    ListTile(
                      leading: const Icon(Icons.report_problem, color: Colors.redAccent),
                      title: const Text('Şikayet Et', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                      subtitle: const Text('Spam, taciz veya suistimali bildir', style: TextStyle(color: Colors.white54, fontSize: 11)),
                      onTap: () {
                        Navigator.pop(ctx);
                        showDialog(
                          context: context,
                          builder: (_) => ReportDialog(reportedUserId: msg.senderId),
                        );
                      },
                    ),
                    const Divider(height: 16, color: Colors.white12),
                  ],
                  ListTile(
                    leading: Icon(
                      msg.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                      color: AppColors.accent,
                    ),
                    title: Text(msg.isPinned ? 'Sabitlemeyi Kaldır' : 'Sabitle', style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold)),
                    subtitle: Text(msg.isPinned ? 'Mesajı sabitlemekten vazgeç' : 'Sohbette öne çıkar', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                    onTap: () {
                      Navigator.pop(ctx);
                      if (msg.isPinned) {
                        ref.read(chatProvider(msg.conversationId).notifier).unpinMessage(msg.id);
                      } else {
                        ref.read(chatProvider(msg.conversationId).notifier).pinMessage(msg.id);
                      }
                    },
                  ),
                  const Divider(height: 16, color: Colors.white12),
                  ListTile(
                    leading: const Icon(Icons.delete_outline, color: Colors.white70),
                    title: const Text('Benden Sil', style: TextStyle(color: Colors.white)),
                    subtitle: const Text('Mesajı yalnızca bu cihazdan siler', style: TextStyle(color: Colors.white54, fontSize: 11)),
                    onTap: () {
                      Navigator.pop(ctx);
                      ref.read(chatProvider(msg.conversationId).notifier).deleteMessageForMe(msg.id);
                    },
                  ),
                  if (isMe) ...[
                    const Divider(height: 16, color: Colors.white12),
                    if (isWithin15Mins) ...[
                      ListTile(
                        leading: const Icon(Icons.edit_outlined, color: Colors.white),
                        title: const Text('Düzenle', style: TextStyle(color: Colors.white)),
                        subtitle: const Text('Mesajı düzenle', style: TextStyle(color: Colors.white54, fontSize: 11)),
                        onTap: () {
                          Navigator.pop(ctx);
                          _showEditDialog(context, ref, msg);
                        },
                      ),
                      const Divider(height: 16, color: Colors.white12),
                    ],
                    ListTile(
                      leading: Icon(
                        Icons.delete_forever,
                        color: isWithin15Mins ? Colors.redAccent : Colors.white30,
                      ),
                      title: Text(
                        'Herkesten Sil',
                        style: TextStyle(
                          color: isWithin15Mins ? Colors.redAccent : Colors.white30,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        isWithin15Mins 
                            ? 'Mesajı hem sizin hem de karşı tarafın cihazından siler' 
                            : 'Geri çekme süresi doldu (Maks. 15 dakika)',
                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                      onTap: isWithin15Mins
                          ? () {
                              Navigator.pop(ctx);
                              ref.read(chatProvider(msg.conversationId).notifier).deleteMessageForEveryone(msg.id);
                            }
                          : null,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, MessageModel msg) {
    final controller = TextEditingController(text: msg.plaintext);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgElevated,
        title: Text('Mesajı Düzenle', style: GoogleFonts.inter(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: GoogleFonts.inter(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Yeni mesaj...',
            hintStyle: TextStyle(color: AppColors.textMuted),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.glassBorder)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.accent)),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              final newText = controller.text.trim();
              if (newText.isNotEmpty && newText != msg.plaintext) {
                ref.read(chatProvider(msg.conversationId).notifier).editMessage(msg.id, newText);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Kaydet', style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );
  }


  Widget _buildTextBubble(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        color: isMe ? Colors.white : AppColors.textPrimary,
        fontSize: 15,
        height: 1.4,
      ),
    );
  }

  Widget _buildUploadingBubble(BuildContext context, String filename, double progress) {
    return Container(
      width: 200,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: progress,
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(isMe ? Colors.white70 : AppColors.accent),
                backgroundColor: isMe ? Colors.white24 : AppColors.bgElevated,
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: GoogleFonts.inter(
                  color: isMe ? Colors.white : AppColors.textPrimary,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Yükleniyor...',
                  style: GoogleFonts.inter(
                    color: isMe ? Colors.white : AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  filename,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: isMe ? Colors.white70 : AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFailedBubble(BuildContext context, String filename, String? error) {
    return Container(
      width: 200,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.redAccent,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Yükleme Başarısız',
                  style: GoogleFonts.inter(
                    color: isMe ? Colors.white : Colors.redAccent,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  filename,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: isMe ? Colors.white70 : AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageBubble(
    BuildContext context,
    WidgetRef ref,
    String mediaUrl,
    String mediaKey,
    String filename,
    int size,
  ) {
    final cachedBytes = ref.watch(decryptedMediaProvider)[mediaUrl];

    if (cachedBytes != null) {
      return GestureDetector(
        onTap: () {
          _showFullscreenImage(context, cachedBytes, filename);
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(
            cachedBytes,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return _buildErrorPlaceholder(filename);
            },
          ),
        ),
      );
    }

    return FutureBuilder<Uint8List>(
      future: ref.read(mediaUploadServiceProvider).downloadAndDecryptMedia(
        mediaUrl: mediaUrl,
        mediaKeyBase64: mediaKey,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            width: 200,
            height: 150,
            decoration: BoxDecoration(
              color: isMe ? Colors.white10 : AppColors.bgElevated,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        } else if (snapshot.hasError || !snapshot.hasData) {
          return _buildErrorPlaceholder(filename);
        } else {
          final bytes = snapshot.data!;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(decryptedMediaProvider.notifier).setBytes(mediaUrl, bytes);
          });

          return GestureDetector(
            onTap: () {
              _showFullscreenImage(context, bytes, filename);
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                bytes,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildErrorPlaceholder(filename);
                },
              ),
            ),
          );
        }
      },
    );
  }

  Widget _buildErrorPlaceholder(String filename) {
    return Container(
      width: 200,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.orangeAccent,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Medya Deşifre Edilemedi',
                  style: GoogleFonts.inter(
                    color: isMe ? Colors.white : AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  filename,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: isMe ? Colors.white70 : AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileBubble(
    BuildContext context,
    WidgetRef ref,
    String mediaUrl,
    String mediaKey,
    String filename,
    int size,
  ) {
    final formattedSize = _formatBytes(size);
    final cachedBytes = ref.watch(decryptedMediaProvider)[mediaUrl];

    return Container(
      width: 220,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: () async {
              if (cachedBytes != null) {
                _saveOrOpenFile(context, cachedBytes, filename);
                return;
              }

              try {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Dosya indiriliyor...')),
                );
                final bytes = await ref.read(mediaUploadServiceProvider).downloadAndDecryptMedia(
                  mediaUrl: mediaUrl,
                  mediaKeyBase64: mediaKey,
                );
                if (!context.mounted) return;
                ref.read(decryptedMediaProvider.notifier).setBytes(mediaUrl, bytes);
                _saveOrOpenFile(context, bytes, filename);
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Dosya indirilemedi: $e')),
                );
              }
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isMe ? Colors.white.withValues(alpha: 0.2) : AppColors.bgSurface,
                shape: BoxShape.circle,
              ),
              child: Icon(
                cachedBytes != null ? Icons.download_done_rounded : Icons.download_rounded,
                color: isMe ? Colors.white : AppColors.accent,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  filename,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: isMe ? Colors.white : AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  formattedSize,
                  style: GoogleFonts.inter(
                    color: isMe ? Colors.white70 : AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB"];
    var i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}';
  }

  Future<void> _saveOrOpenFile(BuildContext context, Uint8List bytes, String filename) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final safeFilename = path.basename(filename);
      final file = File('${tempDir.path}/$safeFilename');
      await file.writeAsBytes(bytes);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$safeFilename geçici dizine kaydedildi: ${tempDir.path}'),
          action: SnackBarAction(
            label: 'Tamam',
            onPressed: () {},
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dosya açılırken hata: $e')),
      );
    }
  }

  void _showFullscreenImage(BuildContext context, Uint8List bytes, String filename) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        pageBuilder: (context, _, secondaryAnimation) {
          return Scaffold(
            backgroundColor: Colors.black.withValues(alpha: 0.9),
            body: Stack(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Center(
                    child: Hero(
                      tag: filename,
                      child: InteractiveViewer(
                        minScale: 0.5,
                        maxScale: 4.0,
                        child: Image.memory(bytes),
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Expanded(
                          child: Text(
                            filename,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── Glass Icon Button (for chat app bar) ────────────────────────────────────

class _GlassIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _GlassIconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.glassMedium,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.glassBorder, width: 0.5),
            ),
            child: Icon(icon, color: AppColors.accentLight, size: 20),
          ),
        ),
      ),
    );
  }
}

class _PulsingTypingIndicator extends StatefulWidget {
  const _PulsingTypingIndicator();

  @override
  State<_PulsingTypingIndicator> createState() => _PulsingTypingIndicatorState();
}

class _PulsingTypingIndicatorState extends State<_PulsingTypingIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Yazıyor',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: AppColors.accent,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 2),
        ...List.generate(3, (index) {
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final delay = index * 0.2;
              final double value = (sin((_controller.value * 2 * pi) - (delay * pi)) + 1) / 2;
              return Container(
                width: 3.5,
                height: 3.5,
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.3 + 0.7 * value),
                  shape: BoxShape.circle,
                ),
              );
            },
          );
        }),
      ],
    );
  }
}

class _BottomSheetDivider extends StatelessWidget {
  const _BottomSheetDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 0.5,
      color: AppColors.glassBorder,
      margin: const EdgeInsets.symmetric(vertical: 4),
    );
  }
}
