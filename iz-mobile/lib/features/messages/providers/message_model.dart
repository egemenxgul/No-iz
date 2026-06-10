import 'dart:convert';

class MessageModel {
  final String id;
  final String conversationId;
  final String senderId;
  final String recipientId;
  final String ciphertext;
  final String? plaintext;
  final String msgType;
  final String? ratchetKey;
  final String? aliceIdentityKey;
  final String? aliceEphemeralKey;
  final int? prevCounter;
  final int? counter;
  final DateTime createdAt;
  final DateTime? deliveredAt;
  final DateTime? readAt;
  final DateTime? expiresAt;
  final DateTime? editedAt;
  final String? reactions;
  final bool isPinned;
  final String? senderName;

  MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.recipientId,
    required this.ciphertext,
    this.plaintext,
    required this.msgType,
    this.ratchetKey,
    this.aliceIdentityKey,
    this.aliceEphemeralKey,
    this.prevCounter,
    this.counter,
    required this.createdAt,
    this.deliveredAt,
    this.readAt,
    this.expiresAt,
    this.editedAt,
    this.reactions,
    this.isPinned = false,
    this.senderName,
  });

  Map<String, String> get reactionsMap {
    if (reactions == null || reactions!.isEmpty) return {};
    try {
      final decoded = jsonDecode(reactions!);
      return (decoded as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, v.toString()),
      );
    } catch (_) {
      return {};
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'sender_id': senderId,
      'recipient_id': recipientId,
      'ciphertext': ciphertext,
      'plaintext': plaintext,
      'msg_type': msgType,
      'ratchet_key': ratchetKey,
      'alice_identity_key': aliceIdentityKey,
      'alice_ephemeral_key': aliceEphemeralKey,
      'prev_counter': prevCounter,
      'counter': counter,
      'created_at': createdAt.toIso8601String(),
      'delivered_at': deliveredAt?.toIso8601String(),
      'read_at': readAt?.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
      'edited_at': editedAt?.toIso8601String(),
      'reactions': reactions,
      'is_pinned': isPinned ? 1 : 0,
      'sender_name': senderName,
    };
  }

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    return MessageModel(
      id: map['id'],
      conversationId: map['conversation_id'],
      senderId: map['sender_id'],
      recipientId: map['recipient_id'],
      ciphertext: map['ciphertext'],
      plaintext: map['plaintext'],
      msgType: map['msg_type'],
      ratchetKey: map['ratchet_key'],
      aliceIdentityKey: map['alice_identity_key'],
      aliceEphemeralKey: map['alice_ephemeral_key'],
      prevCounter: map['prev_counter'],
      counter: map['counter'],
      createdAt: DateTime.parse(map['created_at']),
      deliveredAt: map['delivered_at'] != null ? DateTime.parse(map['delivered_at']) : null,
      readAt: map['read_at'] != null ? DateTime.parse(map['read_at']) : null,
      expiresAt: map['expires_at'] != null ? DateTime.parse(map['expires_at']) : null,
      editedAt: map['edited_at'] != null ? DateTime.parse(map['edited_at']) : null,
      reactions: map['reactions'],
      isPinned: map['is_pinned'] == 1 || map['is_pinned'] == true,
      senderName: map['sender_name'],
    );
  }

  MessageModel copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? recipientId,
    String? ciphertext,
    String? plaintext,
    String? msgType,
    String? ratchetKey,
    String? aliceIdentityKey,
    String? aliceEphemeralKey,
    int? prevCounter,
    int? counter,
    DateTime? createdAt,
    DateTime? deliveredAt,
    DateTime? readAt,
    DateTime? expiresAt,
    DateTime? editedAt,
    String? reactions,
    bool? isPinned,
    String? senderName,
  }) {
    return MessageModel(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      recipientId: recipientId ?? this.recipientId,
      ciphertext: ciphertext ?? this.ciphertext,
      plaintext: plaintext ?? this.plaintext,
      msgType: msgType ?? this.msgType,
      ratchetKey: ratchetKey ?? this.ratchetKey,
      aliceIdentityKey: aliceIdentityKey ?? this.aliceIdentityKey,
      aliceEphemeralKey: aliceEphemeralKey ?? this.aliceEphemeralKey,
      prevCounter: prevCounter ?? this.prevCounter,
      counter: counter ?? this.counter,
      createdAt: createdAt ?? this.createdAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      readAt: readAt ?? this.readAt,
      expiresAt: expiresAt ?? this.expiresAt,
      editedAt: editedAt ?? this.editedAt,
      reactions: reactions ?? this.reactions,
      isPinned: isPinned ?? this.isPinned,
      senderName: senderName ?? this.senderName,
    );
  }
}

class ConversationModel {
  final String id;
  final String otherUserId;
  final String otherUsername;
  final String? otherDisplayName;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final String friendshipStatus;
  final String? initiatorId;
  final bool isOnline;
  final DateTime? lastSeenAt;
  final int disappearingDuration;
  final bool isMuted;
  final bool isArchived;
  final bool isGroup;

  ConversationModel({
    required this.id,
    required this.otherUserId,
    required this.otherUsername,
    this.otherDisplayName,
    this.lastMessage,
    this.lastMessageAt,
    this.unreadCount = 0,
    this.friendshipStatus = 'none',
    this.initiatorId,
    this.isOnline = false,
    this.lastSeenAt,
    this.disappearingDuration = 0,
    this.isMuted = false,
    this.isArchived = false,
    this.isGroup = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'other_user_id': otherUserId,
      'other_username': otherUsername,
      'other_display_name': otherDisplayName,
      'last_message': lastMessage,
      'last_message_at': lastMessageAt?.toIso8601String(),
      'unread_count': unreadCount,
      'friendship_status': friendshipStatus,
      'initiator_id': initiatorId,
      'is_online': isOnline ? 1 : 0,
      'last_seen_at': lastSeenAt?.toIso8601String(),
      'disappearing_duration': disappearingDuration,
      'is_muted': isMuted ? 1 : 0,
      'is_archived': isArchived ? 1 : 0,
      'is_group': isGroup ? 1 : 0,
    };
  }

  factory ConversationModel.fromMap(Map<String, dynamic> map) {
    return ConversationModel(
      id: map['id'] ?? map['other_user_id'],
      otherUserId: map['other_user_id'],
      otherUsername: map['other_username'] ?? '',
      otherDisplayName: map['other_display_name'],
      lastMessage: map['last_message'],
      lastMessageAt: map['last_message_at'] != null ? DateTime.parse(map['last_message_at']) : null,
      unreadCount: map['unread_count'] ?? 0,
      friendshipStatus: map['friendship_status'] ?? 'none',
      initiatorId: map['initiator_id'],
      isOnline: map['is_online'] == true || map['is_online'] == 1,
      lastSeenAt: map['last_seen_at'] != null ? DateTime.parse(map['last_seen_at']) : null,
      disappearingDuration: map['disappearing_duration'] ?? 0,
      isMuted: map['is_muted'] == true || map['is_muted'] == 1,
      isArchived: map['is_archived'] == true || map['is_archived'] == 1,
      isGroup: map['is_group'] == true || map['is_group'] == 1,
    );
  }

  ConversationModel copyWith({
    String? id,
    String? otherUserId,
    String? otherUsername,
    String? otherDisplayName,
    String? lastMessage,
    DateTime? lastMessageAt,
    int? unreadCount,
    String? friendshipStatus,
    String? initiatorId,
    bool? isOnline,
    DateTime? lastSeenAt,
    int? disappearingDuration,
    bool? isMuted,
    bool? isArchived,
    bool? isGroup,
  }) {
    return ConversationModel(
      id: id ?? this.id,
      otherUserId: otherUserId ?? this.otherUserId,
      otherUsername: otherUsername ?? this.otherUsername,
      otherDisplayName: otherDisplayName ?? this.otherDisplayName,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      unreadCount: unreadCount ?? this.unreadCount,
      friendshipStatus: friendshipStatus ?? this.friendshipStatus,
      initiatorId: initiatorId ?? this.initiatorId,
      isOnline: isOnline ?? this.isOnline,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      disappearingDuration: disappearingDuration ?? this.disappearingDuration,
      isMuted: isMuted ?? this.isMuted,
      isArchived: isArchived ?? this.isArchived,
      isGroup: isGroup ?? this.isGroup,
    );
  }
}
