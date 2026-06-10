import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/messages/providers/chat_provider.dart';
import '../../features/messages/providers/message_model.dart';
import '../../core/database/outbound_queue.dart';
import '../../features/call/providers/call_provider.dart';
import '../../features/call/models/call_session.dart';
import 'websocket_service.dart';

/// Tracks which conversation is currently open on screen.
/// When set, incoming messages from that sender are auto-marked read.
class _ActiveChatNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? id) => state = id;
}

final activeChatConversationId =
    NotifierProvider<_ActiveChatNotifier, String?>(_ActiveChatNotifier.new);

/// Notifier that holds the live WebSocket connection state.
class _WsStateNotifier extends Notifier<WsConnectionState> {
  @override
  WsConnectionState build() => WsConnectionState.disconnected;
  void set(WsConnectionState s) => state = s;
}

/// Exposes the live WebSocket connection state for UI indicators.
final wsConnectionStateProvider =
    NotifierProvider<_WsStateNotifier, WsConnectionState>(_WsStateNotifier.new);

final webSocketProvider = Provider<WebSocketService?>((ref) {
  final authState = ref.watch(authProvider);

  if (!authState.isAuthenticated) return null;

  const storage = FlutterSecureStorage();
  // Captured as a late local so it's accessible inside onMessageReceived
  // without creating a circular dependency back through webSocketProvider.
  late WebSocketService service;

  service = WebSocketService(
    tokenProvider: () => storage.read(key: 'access_token'),
    onStateChanged: (wsState) {
      // Mirror the WS state into a Riverpod-readable provider.
      ref.read(wsConnectionStateProvider.notifier).set(wsState);

      // When reconnected, flush any messages that were queued while offline.
      if (wsState == WsConnectionState.connected) {
        _flushOutboundQueue(ref, service);
      }
    },
    onMessageReceived: (data) async {
      final type = data['type'] as String?;

      // ── Incoming new message ────────────────────────────────────────────
      if (type == 'new_message') {
        final payload = data['payload'] as Map<String, dynamic>;
        final activeUserId = ref.read(authProvider).userId ?? '';
        final senderID = payload['sender_id'] as String? ?? '';
        final messageId =
            (payload['message_id'] ?? payload['id'] ?? '') as String;

        final mapped = {
          'id': messageId,
          'conversation_id': senderID,
          'sender_id': senderID,
          'recipient_id': activeUserId,
          'ciphertext': payload['ciphertext'],
          'plaintext': null,
          'msg_type': payload['msg_type'] ?? 'text',
          'ratchet_key': payload['ratchet_key'],
          'alice_identity_key': payload['alice_identity_key'],
          'alice_ephemeral_key': payload['alice_ephemeral_key'],
          'prev_counter': payload['prev_counter'],
          'counter': payload['counter'],
          'created_at': payload['created_at'] ?? DateTime.now().toIso8601String(),
          'expires_at': payload['expires_at'],
        };
        final msg = MessageModel.fromMap(mapped);

        // Decrypt and store in the correct conversation provider.
        ref.read(chatProvider(senderID).notifier).receiveMessage(msg);
        ref.read(conversationProvider.notifier).loadConversations();

        // If this conversation is currently open, auto-send a read receipt.
        final activeChatId = ref.read(activeChatConversationId);
        if (activeChatId == senderID && messageId.isNotEmpty) {
          service.sendMessage('message_read', {'message_id': messageId});
        }
      }

      // ── Incoming new group message ──────────────────────────────────────
      else if (type == 'new_group_message') {
        final payload = data['payload'] as Map<String, dynamic>;
        final groupId = payload['group_id'] as String? ?? '';
        final senderID = payload['sender_id'] as String? ?? '';
        final messageId = (payload['message_id'] ?? payload['id'] ?? '') as String;

        final mapped = {
          'id': messageId,
          'conversation_id': groupId,
          'sender_id': senderID,
          'recipient_id': groupId,
          'ciphertext': payload['ciphertext'],
          'plaintext': payload['ciphertext'], // Plaintext transport fallback
          'msg_type': payload['msg_type'] ?? 'text',
          'created_at': payload['created_at'] ?? DateTime.now().toIso8601String(),
        };
        final msg = MessageModel.fromMap(mapped);

        ref.read(chatProvider(groupId).notifier).receiveGroupMessage(msg);
        ref.read(conversationProvider.notifier).loadConversations();
      }

      // ── Read receipt — update our sent message tick status ──────────────
      else if (type == 'message_read') {
        final payload = data['payload'] as Map<String, dynamic>;
        final messageId = payload['message_id'] as String? ?? '';
        final readerId = payload['reader_id'] as String? ?? '';

        if (messageId.isEmpty || readerId.isEmpty) return;

        ref.read(chatProvider(readerId).notifier).updateMessageReadAt(messageId);
      }

      // ── Message deleted — update message locally to "Bu mesaj silindi" ──
      else if (type == 'message_deleted') {
        final payload = data['payload'] as Map<String, dynamic>;
        final messageId = payload['message_id'] as String? ?? '';
        final conversationId = payload['conversation_id'] as String? ?? '';

        if (messageId.isNotEmpty && conversationId.isNotEmpty) {
          ref.read(chatProvider(conversationId).notifier).handleMessageDeletedEvent(messageId);
        }
      }

      // ── Offline queue ACK — remove successfully delivered message ────────
      else if (type == 'message_delivered') {
        final payload = data['payload'] as Map<String, dynamic>;
        final queueId = payload['queue_id'] as String? ?? '';
        if (queueId.isNotEmpty) {
          ref.read(outboundQueueProvider.notifier).removeFromQueue(queueId);
        }
      }

      // ── Presence update event ───────────────────────────────────────────
      else if (type == 'presence') {
        final payload = data['payload'] as Map<String, dynamic>;
        final userId = payload['user_id'] as String? ?? '';
        final online = payload['online'] as bool? ?? false;
        final lastSeenAtStr = payload['last_seen_at'] as String?;

        if (userId.isNotEmpty) {
          final db = await ref.read(dbProvider.future);
          
          await db.update(
            'conversations',
            {
              'is_online': online ? 1 : 0,
              'last_seen_at': lastSeenAtStr,
            },
            where: 'other_user_id = ?',
            whereArgs: [userId],
          );

          ref.read(conversationProvider.notifier).loadConversations();
        }
      }

      // ── Typing status event ─────────────────────────────────────────────
      else if (type == 'user_typing') {
        final payload = data['payload'] as Map<String, dynamic>;
        final senderId = payload['sender_id'] as String? ?? '';
        final isTyping = payload['is_typing'] as bool? ?? false;

        if (senderId.isNotEmpty) {
          ref.read(typingProvider(senderId).notifier).setTyping(isTyping);
        }
      }

      // ── Conversation settings update event ──────────────────────────────
      else if (type == 'conversation_settings_updated') {
        final payload = data['payload'] as Map<String, dynamic>;
        final convId = payload['conversation_id'] as String? ?? '';
        final duration = payload['disappearing_duration'] as int? ?? 0;
        if (convId.isNotEmpty) {
          final db = await ref.read(dbProvider.future);
          await db.update(
            'conversations',
            {'disappearing_duration': duration},
            where: 'id = ?',
            whereArgs: [convId],
          );
          ref.read(conversationProvider.notifier).loadConversations();
        }
      }

      // ── Message Pinned/Unpinned event ───────────────────────────────────
      else if (type == 'message_pinned' || type == 'message_unpinned') {
        final payload = data['payload'] as Map<String, dynamic>;
        final messageId = payload['message_id'] as String? ?? '';
        final isPinned = payload['is_pinned'] as bool? ?? false;

        if (messageId.isNotEmpty) {
          final db = await ref.read(dbProvider.future);
          final result = await db.query(
            'messages',
            columns: ['conversation_id'],
            where: 'id = ?',
            whereArgs: [messageId],
          );
          if (result.isNotEmpty) {
            final convId = result.first['conversation_id'] as String;
            if (isPinned) {
              await ref.read(chatProvider(convId).notifier).pinMessage(messageId);
            } else {
              await ref.read(chatProvider(convId).notifier).unpinMessage(messageId);
            }
          }
        }
      }

      // ── WebRTC Call Signaling Relays ─────────────────────────────────────
      else if (type == 'incoming_call') {
        final payload = data['payload'] as Map<String, dynamic>;
        final callId = payload['call_id'] as String? ?? '';
        final callerId = payload['caller_id'] as String? ?? '';
        final sdp = payload['sdp'] as String? ?? '';
        final callTypeStr = payload['call_type'] as String? ?? 'audio';
        final callType = callTypeStr == 'video' ? CallType.video : CallType.audio;

        ref.read(callProvider.notifier).receiveOffer(
          callId: callId,
          callerId: callerId,
          sdp: sdp,
          type: callType,
        );
      }

      else if (type == 'call_accepted') {
        final payload = data['payload'] as Map<String, dynamic>;
        final callId = payload['call_id'] as String? ?? '';
        final sdp = payload['sdp'] as String? ?? '';

        ref.read(callProvider.notifier).handleCallAccepted(
          callId: callId,
          sdp: sdp,
        );
      }

      else if (type == 'call_rejected') {
        final payload = data['payload'] as Map<String, dynamic>;
        final callId = payload['call_id'] as String? ?? '';
        final reason = payload['reason'] as String? ?? '';

        ref.read(callProvider.notifier).handleCallRejected(
          callId: callId,
          reason: reason,
        );
      }

      else if (type == 'call_ended') {
        final payload = data['payload'] as Map<String, dynamic>;
        final callId = payload['call_id'] as String? ?? '';

        ref.read(callProvider.notifier).handleCallEnded(
          callId: callId,
        );
      }

      else if (type == 'ice_candidate') {
        final payload = data['payload'] as Map<String, dynamic>;
        final fromId = payload['from_id'] as String? ?? '';
        final candidate = payload['candidate'] as String? ?? '';

        ref.read(callProvider.notifier).handleIceCandidate(
          fromId: fromId,
          candidateJson: candidate,
        );
      }

      else if (type == 'call_promote') {
        final payload = data['payload'] as Map<String, dynamic>;
        final callId = payload['call_id'] as String? ?? '';
        final fromId = payload['from_id'] as String? ?? '';

        ref.read(callProvider.notifier).handleCallPromoted(
          callId: callId,
          fromId: fromId,
        );
      }

      else if (type == 'group_call_offer') {
        final payload = data['payload'] as Map<String, dynamic>;
        final groupId = payload['group_id'] as String? ?? '';
        final fromId = payload['from_id'] as String? ?? '';
        final sdp = payload['sdp'] as String? ?? '';
        final callTypeStr = payload['call_type'] as String? ?? 'audio';
        final callType = callTypeStr == 'video' ? CallType.video : CallType.audio;

        ref.read(callProvider.notifier).handleGroupCallOffer(
          callId: groupId,
          fromId: fromId,
          sdp: sdp,
          type: callType,
        );
      }

      else if (type == 'group_call_member') {
        final payload = data['payload'] as Map<String, dynamic>;
        final callId = payload['call_id'] as String? ?? '';
        final userId = payload['user_id'] as String? ?? '';
        final action = payload['action'] as String? ?? '';

        ref.read(callProvider.notifier).handleGroupCallMember(
          callId: callId,
          userId: userId,
          action: action,
        );
      }

      else if (type == 'error') {
        final payload = data['payload'] as Map<String, dynamic>;
        final errorMsg = payload['error'] as String? ?? '';
        if (errorMsg.contains('callee is offline') || 
            errorMsg.contains('callee is busy') || 
            errorMsg.contains('call_id') ||
            ref.read(callProvider) != null) {
          ref.read(callProvider.notifier).handleCallError(errorMsg);
        }
      }
    },
  );

  service.connect();

  ref.onDispose(() => service.disconnect());
  return service;
});

/// Replays all queued outbound messages over the newly-connected WebSocket.
/// Called automatically when the connection transitions to [WsConnectionState.connected].
void _flushOutboundQueue(Ref ref, WebSocketService service) async {
  final queue = ref.read(outboundQueueProvider);
  if (queue.isEmpty) return;

  for (final item in queue) {
    if (!service.isConnected) break; // Stop if connection drops mid-flush.
    try {
      if (item.payload.containsKey('group_id')) {
        service.sendMessage('send_group_message', item.payload);
        ref.read(outboundQueueProvider.notifier).removeFromQueue(item.id);
      } else {
        service.sendMessage('send_message', item.payload);
      }
      // Note: direct message item is only removed from queue when the server sends a
      // message_delivered ACK (handled in onMessageReceived above).
    } catch (e) {
      // Increment retry counter; item will be pruned after 5 failures.
      ref.read(outboundQueueProvider.notifier).markRetried(item.id);
    }
  }
}
