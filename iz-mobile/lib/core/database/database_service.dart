import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:io';
import 'dart:math';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

class DatabaseService {
  static Database? _database;
  static String? _activeAccountId;
  static const _storage = FlutterSecureStorage();

  // Updated to support multiple accounts with full isolation
  Future<Database> getDatabase(String accountId) async {
    if (_database != null && _activeAccountId == accountId) {
      return _database!;
    }
    
    // Close existing connection if switching
    if (_database != null) {
      await _database!.close();
      _database = null;
    }

    _activeAccountId = accountId;
    _database = await _initDB(accountId);
    return _database!;
  }

  Future<Database> _initDB(String accountId) async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    
    // Create a siloed directory for this specific account
    final accountDir = Directory(join(documentsDirectory.path, "accounts", accountId));
    if (!await accountDir.exists()) {
      await accountDir.create(recursive: true);
    }

    String path = join(accountDir.path, "iz_vault.db");

    // Retrieve or generate a cryptographically secure encryption key for this account.
    // Uses dart:math Random.secure() to produce 32 random bytes encoded as hex (64 chars).
    String? dbKey = await _storage.read(key: 'db_key_$accountId');
    if (dbKey == null) {
      dbKey = _generateSecureKey();
      await _storage.write(key: 'db_key_$accountId', value: dbKey);
    }

    return await openDatabase(
      path,
      version: 9,
      password: dbKey, // SQLCipher encryption
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE conversations (
        id TEXT PRIMARY KEY,
        other_user_id TEXT NOT NULL,
        other_username TEXT NOT NULL,
        other_display_name TEXT,
        last_message TEXT,
        last_message_at TEXT,
        unread_count INTEGER DEFAULT 0,
        friendship_status TEXT DEFAULT 'none',
        initiator_id TEXT,
        is_online INTEGER DEFAULT 0,
        last_seen_at TEXT,
        disappearing_duration INTEGER DEFAULT 0,
        is_muted INTEGER DEFAULT 0,
        is_archived INTEGER DEFAULT 0,
        is_group INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE messages (
        id TEXT PRIMARY KEY,
        conversation_id TEXT NOT NULL,
        sender_id TEXT NOT NULL,
        recipient_id TEXT NOT NULL,
        ciphertext TEXT NOT NULL,
        plaintext TEXT,
        msg_type TEXT NOT NULL,
        ratchet_key TEXT,
        alice_identity_key TEXT,
        alice_ephemeral_key TEXT,
        prev_counter INTEGER,
        counter INTEGER,
        created_at TEXT NOT NULL,
        delivered_at TEXT,
        read_at TEXT,
        expires_at TEXT,
        edited_at TEXT,
        reactions TEXT,
        is_pinned INTEGER DEFAULT 0,
        sender_name TEXT,
        FOREIGN KEY (conversation_id) REFERENCES conversations (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE signal_keys (
        key_id TEXT PRIMARY KEY,
        key_type TEXT NOT NULL,
        public_key TEXT NOT NULL,
        private_key TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // v2: outbound message queue for offline-first sending
    await _createOutboundQueueTable(db);

    await db.execute('''
      CREATE TABLE story_keys (
        story_id TEXT PRIMARY KEY,
        media_key TEXT NOT NULL
      )
    ''');

    // v8: Groups & Group Messaging tables
    await db.execute('''
      CREATE TABLE groups (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT DEFAULT '',
        avatar_url TEXT DEFAULT '',
        invite_link TEXT,
        created_by TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        last_message TEXT,
        last_message_at TEXT,
        unread_count INTEGER DEFAULT 0,
        is_muted INTEGER DEFAULT 0,
        is_archived INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE group_members (
        group_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        role TEXT NOT NULL DEFAULT 'member',
        joined_at TEXT NOT NULL,
        PRIMARY KEY (group_id, user_id),
        FOREIGN KEY (group_id) REFERENCES groups (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE group_messages (
        id TEXT PRIMARY KEY,
        group_id TEXT NOT NULL,
        sender_id TEXT NOT NULL,
        sender_name TEXT,
        ciphertext TEXT NOT NULL,
        plaintext TEXT,
        msg_type TEXT NOT NULL,
        created_at TEXT NOT NULL,
        edited_at TEXT,
        reactions TEXT,
        is_pinned INTEGER DEFAULT 0,
        FOREIGN KEY (group_id) REFERENCES groups (id) ON DELETE CASCADE
      )
    ''');
  }

  /// Handles schema upgrades between versions.
  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createOutboundQueueTable(db);
    }
    if (oldVersion < 3) {
      try {
        await db.execute("ALTER TABLE conversations ADD COLUMN friendship_status TEXT DEFAULT 'none'");
        await db.execute("ALTER TABLE conversations ADD COLUMN initiator_id TEXT");
      } catch (e) {
        debugPrint("SQLite version 3 upgrade warning: $e");
      }
    }
    if (oldVersion < 4) {
      try {
        await db.execute("ALTER TABLE conversations ADD COLUMN is_online INTEGER DEFAULT 0");
        await db.execute("ALTER TABLE conversations ADD COLUMN last_seen_at TEXT");
      } catch (e) {
        debugPrint("SQLite version 4 upgrade warning: $e");
      }
    }
    if (oldVersion < 5) {
      try {
        await db.execute("ALTER TABLE conversations ADD COLUMN disappearing_duration INTEGER DEFAULT 0");
        await db.execute("ALTER TABLE messages ADD COLUMN expires_at TEXT");
        await db.execute("ALTER TABLE messages ADD COLUMN reactions TEXT");
      } catch (e) {
        debugPrint("SQLite version 5 upgrade warning: $e");
      }
    }
    if (oldVersion < 6) {
      try {
        await db.execute("ALTER TABLE conversations ADD COLUMN is_muted INTEGER DEFAULT 0");
        await db.execute("ALTER TABLE conversations ADD COLUMN is_archived INTEGER DEFAULT 0");
        await db.execute('''
          CREATE TABLE IF NOT EXISTS story_keys (
            story_id TEXT PRIMARY KEY,
            media_key TEXT NOT NULL
          )
        ''');
      } catch (e) {
        debugPrint("SQLite version 6 upgrade warning: $e");
      }
    }
    if (oldVersion < 7) {
      try {
        await db.execute("ALTER TABLE messages ADD COLUMN edited_at TEXT");
      } catch (e) {
        debugPrint("SQLite version 7 upgrade warning: $e");
      }
    }
    if (oldVersion < 9) {
      try {
        await db.execute("ALTER TABLE messages ADD COLUMN alice_identity_key TEXT");
        await db.execute("ALTER TABLE messages ADD COLUMN alice_ephemeral_key TEXT");
        await db.execute("ALTER TABLE messages ADD COLUMN sender_name TEXT");
      } catch (e) {
        debugPrint('SQLite version 9 upgrade warning: $e');
      }
    }
    if (oldVersion < 8) {
      try {
        await db.execute("ALTER TABLE conversations ADD COLUMN is_group INTEGER DEFAULT 0");
        await db.execute('''
          CREATE TABLE IF NOT EXISTS groups (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            description TEXT DEFAULT '',
            avatar_url TEXT DEFAULT '',
            invite_link TEXT,
            created_by TEXT NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            last_message TEXT,
            last_message_at TEXT,
            unread_count INTEGER DEFAULT 0,
            is_muted INTEGER DEFAULT 0,
            is_archived INTEGER DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS group_members (
            group_id TEXT NOT NULL,
            user_id TEXT NOT NULL,
            role TEXT NOT NULL DEFAULT 'member',
            joined_at TEXT NOT NULL,
            PRIMARY KEY (group_id, user_id),
            FOREIGN KEY (group_id) REFERENCES groups (id) ON DELETE CASCADE
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS group_messages (
            id TEXT PRIMARY KEY,
            group_id TEXT NOT NULL,
            sender_id TEXT NOT NULL,
            sender_name TEXT,
            ciphertext TEXT NOT NULL,
            plaintext TEXT,
            msg_type TEXT NOT NULL,
            created_at TEXT NOT NULL,
            edited_at TEXT,
            reactions TEXT,
            is_pinned INTEGER DEFAULT 0,
            FOREIGN KEY (group_id) REFERENCES groups (id) ON DELETE CASCADE
          )
        ''');
      } catch (e) {
        debugPrint("SQLite version 8 upgrade warning: $e");
      }
    }
  }

  /// Creates the outbound queue table (shared between onCreate v2 and upgrade).
  /// Stores encrypted message payloads that haven't been ACK'd by the server yet.
  Future<void> _createOutboundQueueTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS outbound_queue (
        id TEXT PRIMARY KEY,
        conversation_id TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        created_at TEXT NOT NULL,
        retry_count INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  /// Generates a cryptographically secure 64-character hex string (32 random bytes).
  /// This is used as the SQLCipher passphrase for the per-account local database.
  String _generateSecureKey() {
    final rng = Random.secure();
    final bytes = List<int>.generate(32, (_) => rng.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
      _activeAccountId = null;
    }
  }
}
