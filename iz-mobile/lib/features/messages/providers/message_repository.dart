import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import '../providers/message_model.dart';
import '../providers/message_service.dart';
import '../../../core/database/database_service.dart';
import '../../auth/providers/account_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class MessageRepository {
  final DatabaseService _dbService;
  final MessageService _messageService;
  final Ref _ref;

  MessageRepository(this._dbService, this._messageService, this._ref) {
    vacuumExpiredMessages();
  }

  Future<Database> _getDb() async {
    final activeId = _ref.read(accountProvider).activeAccountId ?? 'default';
    return await _dbService.getDatabase(activeId);
  }

  Future<void> vacuumExpiredMessages() async {
    try {
      final db = await _getDb();
      final nowIso = DateTime.now().toIso8601String();
      final count = await db.delete(
        'messages',
        where: 'expires_at IS NOT NULL AND expires_at < ?',
        whereArgs: [nowIso],
      );
      if (count > 0) {
        debugPrint('Vacuumed $count expired messages from SQLite.');
      }
    } catch (e) {
      debugPrint('Vacuum Error: $e');
    }
  }

  Future<List<ConversationModel>> getConversations() async {
    final db = await _getDb();

    // 1. Fetch direct conversations from Backend and Sync to Local DB
    try {
      final remoteConvs = await _messageService.getConversations();
      for (var map in remoteConvs) {
        final id = map['other_user_id'];
        
        final List<Map<String, dynamic>> existing = await db.query(
          'conversations',
          columns: ['disappearing_duration', 'is_muted', 'is_archived'],
          where: 'id = ?',
          whereArgs: [id],
        );
        int localDuration = 0;
        int localMuted = 0;
        int localArchived = 0;
        if (existing.isNotEmpty) {
          localDuration = existing.first['disappearing_duration'] ?? 0;
          localMuted = existing.first['is_muted'] ?? 0;
          localArchived = existing.first['is_archived'] ?? 0;
        }

        final normalizedMap = {
          ...map,
          'id': id,
          'disappearing_duration': localDuration,
          'is_muted': localMuted,
          'is_archived': localArchived,
          'is_group': 0,
        };
        final model = ConversationModel.fromMap(normalizedMap);
        await db.insert('conversations', model.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
    } catch (e) {
      debugPrint('Sync Conversations Error: $e');
    }

    // 2. Fetch groups from Backend and Sync to Local DB
    try {
      final remoteGroups = await _messageService.getGroups();
      for (var group in remoteGroups) {
        final groupId = group['id'];
        
        // Save to groups table
        await db.insert(
          'groups',
          {
            'id': groupId,
            'name': group['name'],
            'description': group['description'] ?? '',
            'avatar_url': group['avatar_url'] ?? '',
            'invite_link': group['invite_link'] ?? '',
            'created_by': group['created_by'] ?? '',
            'created_at': group['created_at'] ?? DateTime.now().toIso8601String(),
            'updated_at': group['updated_at'] ?? DateTime.now().toIso8601String(),
            'last_message': group['last_message'] ?? '',
            'last_message_at': group['last_message_at'],
            'unread_count': group['unread_count'] ?? 0,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        // Fetch local settings
        final List<Map<String, dynamic>> existing = await db.query(
          'conversations',
          columns: ['is_muted', 'is_archived', 'last_message', 'last_message_at'],
          where: 'id = ?',
          whereArgs: [groupId],
        );
        int localMuted = 0;
        int localArchived = 0;
        String? lastMsg = group['last_message'];
        String? lastMsgAt = group['last_message_at'];
        if (existing.isNotEmpty) {
          localMuted = existing.first['is_muted'] ?? 0;
          localArchived = existing.first['is_archived'] ?? 0;
          if (lastMsg == null || lastMsg.isEmpty) {
            lastMsg = existing.first['last_message'];
            lastMsgAt = existing.first['last_message_at'];
          }
        }

        // Insert into conversations to unify the UI list
        await db.insert(
          'conversations',
          {
            'id': groupId,
            'other_user_id': groupId,
            'other_username': group['name'],
            'other_display_name': group['description'] ?? '',
            'last_message': lastMsg,
            'last_message_at': lastMsgAt,
            'unread_count': group['unread_count'] ?? 0,
            'friendship_status': 'accepted',
            'initiator_id': null,
            'is_online': 0,
            'last_seen_at': null,
            'disappearing_duration': 0,
            'is_muted': localMuted,
            'is_archived': localArchived,
            'is_group': 1,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    } catch (e) {
      debugPrint('Sync Groups Error: $e');
    }

    // 3. Return both from Local DB
    final List<Map<String, dynamic>> maps = await db.query(
      'conversations',
      orderBy: 'last_message_at DESC',
    );
    return List.generate(maps.length, (i) => ConversationModel.fromMap(maps[i]));
  }

  Future<List<MessageModel>> getMessages(String conversationId) async {
    final db = await _getDb();
    
    // Check if it is a group
    final List<Map<String, dynamic>> convs = await db.query(
      'conversations',
      columns: ['is_group'],
      where: 'id = ?',
      whereArgs: [conversationId],
    );
    final isGroup = convs.isNotEmpty && convs.first['is_group'] == 1;

    if (isGroup) {
      try {
        final remoteMsgs = await _messageService.getGroupMessages(conversationId);
        for (var map in remoteMsgs) {
          final mapped = {
            'id': map['id'] ?? map['message_id'],
            'group_id': conversationId,
            'sender_id': map['sender_id'],
            'sender_name': map['sender_name'] ?? 'Kullanıcı',
            'ciphertext': map['ciphertext'],
            'plaintext': map['ciphertext'], // Plaintext transport fallback
            'msg_type': map['msg_type'] ?? 'text',
            'created_at': map['created_at'],
            'edited_at': map['edited_at'],
            'reactions': map['reactions'],
            'is_pinned': (map['is_pinned'] == true || map['is_pinned'] == 1) ? 1 : 0,
          };
          await db.insert('group_messages', mapped, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      } catch (e) {
        debugPrint('Sync Group Messages Error: $e');
      }

      final List<Map<String, dynamic>> maps = await db.query(
        'group_messages',
        where: 'group_id = ?',
        whereArgs: [conversationId],
        orderBy: 'created_at ASC',
      );
      return List.generate(maps.length, (i) {
        final map = maps[i];
        return MessageModel(
          id: map['id'],
          conversationId: map['group_id'],
          senderId: map['sender_id'],
          recipientId: map['group_id'],
          ciphertext: map['ciphertext'],
          plaintext: map['plaintext'] ?? map['ciphertext'],
          msgType: map['msg_type'],
          createdAt: DateTime.parse(map['created_at']),
          editedAt: map['edited_at'] != null ? DateTime.parse(map['edited_at']) : null,
          reactions: map['reactions'],
          isPinned: map['is_pinned'] == 1,
        );
      });
    }

    try {
      // 1. Fetch direct from Backend
      final remoteMsgs = await _messageService.getMessages(conversationId);
      
      // 2. Sync to Local DB
      for (var map in remoteMsgs) {
        await db.insert('messages', map, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    } catch (e) {
      debugPrint('Sync Messages Error: $e');
    }

    // 3. Return from Local DB
    final List<Map<String, dynamic>> maps = await db.query(
      'messages',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy: 'created_at ASC',
    );
    return List.generate(maps.length, (i) => MessageModel.fromMap(maps[i]));
  }

  Future<void> saveMessage(MessageModel message) async {
    final db = await _getDb();
    
    // Check if group
    final List<Map<String, dynamic>> convs = await db.query(
      'conversations',
      columns: ['is_group'],
      where: 'id = ?',
      whereArgs: [message.conversationId],
    );
    final isGroup = convs.isNotEmpty && convs.first['is_group'] == 1;

    if (isGroup) {
      await db.insert(
        'group_messages',
        {
          'id': message.id,
          'group_id': message.conversationId,
          'sender_id': message.senderId,
          'sender_name': 'Ben',
          'ciphertext': message.ciphertext,
          'plaintext': message.plaintext ?? message.ciphertext,
          'msg_type': message.msgType,
          'created_at': message.createdAt.toIso8601String(),
          'edited_at': message.editedAt?.toIso8601String(),
          'reactions': message.reactions,
          'is_pinned': message.isPinned ? 1 : 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      await db.update(
        'conversations',
        {
          'last_message': _formatLastMessage(message),
          'last_message_at': message.createdAt.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [message.conversationId],
      );
      return;
    }

    await db.insert(
      'messages',
      message.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    final List<Map<String, dynamic>> existing = await db.query(
      'conversations',
      where: 'id = ?',
      whereArgs: [message.conversationId],
    );

    if (existing.isNotEmpty) {
      await db.update(
        'conversations',
        {
          'last_message': _formatLastMessage(message),
          'last_message_at': message.createdAt.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [message.conversationId],
      );
    } else {
      await db.insert(
        'conversations',
        {
          'id': message.conversationId,
          'other_user_id': message.conversationId,
          'other_username': 'User',
          'last_message': _formatLastMessage(message),
          'last_message_at': message.createdAt.toIso8601String(),
          'unread_count': 0,
          'friendship_status': 'none',
          'is_online': 0,
          'last_seen_at': null,
          'is_group': 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  String _formatLastMessage(MessageModel message) {
    if (message.plaintext == null) return '[Şifreli Mesaj]';
    final text = message.plaintext!.trim();
    if (text.startsWith('{')) {
      try {
        final parsed = jsonDecode(text);
        if (parsed['type'] == 'media') {
          final isImage = (parsed['mime_type'] as String?)?.startsWith('image/') ?? false;
          return isImage ? '[Fotoğraf]' : '[Dosya]';
        }
      } catch (_) {}
    }
    return text;
  }

  /// Updates read_at in local SQLite for a specific message.
  Future<void> markMessageReadLocally(String messageId) async {
    final db = await _getDb();
    await db.update(
      'messages',
      {'read_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }
}
