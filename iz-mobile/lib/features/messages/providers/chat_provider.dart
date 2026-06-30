import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'message_model.dart';
import 'message_repository.dart';
import 'message_service.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/outbound_queue.dart';
import '../../../core/crypto/crypto_providers.dart';

import '../../../core/network/websocket_provider.dart';
import '../../../core/network/dio_provider.dart';
import '../../auth/providers/account_provider.dart';
import '../../auth/providers/auth_provider.dart';
import 'p2p_provider.dart';

import 'dart:convert';
import 'dart:async';
import 'package:uuid/uuid.dart';
import 'media_upload_service.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'group_crypto_service.dart';

class DecryptedMediaNotifier extends Notifier<Map<String, Uint8List>> {
  @override
  Map<String, Uint8List> build() => {};

  void setBytes(String url, Uint8List bytes) {
    state = {...state, url: bytes};
  }
}

final decryptedMediaProvider = NotifierProvider<DecryptedMediaNotifier, Map<String, Uint8List>>(
  DecryptedMediaNotifier.new,
);

class UploadProgressNotifier extends Notifier<Map<String, double>> {
  @override
  Map<String, double> build() => {};

  void setProgress(String messageId, double progress) {
    state = {...state, messageId: progress};
  }

  void removeProgress(String messageId) {
    final newState = Map<String, double>.from(state);
    newState.remove(messageId);
    state = newState;
  }
}

final uploadProgressProvider = NotifierProvider<UploadProgressNotifier, Map<String, double>>(
  UploadProgressNotifier.new,
);


// Provider for the database service - properly async
final dbProvider = FutureProvider((ref) async {
  final activeId = ref.watch(accountProvider).activeAccountId ?? 'default';
  return await DatabaseService().getDatabase(activeId);
});

// Provider for MessageService
final messageServiceProvider = Provider((ref) {
  final dio = ref.watch(dioProvider);
  return MessageService(dio);
});

// Provider for the message repository
final messageRepositoryProvider = Provider((ref) {
  final dbService = DatabaseService();
  final messageService = ref.watch(messageServiceProvider);
  return MessageRepository(dbService, messageService, ref);
});

// Modern Notifier for current conversation's messages in Riverpod 3.0
class ChatNotifier extends FamilyNotifier<List<MessageModel>, String> {
  String get conversationId => arg;

  int _currentOffset = 0;
  bool _hasMore = true;
  bool get hasMore => _hasMore;

  @override
  List<MessageModel> build(String arg) {
    loadMessages();
    return [];
  }

  Future<void> loadMessages() async {
    final repo = ref.read(messageRepositoryProvider);
    _currentOffset = 0;
    _hasMore = true;
    final msgs = await repo.getMessages(conversationId, limit: 50, offset: _currentOffset);
    if (msgs.length < 50) _hasMore = false;
    state = msgs;
  }

  Future<void> loadMoreMessages() async {
    if (!_hasMore) return;
    
    final repo = ref.read(messageRepositoryProvider);
    _currentOffset += 50;
    
    // We pass offset to get older messages
    final olderMsgs = await repo.getMessages(conversationId, limit: 50, offset: _currentOffset);
    
    if (olderMsgs.isEmpty) {
      _hasMore = false;
      return;
    }
    
    if (olderMsgs.length < 50) {
      _hasMore = false;
    }
    
    // olderMsgs are returned oldest to newest for the chunk.
    // E.g., [msg49, msg50, ... msg99].
    // state currently has [msg0, msg1, ... msg48].
    // We want the final list to have oldest at the beginning.
    state = [...olderMsgs, ...state];
  }

  Future<void> addMessage(MessageModel msg) async {
    final db = await ref.read(dbProvider.future);
    final List<Map<String, dynamic>> convs = await db.query(
      'conversations',
      columns: ['is_group'],
      where: 'id = ?',
      whereArgs: [conversationId],
    );
    final isGroup = convs.isNotEmpty && convs.first['is_group'] == 1;

    if (isGroup) {
      final groupCryptoService = ref.read(groupCryptoServiceProvider);
      
      // 1. Ensure we have distributed our Sender Key
      var mySenderKey = await groupCryptoService.getSenderKey(conversationId, msg.senderId);
      if (mySenderKey == null) {
        mySenderKey = await groupCryptoService.generateSenderKey();
        await groupCryptoService.saveSenderKeyLocally(conversationId, msg.senderId, mySenderKey);
        // Distribute to all group members (1-1 E2EE)
        await groupCryptoService.distributeSenderKey(conversationId, mySenderKey, msg.senderId);
      }

      // 2. Encrypt the group message payload (AES-GCM)
      final encryptionResult = await groupCryptoService.encryptGroupMessage(
        conversationId,
        msg.senderId,
        msg.plaintext ?? '',
      );

      // Pack IV, MAC, and Ciphertext into a single JSON payload for transport
      final packedCiphertext = jsonEncode(encryptionResult);

      final encryptedMsg = MessageModel(
        id: msg.id,
        conversationId: msg.conversationId,
        senderId: msg.senderId,
        recipientId: msg.conversationId,
        ciphertext: packedCiphertext,
        plaintext: msg.plaintext,
        msgType: msg.msgType,
        createdAt: msg.createdAt,
      );

      final repo = ref.read(messageRepositoryProvider);
      state = [...state, encryptedMsg];
      await repo.saveMessage(encryptedMsg);

      final wsPayload = {
        'group_id': conversationId,
        'ciphertext': packedCiphertext,
        'msg_type': msg.msgType,
        'iteration': 0,
        'distribution_id': '',
      };

      final socket = ref.read(webSocketProvider);
      if (socket != null && socket.isConnected) {
        socket.sendMessage('send_group_message', wsPayload);
      } else {
        await ref.read(outboundQueueProvider.notifier).enqueue(
          OutboundQueueItem(
            id: encryptedMsg.id,
            conversationId: conversationId,
            payload: wsPayload,
            createdAt: encryptedMsg.createdAt,
          ),
        );
      }
      return;
    }

    final sessionManager = ref.read(sessionManagerProvider);
    final identityManager = ref.read(identityManagerProvider);
    final authService = ref.read(authServiceProvider);
    
    try {
      // 1. Get Alice's Identity
      final aliceIdentityKeyPair = await identityManager.getIdentityKeyPair();
      if (aliceIdentityKeyPair == null) throw 'Yerel anahtar bulunamadı';

      // 2. Establish/Get Session
      final bobBundle = await authService.getUserBundle(msg.recipientId);
      
      final x3dhResult = await sessionManager.establishSession(
        conversationId: conversationId,
        aliceIdentityKeyPair: aliceIdentityKeyPair,
        bobBundle: bobBundle,
      );

      final aliceIdentityPub = (await identityManager.getPublicBundle())['identity_key'];

      // 3. Encrypt with Double Ratchet
      final encryptionResult = await sessionManager.encryptMessage(
        conversationId, 
        msg.plaintext ?? ''
      );

      // Check disappearing duration
      final List<Map<String, dynamic>> res = await db.query(
        'conversations',
        columns: ['disappearing_duration'],
        where: 'id = ?',
        whereArgs: [conversationId],
      );
      int disappearingDuration = 0;
      if (res.isNotEmpty) {
        disappearingDuration = res.first['disappearing_duration'] ?? 0;
      }
      
      DateTime? expiresAt;
      if (disappearingDuration > 0) {
        expiresAt = DateTime.now().add(Duration(seconds: disappearingDuration));
      }

      final encryptedMsg = MessageModel(
        id: msg.id,
        conversationId: msg.conversationId,
        senderId: msg.senderId,
        recipientId: msg.recipientId,
        ciphertext: encryptionResult['ciphertext'],
        plaintext: msg.plaintext, 
        msgType: msg.msgType,
        ratchetKey: encryptionResult['ratchet_key'],
        counter: encryptionResult['counter'],
        aliceIdentityKey: aliceIdentityPub,
        aliceEphemeralKey: x3dhResult['aliceEphemeralPub'],
        createdAt: msg.createdAt,
        expiresAt: expiresAt,
      );

      final repo = ref.read(messageRepositoryProvider);
      state = [...state, encryptedMsg];
      await repo.saveMessage(encryptedMsg);

      // 4. Build the WebSocket payload.
      final wsPayload = {
        'recipient_id': encryptedMsg.recipientId,
        'ciphertext': encryptedMsg.ciphertext,
        'msg_type': encryptedMsg.msgType,
        'ratchet_key': encryptedMsg.ratchetKey,
        'prev_counter': encryptedMsg.prevCounter ?? 0,
        'counter': encryptedMsg.counter ?? 0,
        'expires_in': disappearingDuration,
        'queue_id': encryptedMsg.id, // echoed back in message_delivered ACK
      };

      // 5. Check if P2P mode is active (Cloud Lock Bypass)
      final p2pActive = ref.read(p2pProvider)[conversationId] ?? false;
      if (p2pActive) {
        final p2pSuccess = await ref.read(p2pProvider.notifier).sendP2PMessage(conversationId, wsPayload);
        if (p2pSuccess) return;
      }

      // 6. Send immediately if connected; otherwise queue for later delivery.
      final socket = ref.read(webSocketProvider);
      if (socket != null && socket.isConnected) {
        socket.sendMessage('send_message', wsPayload);
      } else {
        // Offline — persist to outbound queue; will be flushed on reconnect.
        await ref.read(outboundQueueProvider.notifier).enqueue(
          OutboundQueueItem(
            id: encryptedMsg.id,
            conversationId: conversationId,
            payload: wsPayload,
            createdAt: encryptedMsg.createdAt,
          ),
        );
        if (kDebugMode) debugPrint('[Chat] Queued message ${encryptedMsg.id} (offline)');
      }
    } catch (e) {
      debugPrint('Gönderim hatası: $e');
    }
  }

  Future<void> sendMediaMessage({
    required Uint8List fileBytes,
    required String filename,
    required String mimeType,
    required int fileSize,
    bool isHD = false,
  }) async {
    final sessionManager = ref.read(sessionManagerProvider);
    final identityManager = ref.read(identityManagerProvider);
    final authService = ref.read(authServiceProvider);
    final mediaUploadSvc = ref.read(mediaUploadServiceProvider);
    
    final myUserId = ref.read(authProvider).userId ?? '';
    final tempMsgId = const Uuid().v4();
    final createdAt = DateTime.now();

    // 1. Create a local placeholder message with uploading status
    final tempPlaintext = jsonEncode({
      'type': 'media',
      'status': 'uploading',
      'filename': filename,
      'mime_type': mimeType,
      'size': fileSize,
    });

    final tempMsg = MessageModel(
      id: tempMsgId,
      conversationId: conversationId,
      senderId: myUserId,
      recipientId: conversationId,
      ciphertext: '', 
      plaintext: tempPlaintext,
      msgType: mimeType.startsWith('image/') ? 'image' : 'file',
      createdAt: createdAt,
    );

    // Save placeholder to UI state and SQLite
    final repo = ref.read(messageRepositoryProvider);
    state = [...state, tempMsg];
    await repo.saveMessage(tempMsg);

    try {
      // 2. Compress image before encryption (compress → encrypt → upload).
      //    Compression is now handled centrally in MediaUploadService.

      // 3. Upload file with progress reporting.
      ref.read(uploadProgressProvider.notifier).setProgress(tempMsgId, 0.0);

      final uploadResult = await mediaUploadSvc.uploadMedia(
        fileBytes: fileBytes,
        filename: filename,
        mimeType: mimeType,
        isHD: isHD,
        onProgress: (progress) {
          ref.read(uploadProgressProvider.notifier).setProgress(tempMsgId, progress);
        },
      );

      // Cache decrypted bytes locally so we don't download back.
      ref.read(decryptedMediaProvider.notifier).setBytes(uploadResult.url, fileBytes);

      // 4. Prepare Final E2EE Message Payload
      final finalPlaintext = jsonEncode({
        'type': 'media',
        'status': 'success',
        'media_url': uploadResult.url,
        'media_key': uploadResult.mediaKeyBase64,
        'filename': filename,
        'mime_type': mimeType,   // actual stored type (may differ after compress)
        'size': fileSize,        // compressed size in bytes
      });

      // 4. Encrypt with Signal Protocol (Double Ratchet)
      final aliceIdentityKeyPair = await identityManager.getIdentityKeyPair();
      if (aliceIdentityKeyPair == null) throw 'Yerel anahtar bulunamadı';

      final bobBundle = await authService.getUserBundle(tempMsg.recipientId);
      
      final x3dhResult = await sessionManager.establishSession(
        conversationId: conversationId,
        aliceIdentityKeyPair: aliceIdentityKeyPair,
        bobBundle: bobBundle,
      );

      final aliceIdentityPub = (await identityManager.getPublicBundle())['identity_key'];

      final encryptionResult = await sessionManager.encryptMessage(
        conversationId, 
        finalPlaintext
      );

      // Check disappearing duration
      final db = await ref.read(dbProvider.future);
      final List<Map<String, dynamic>> res = await db.query(
        'conversations',
        columns: ['disappearing_duration'],
        where: 'id = ?',
        whereArgs: [conversationId],
      );
      int disappearingDuration = 0;
      if (res.isNotEmpty) {
        disappearingDuration = res.first['disappearing_duration'] ?? 0;
      }
      
      DateTime? expiresAt;
      if (disappearingDuration > 0) {
        expiresAt = DateTime.now().add(Duration(seconds: disappearingDuration));
      }

      final finalMsg = MessageModel(
        id: tempMsgId,
        conversationId: conversationId,
        senderId: myUserId,
        recipientId: tempMsg.recipientId,
        ciphertext: encryptionResult['ciphertext'],
        plaintext: finalPlaintext,
        msgType: mimeType.startsWith('image/') ? 'image' : 'file',
        ratchetKey: encryptionResult['ratchet_key'],
        counter: encryptionResult['counter'],
        aliceIdentityKey: aliceIdentityPub,
        aliceEphemeralKey: x3dhResult['aliceEphemeralPub'],
        createdAt: createdAt,
        expiresAt: expiresAt,
      );

      // 5. Update local database with final encrypted message
      await repo.saveMessage(finalMsg);
      
      // Update UI state by replacing the placeholder
      state = state.map((m) => m.id == tempMsgId ? finalMsg : m).toList();

      // 6. Check if P2P mode is active (Cloud Lock Bypass)
      final p2pActive = ref.read(p2pProvider)[conversationId] ?? false;
      final payload = {
        'recipient_id': finalMsg.recipientId,
        'ciphertext': finalMsg.ciphertext,
        'msg_type': finalMsg.msgType,
        'ratchet_key': finalMsg.ratchetKey,
        'prev_counter': finalMsg.prevCounter ?? 0,
        'counter': finalMsg.counter ?? 0,
        'expires_in': disappearingDuration,
      };

      if (p2pActive) {
        final p2pSuccess = await ref.read(p2pProvider.notifier).sendP2PMessage(conversationId, payload);
        if (p2pSuccess) return;
      }

      // 7. Send envelope via WebSocket
      final socket = ref.read(webSocketProvider);
      if (socket != null) {
        final payload = {
          'recipient_id': finalMsg.recipientId,
          'ciphertext': finalMsg.ciphertext,
          'msg_type': finalMsg.msgType,
          'ratchet_key': finalMsg.ratchetKey,
          'prev_counter': finalMsg.prevCounter ?? 0,
          'counter': finalMsg.counter ?? 0,
          'expires_in': disappearingDuration,
        };
        socket.sendMessage('send_message', payload);
      }
    } catch (e) {
      debugPrint('Medya gönderim hatası: $e');
      final errorStr = e.toString();
      
      // Fallback: If Cloud Lock is active (402/413), try establishing P2P.
      if (errorStr.contains('402') || errorStr.contains('413') || errorStr.contains('limit')) {
        ref.read(p2pProvider.notifier).establishP2P(conversationId);
      }

      final failedPlaintext = jsonEncode({
        'type': 'media',
        'status': 'failed',
        'filename': filename,
        'mime_type': mimeType,
        'size': fileSize,
        'error': errorStr,
      });
      final failedMsg = MessageModel(
        id: tempMsgId,
        conversationId: conversationId,
        senderId: myUserId,
        recipientId: tempMsg.recipientId,
        ciphertext: '',
        plaintext: failedPlaintext,
        msgType: mimeType.startsWith('image/') ? 'image' : 'file',
        createdAt: createdAt,
      );
      await repo.saveMessage(failedMsg);
      state = state.map((m) => m.id == tempMsgId ? failedMsg : m).toList();
    } finally {
      ref.read(uploadProgressProvider.notifier).removeProgress(tempMsgId);
    }
  }

  Future<void> receiveMessage(MessageModel msg) async {
    final db = await ref.read(dbProvider.future);
    final List<Map<String, dynamic>> convs = await db.query(
      'conversations',
      columns: ['is_group'],
      where: 'id = ?',
      whereArgs: [conversationId],
    );
    final isGroup = convs.isNotEmpty && convs.first['is_group'] == 1;

    if (isGroup) {
      final groupCryptoService = ref.read(groupCryptoServiceProvider);
      try {
        final payload = jsonDecode(msg.ciphertext);
        final plaintext = await groupCryptoService.decryptGroupMessage(
          conversationId,
          msg.senderId,
          payload['ciphertext'],
          payload['iv'],
          payload['mac'],
        );

        final decryptedMsg = msg.copyWith(
          plaintext: plaintext,
          readAt: DateTime.now(),
        );

        final repo = ref.read(messageRepositoryProvider);
        await repo.saveMessage(decryptedMsg);
        state = [...state, decryptedMsg];
      } catch (e) {
        debugPrint('Group decryption failed: $e');
        if (e.toString().contains('missing')) {
          final myUserId = ref.read(authProvider).userId ?? '';
          await groupCryptoService.syncSenderKeys(conversationId, myUserId);
          try {
            final payload = jsonDecode(msg.ciphertext);
            final plaintext = await groupCryptoService.decryptGroupMessage(
              conversationId,
              msg.senderId,
              payload['ciphertext'],
              payload['iv'],
              payload['mac'],
            );
            final decryptedMsg = msg.copyWith(
              plaintext: plaintext,
              readAt: DateTime.now(),
            );
            final repo = ref.read(messageRepositoryProvider);
            await repo.saveMessage(decryptedMsg);
            state = [...state, decryptedMsg];
          } catch(e2) {
            debugPrint('Group decryption failed again after sync: $e2');
          }
        }
      }
      return;
    }

    final sessionManager = ref.read(sessionManagerProvider);
    final identityManager = ref.read(identityManagerProvider);

    try {
      // 1. Get Bob's Identity and SPK
      final bobIdentityKeyPair = await identityManager.getIdentityKeyPair();
      final bobSPKKeyPair = await identityManager.getSignedPreKeyPair();
      
      if (bobIdentityKeyPair == null || bobSPKKeyPair == null) throw 'Yerel anahtarlar bulunamadı';

      // 2. Establish/Get Session (Bob Side)
      await sessionManager.receiveSession(
        conversationId: conversationId,
        bobIdentityKeyPair: bobIdentityKeyPair,
        bobSignedPreKeyPairs: bobSPKKeyPair,
        aliceIdentityPubBase64: msg.aliceIdentityKey ?? '',
        aliceEphemeralPubBase64: msg.aliceEphemeralKey ?? '',
      );

      // 3. Decrypt with Double Ratchet
      final plaintext = await sessionManager.decryptMessage(
        conversationId,
        msg.ciphertext,
        msg.ratchetKey ?? '',
        msg.counter ?? 0,
      );

      if (msg.msgType == 'story_key') {
        try {
          final parsed = jsonDecode(plaintext);
          if (parsed['type'] == 'story_key') {
            final storyId = parsed['story_id'] as String;
            final mediaKey = parsed['media_key'] as String;
            
            final db = await ref.read(dbProvider.future);
            await db.insert(
              'story_keys',
              {
                'story_id': storyId,
                'media_key': mediaKey,
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
            return; // discard story key control message from the chat list
          }
        } catch (e) {
          debugPrint('Story key parsing error: $e');
        }
      }

      if (msg.msgType == 'reaction') {
        try {
          final parsed = jsonDecode(plaintext);
          if (parsed['type'] == 'reaction') {
            final targetId = parsed['target_message_id'] as String;
            final emoji = parsed['emoji'] as String;
            final action = parsed['action'] as String;
            
            await _updateMessageReactionsInDb(targetId, msg.senderId, emoji, action);
            
            // Update target message in UI state
            state = state.map((m) {
              if (m.id == targetId) {
                final reactionsMap = m.reactionsMap;
                if (action == 'add') {
                  reactionsMap[emoji] = msg.senderId;
                } else {
                  reactionsMap.remove(emoji);
                }
                return m.copyWith(reactions: reactionsMap.isEmpty ? null : jsonEncode(reactionsMap));
              }
              return m;
            }).toList();
            return; // discard reaction control message from the chat list
          }
        } catch (e) {
          debugPrint('Reaction parsing error: $e');
        }
      }

      if (msg.msgType == 'edit') {
        try {
          final parsed = jsonDecode(plaintext);
          if (parsed['type'] == 'edit') {
            final targetId = parsed['target_message_id'] as String;
            final newText = parsed['new_text'] as String;
            
            final db = await ref.read(dbProvider.future);
            await db.update(
              'messages',
              {
                'plaintext': newText,
                'edited_at': DateTime.now().toIso8601String(),
              },
              where: 'id = ?',
              whereArgs: [targetId],
            );
            
            state = state.map((m) {
              if (m.id == targetId) {
                return m.copyWith(
                  plaintext: newText,
                  editedAt: DateTime.now(),
                );
              }
              return m;
            }).toList();
            return; // discard edit control message
          }
        } catch (e) {
          debugPrint('Edit parsing error: $e');
        }
      }

      final decryptedMsg = MessageModel(
        id: msg.id,
        conversationId: msg.conversationId,
        senderId: msg.senderId,
        recipientId: msg.recipientId,
        ciphertext: msg.ciphertext,
        plaintext: plaintext,
        msgType: msg.msgType,
        ratchetKey: msg.ratchetKey,
        counter: msg.counter,
        createdAt: msg.createdAt,
        expiresAt: msg.expiresAt,
      );

      final repo = ref.read(messageRepositoryProvider);
      state = [...state, decryptedMsg];
      repo.saveMessage(decryptedMsg);
    } catch (e) {
      debugPrint('Deşifre hatası: $e');
    }
  }

  Future<void> receiveGroupMessage(MessageModel msg) async {
    final repo = ref.read(messageRepositoryProvider);
    state = [...state, msg];
    await repo.saveMessage(msg);
  }

  Future<void> editMessage(String id, String newText) async {
    try {
      final sessionManager = ref.read(sessionManagerProvider);
      final socket = ref.read(webSocketProvider);
      
      final db = await ref.read(dbProvider.future);
      
      // Update locally first
      await db.update(
        'messages',
        {
          'plaintext': newText,
          'edited_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      
      state = state.map((m) {
        if (m.id == id) {
          return m.copyWith(plaintext: newText, editedAt: DateTime.now());
        }
        return m;
      }).toList();
      
      ref.read(conversationProvider.notifier).loadConversations();
      
      // Send WebSocket event
      final controlPlaintext = jsonEncode({
        'type': 'edit',
        'target_message_id': id,
        'new_text': newText,
      });

      final encryptionResult = await sessionManager.encryptMessage(
        conversationId,
        controlPlaintext,
      );

      if (socket != null && socket.isConnected) {
        socket.sendMessage('send_message', {
          'recipient_id': conversationId,
          'ciphertext': encryptionResult['ciphertext'],
          'msg_type': 'edit',
          'ratchet_key': encryptionResult['ratchet_key'],
          'prev_counter': 0,
          'counter': encryptionResult['counter'],
          'expires_in': 0,
          'queue_id': const Uuid().v4(),
        });
      }
    } catch (e) {
      debugPrint('Edit error: $e');
  }

  Future<void> deleteMessageForMe(String id) async {
    try {
      final db = await ref.read(dbProvider.future);
      await db.delete(
        'messages',
        where: 'id = ?',
        whereArgs: [id],
      );
      
      state = state.where((m) => m.id != id).toList();
      ref.read(conversationProvider.notifier).loadConversations();
    } catch (e) {
      debugPrint('Benden silme hatası: $e');
    }
  }

  Future<void> deleteMessageForEveryone(String id) async {
    try {
      final dio = ref.read(dioProvider);
      await dio.delete('/api/messages/$id');
      
      final db = await ref.read(dbProvider.future);
      await db.update(
        'messages',
        {
          'plaintext': 'Bu mesaj silindi',
          'msg_type': 'deleted',
          'ciphertext': '',
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      
      state = state.map((m) {
        if (m.id == id) {
          return m.copyWith(
            plaintext: 'Bu mesaj silindi',
            msgType: 'deleted',
            ciphertext: '',
          );
        }
        return m;
      }).toList();
      
      ref.read(conversationProvider.notifier).loadConversations();
    } catch (e) {
      debugPrint('Herkesten silme hatası: $e');
      rethrow;
    }
  }

  Future<void> handleMessageDeletedEvent(String messageId) async {
    try {
      final db = await ref.read(dbProvider.future);
      await db.update(
        'messages',
        {
          'plaintext': 'Bu mesaj silindi',
          'msg_type': 'deleted',
          'ciphertext': '',
        },
        where: 'id = ?',
        whereArgs: [messageId],
      );
      
      state = state.map((m) {
        if (m.id == messageId) {
          return m.copyWith(
            plaintext: 'Bu mesaj silindi',
            msgType: 'deleted',
            ciphertext: '',
          );
        }
        return m;
      }).toList();
      
      ref.read(conversationProvider.notifier).loadConversations();
    } catch (e) {
      debugPrint('Silinen mesaj işleme hatası: $e');
    }
  }

  Future<void> pinMessage(String id) async {
    try {
      final msgService = ref.read(messageServiceProvider);
      await msgService.pinMessage(id);

      final db = await ref.read(dbProvider.future);
      await db.update(
        'messages',
        {'is_pinned': 1},
        where: 'id = ?',
        whereArgs: [id],
      );

      state = state.map((m) {
        if (m.id == id) {
          return m.copyWith(isPinned: true);
        }
        return m;
      }).toList();
    } catch (e) {
      debugPrint('Mesaj sabitleme hatası: $e');
      rethrow;
    }
  }

  Future<void> unpinMessage(String id) async {
    try {
      final msgService = ref.read(messageServiceProvider);
      await msgService.unpinMessage(id);

      final db = await ref.read(dbProvider.future);
      await db.update(
        'messages',
        {'is_pinned': 0},
        where: 'id = ?',
        whereArgs: [id],
      );

      state = state.map((m) {
        if (m.id == id) {
          return m.copyWith(isPinned: false);
        }
        return m;
      }).toList();
    } catch (e) {
      debugPrint('Sabitleme kaldırma hatası: $e');
      rethrow;
    }
  }

  Future<void> handleMessagePinnedEvent(String id) async {
    try {
      final db = await ref.read(dbProvider.future);
      await db.update(
        'messages',
        {'is_pinned': 1},
        where: 'id = ?',
        whereArgs: [id],
      );

      state = state.map((m) {
        if (m.id == id) {
          return m.copyWith(isPinned: true);
        }
        return m;
      }).toList();
    } catch (e) {
      debugPrint('Event pin hatası: $e');
    }
  }

  Future<void> handleMessageUnpinnedEvent(String id) async {
    try {
      final db = await ref.read(dbProvider.future);
      await db.update(
        'messages',
        {'is_pinned': 0},
        where: 'id = ?',
        whereArgs: [id],
      );

      state = state.map((m) {
        if (m.id == id) {
          return m.copyWith(isPinned: false);
        }
        return m;
      }).toList();
    } catch (e) {
      debugPrint('Event unpin hatası: $e');
    }
  }

  /// Called when a message_read WebSocket event arrives for a message WE sent.
  /// Updates both in-memory state and local SQLite so ticks update in real-time.
  Future<void> updateMessageReadAt(String messageId) async {
    final now = DateTime.now();
    state = state.map((m) {
      if (m.id == messageId && m.readAt == null) {
        return MessageModel(
          id: m.id,
          conversationId: m.conversationId,
          senderId: m.senderId,
          recipientId: m.recipientId,
          ciphertext: m.ciphertext,
          plaintext: m.plaintext,
          msgType: m.msgType,
          ratchetKey: m.ratchetKey,
          aliceIdentityKey: m.aliceIdentityKey,
          aliceEphemeralKey: m.aliceEphemeralKey,
          prevCounter: m.prevCounter,
          counter: m.counter,
          createdAt: m.createdAt,
          deliveredAt: m.deliveredAt,
          readAt: now,
        );
      }
      return m;
    }).toList();

    // Persist to local SQLite
    final repo = ref.read(messageRepositoryProvider);
    await repo.markMessageReadLocally(messageId);
  }

  Future<void> acceptRequest() async {
    final service = ref.read(messageServiceProvider);
    try {
      await service.acceptMessageRequest(conversationId);
      
      // Update local conversation status in SQLite
      final db = await ref.read(dbProvider.future);
      await db.update(
        'conversations',
        {'friendship_status': 'accepted'},
        where: 'other_user_id = ?',
        whereArgs: [conversationId],
      );
      
      // Refresh conversations list to update UI
      ref.read(conversationProvider.notifier).loadConversations();
    } catch (e) {
      debugPrint('Accept error: $e');
    }
  }

  Future<void> rejectRequest() async {
    final service = ref.read(messageServiceProvider);
    try {
      await service.rejectMessageRequest(conversationId);
      
      // Update local conversation status in SQLite
      final db = await ref.read(dbProvider.future);
      await db.update(
        'conversations',
        {'friendship_status': 'rejected'},
        where: 'other_user_id = ?',
        whereArgs: [conversationId],
      );
      
      // Refresh conversations list to update UI
      ref.read(conversationProvider.notifier).loadConversations();
    } catch (e) {
      debugPrint('Reject error: $e');
    }
  }

  Future<void> blockUser() async {
    final service = ref.read(messageServiceProvider);
    try {
      await service.blockUser(conversationId);
      
      // Update local conversation status in SQLite
      final db = await ref.read(dbProvider.future);
      await db.update(
        'conversations',
        {
          'friendship_status': 'blocked',
          'initiator_id': ref.read(authProvider).userId,
        },
        where: 'other_user_id = ?',
        whereArgs: [conversationId],
      );
      
      // Refresh conversations list to update UI
      ref.read(conversationProvider.notifier).loadConversations();
    } catch (e) {
      debugPrint('Block error: $e');
    }
  }

  Future<void> unblockUser() async {
    final service = ref.read(messageServiceProvider);
    try {
      await service.unblockUser(conversationId);
      
      // Update local conversation status in SQLite
      final db = await ref.read(dbProvider.future);
      await db.update(
        'conversations',
        {
          'friendship_status': 'none',
          'initiator_id': null,
        },
        where: 'other_user_id = ?',
        whereArgs: [conversationId],
      );
      
      // Refresh conversations list to update UI
      ref.read(conversationProvider.notifier).loadConversations();
    } catch (e) {
      debugPrint('Unblock error: $e');
    }
  }

  Future<void> _updateMessageReactionsInDb(
    String messageId,
    String userId,
    String emoji,
    String action,
  ) async {
    try {
      final db = await ref.read(dbProvider.future);
      final List<Map<String, dynamic>> existing = await db.query(
        'messages',
        columns: ['reactions'],
        where: 'id = ?',
        whereArgs: [messageId],
      );
      if (existing.isEmpty) return;
      
      final rawReactions = existing.first['reactions'] as String?;
      Map<String, String> reactionsMap = {};
      if (rawReactions != null && rawReactions.isNotEmpty) {
        try {
          final decoded = jsonDecode(rawReactions);
          reactionsMap = (decoded as Map<String, dynamic>).map(
            (k, v) => MapEntry(k, v.toString()),
          );
        } catch (_) {}
      }
      
      if (action == 'add') {
        reactionsMap[emoji] = userId;
      } else {
        reactionsMap.remove(emoji);
      }
      
      final newReactionsStr = reactionsMap.isEmpty ? null : jsonEncode(reactionsMap);
      await db.update(
        'messages',
        {'reactions': newReactionsStr},
        where: 'id = ?',
        whereArgs: [messageId],
      );
    } catch (e) {
      debugPrint('Reaction DB update error: $e');
    }
  }

  Future<void> toggleReaction(String messageId, String emoji) async {
    final myUserId = ref.read(authProvider).userId ?? '';
    final sessionManager = ref.read(sessionManagerProvider);
    final identityManager = ref.read(identityManagerProvider);
    final authService = ref.read(authServiceProvider);
    
    // Find target message
    final messageIndex = state.indexWhere((m) => m.id == messageId);
    if (messageIndex == -1) return; // not found
    
    final message = state[messageIndex];
    final currentReactor = message.reactionsMap[emoji];
    final action = (currentReactor == myUserId) ? 'remove' : 'add';
    
    // Update local state immediately for fast response
    state = state.map((m) {
      if (m.id == messageId) {
        final reactionsMap = m.reactionsMap;
        if (action == 'add') {
          reactionsMap[emoji] = myUserId;
        } else {
          reactionsMap.remove(emoji);
        }
        return m.copyWith(reactions: reactionsMap.isEmpty ? null : jsonEncode(reactionsMap));
      }
      return m;
    }).toList();
    
    // Update locally in SQLite
    await _updateMessageReactionsInDb(messageId, myUserId, emoji, action);
    
    // Send E2EE reaction control message
    try {
      final aliceIdentityKeyPair = await identityManager.getIdentityKeyPair();
      if (aliceIdentityKeyPair == null) throw 'Yerel anahtar bulunamadı';

      final otherUserId = conversationId;
      final bobBundle = await authService.getUserBundle(otherUserId);
      await sessionManager.establishSession(
        conversationId: conversationId,
        aliceIdentityKeyPair: aliceIdentityKeyPair,
        bobBundle: bobBundle,
      );

      final reactionPlaintext = jsonEncode({
        'type': 'reaction',
        'target_message_id': messageId,
        'emoji': emoji,
        'action': action,
      });

      final encryptionResult = await sessionManager.encryptMessage(
        conversationId, 
        reactionPlaintext
      );

      final msgId = const Uuid().v4();
      final socket = ref.read(webSocketProvider);
      if (socket != null && socket.isConnected) {
        final payload = {
          'recipient_id': otherUserId,
          'ciphertext': encryptionResult['ciphertext'],
          'msg_type': 'reaction',
          'ratchet_key': encryptionResult['ratchet_key'],
          'prev_counter': 0,
          'counter': encryptionResult['counter'],
          'expires_in': 0,
          'queue_id': msgId,
        };
        socket.sendMessage('send_message', payload);
      }
    } catch (e) {
      debugPrint('Reaksiyon gönderim hatası: $e');
    }
  }

  Future<void> updateDisappearingDuration(int seconds) async {
    try {
      final db = await ref.read(dbProvider.future);
      await db.update(
        'conversations',
        {'disappearing_duration': seconds},
        where: 'id = ?',
        whereArgs: [conversationId],
      );
      
      // Update local state in conversation notifier
      ref.read(conversationProvider.notifier).loadConversations();
      
      // Send WebSocket control signal to recipient
      final socket = ref.read(webSocketProvider);
      if (socket != null && socket.isConnected) {
        socket.sendMessage('conversation_settings_updated', {
          'recipient_id': conversationId,
          'disappearing_duration': seconds,
        });
      }
    } catch (e) {
      debugPrint('Disappearing duration update error: $e');
    }
  }
}

// Correct Family Provider syntax for Riverpod
final chatProvider = NotifierProvider.family<ChatNotifier, List<MessageModel>, String>(
  ChatNotifier.new,
);

// Modern Notifier for all conversations
class ConversationNotifier extends Notifier<List<ConversationModel>> {
  @override
  List<ConversationModel> build() {
    loadConversations();
    return [];
  }

  Future<void> loadConversations() async {
    final repo = ref.read(messageRepositoryProvider);
    state = await repo.getConversations();

    // UX-9: Otomatik PreKey Yenileme
    // Sunucudaki prekey sayısı 10'un altına düşerse 50 adet yeni prekey yükle.
    _replenishPrekeysIfNeeded();
  }

  Future<void> _replenishPrekeysIfNeeded() async {
    try {
      final authService = ref.read(authServiceProvider);
      final identityManager = ref.read(identityManagerProvider);

      final count = await authService.getPrekeysCount();
      if (count < 0) return; // API error, skip silently
      
      if (count < 10) {
        debugPrint('[PreKey] Kalan prekey sayısı: $count — 50 adet yeni prekey yükleniyor...');
        final newKeys = await identityManager.generateOneTimePrekeys(50);
        await authService.replenishPrekeys(newKeys);
        debugPrint('[PreKey] 50 adet prekey başarıyla yüklendi.');
      }
    } catch (e) {
      debugPrint('[PreKey] Yenileme hatası: $e');
    }
  }

  Future<void> toggleMute(String conversationId) async {
    try {
      final db = await ref.read(dbProvider.future);
      final List<Map<String, dynamic>> res = await db.query(
        'conversations',
        columns: ['is_muted'],
        where: 'id = ?',
        whereArgs: [conversationId],
      );
      if (res.isNotEmpty) {
        final currentMuted = (res.first['is_muted'] ?? 0) == 1;
        
        if (currentMuted) {
          await ref.read(messageServiceProvider).unmuteChat(conversationId);
        } else {
          await ref.read(messageServiceProvider).muteChat(conversationId, 'forever');
        }

        await db.update(
          'conversations',
          {'is_muted': currentMuted ? 0 : 1},
          where: 'id = ?',
          whereArgs: [conversationId],
        );
        await loadConversations();
      }
    } catch (e) {
      debugPrint('Sessize alma hatası: $e');
    }
  }

  Future<void> toggleArchive(String conversationId) async {
    try {
      final db = await ref.read(dbProvider.future);
      final List<Map<String, dynamic>> res = await db.query(
        'conversations',
        columns: ['is_archived'],
        where: 'id = ?',
        whereArgs: [conversationId],
      );
      if (res.isNotEmpty) {
        final currentArchived = (res.first['is_archived'] ?? 0) == 1;
        await db.update(
          'conversations',
          {'is_archived': currentArchived ? 0 : 1},
          where: 'id = ?',
          whereArgs: [conversationId],
        );
        await loadConversations();
      }
    } catch (e) {
      debugPrint('Arşivleme hatası: $e');
    }
  }
}

final conversationProvider = NotifierProvider<ConversationNotifier, List<ConversationModel>>(ConversationNotifier.new);

class TypingNotifier extends FamilyNotifier<bool, String> {
  String get userId => arg;
  Timer? _timer;

  @override
  bool build(String arg) {
    ref.onDispose(() {
      _timer?.cancel();
    });
    return false;
  }

  void setTyping(bool isTyping) {
    _timer?.cancel();
    state = isTyping;

    if (isTyping) {
      _timer = Timer(const Duration(seconds: 4), () {
        state = false;
      });
    }
  }
}

final typingProvider = NotifierProvider.family<TypingNotifier, bool, String>(
  TypingNotifier.new,
);

