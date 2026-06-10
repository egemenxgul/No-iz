import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'database_service.dart';
import '../../features/auth/providers/account_provider.dart';

/// Represents a single pending outbound message in the local SQLite queue.
/// Messages stay here until confirmed delivered (message_delivered ACK from server).
class OutboundQueueItem {
  final String id;          // UUID — also used as queue_id in the ACK
  final String conversationId;
  final Map<String, dynamic> payload; // Full WS envelope payload (already encrypted)
  final DateTime createdAt;
  final int retryCount;

  const OutboundQueueItem({
    required this.id,
    required this.conversationId,
    required this.payload,
    required this.createdAt,
    this.retryCount = 0,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'conversation_id': conversationId,
        'payload_json': jsonEncode(payload),
        'created_at': createdAt.toIso8601String(),
        'retry_count': retryCount,
      };

  factory OutboundQueueItem.fromMap(Map<String, dynamic> m) =>
      OutboundQueueItem(
        id: m['id'] as String,
        conversationId: m['conversation_id'] as String,
        payload: jsonDecode(m['payload_json'] as String) as Map<String, dynamic>,
        createdAt: DateTime.parse(m['created_at'] as String),
        retryCount: (m['retry_count'] as int?) ?? 0,
      );
}

/// Manages the `outbound_queue` SQLite table.
/// All methods open the DB via DatabaseService (same encrypted SQLCipher DB).
class OutboundQueueDao {
  final DatabaseService _dbService;
  final String _accountId;

  OutboundQueueDao(this._dbService, this._accountId);

  Future<void> enqueue(OutboundQueueItem item) async {
    final db = await _dbService.getDatabase(_accountId);
    await db.insert('outbound_queue', item.toMap());
  }

  Future<List<OutboundQueueItem>> getAll() async {
    final db = await _dbService.getDatabase(_accountId);
    final rows = await db.query(
      'outbound_queue',
      orderBy: 'created_at ASC',
    );
    return rows.map(OutboundQueueItem.fromMap).toList();
  }

  Future<void> delete(String id) async {
    final db = await _dbService.getDatabase(_accountId);
    await db.delete('outbound_queue', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> incrementRetry(String id) async {
    final db = await _dbService.getDatabase(_accountId);
    await db.rawUpdate(
      'UPDATE outbound_queue SET retry_count = retry_count + 1 WHERE id = ?',
      [id],
    );
  }

  /// Removes items that have exceeded the maximum retry threshold.
  Future<int> pruneExpired({int maxRetries = 5}) async {
    final db = await _dbService.getDatabase(_accountId);
    return db.delete(
      'outbound_queue',
      where: 'retry_count >= ?',
      whereArgs: [maxRetries],
    );
  }
}

// ── Riverpod Providers ───────────────────────────────────────────────────────

/// StateNotifier that exposes the current queue contents and mutations.
class OutboundQueueNotifier extends Notifier<List<OutboundQueueItem>> {
  OutboundQueueDao? _dao;

  @override
  List<OutboundQueueItem> build() {
    _initDao();
    return [];
  }

  void _initDao() async {
    final accountId = ref.read(accountProvider).activeAccountId;
    if (accountId == null) return;
    _dao = OutboundQueueDao(DatabaseService(), accountId);
    await _load();
  }

  Future<void> _load() async {
    if (_dao == null) return;
    final items = await _dao!.getAll();
    state = items;
  }

  /// Adds an item to the persistent queue and updates in-memory state.
  Future<void> enqueue(OutboundQueueItem item) async {
    if (_dao == null) return;
    await _dao!.enqueue(item);
    state = [...state, item];
  }

  /// Removes an item after successful delivery ACK.
  Future<void> removeFromQueue(String id) async {
    if (_dao == null) return;
    await _dao!.delete(id);
    state = state.where((i) => i.id != id).toList();
    if (kDebugMode) debugPrint('[Queue] Removed $id after delivery ACK');
  }

  /// Increments retry counter; prunes items that exceeded max retries.
  Future<void> markRetried(String id) async {
    if (_dao == null) return;
    await _dao!.incrementRetry(id);
    final pruned = await _dao!.pruneExpired();
    if (pruned > 0) {
      if (kDebugMode) debugPrint('[Queue] Pruned $pruned expired items');
    }
    await _load();
  }

  /// Returns all pending queue items (used when flushing after reconnect).
  List<OutboundQueueItem> get pending => List.unmodifiable(state);
}

final outboundQueueProvider =
    NotifierProvider<OutboundQueueNotifier, List<OutboundQueueItem>>(
  OutboundQueueNotifier.new,
);
