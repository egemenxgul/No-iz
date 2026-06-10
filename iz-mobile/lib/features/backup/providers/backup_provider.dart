import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_service.dart';
import '../../auth/providers/account_provider.dart';
import '../../messages/providers/chat_provider.dart';
import 'backup_service.dart';

class BackupState {
	final bool isLoading;
	final String? error;
	final bool isSuccess;
	final DateTime? lastBackupAt;

	BackupState({
		this.isLoading = false,
		this.error,
		this.isSuccess = false,
		this.lastBackupAt,
	});

	BackupState copyWith({
		bool? isLoading,
		String? error,
		bool? isSuccess,
		DateTime? lastBackupAt,
	}) {
		return BackupState(
			isLoading: isLoading ?? this.isLoading,
			error: error,
			isSuccess: isSuccess ?? this.isSuccess,
			lastBackupAt: lastBackupAt ?? this.lastBackupAt,
		);
	}
}

class BackupNotifier extends Notifier<BackupState> {
	final _aesGcm = AesGcm.with256bits();
	final _pbkdf2 = Pbkdf2(
		macAlgorithm: Hmac(Sha256()),
		iterations: 10000,
		bits: 256,
	);

	@override
	BackupState build() {
		checkBackupStatus();
		return BackupState();
	}

	Future<void> checkBackupStatus() async {
		final service = ref.read(backupServiceProvider);
		try {
			final backup = await service.getBackup();
			if (backup != null && backup.containsKey('created_at')) {
				state = state.copyWith(lastBackupAt: DateTime.parse(backup['created_at'] as String));
			}
		} catch (_) {}
	}

	Uint8List _generateSalt() {
		final rng = Random.secure();
		final bytes = Uint8List(16);
		for (var i = 0; i < 16; i++) {
			bytes[i] = rng.nextInt(256);
		}
		return bytes;
	}

	Future<SecretKey> _deriveKey(String password, Uint8List salt) async {
		return await _pbkdf2.deriveKeyFromPassword(
			password: password,
			nonce: salt,
		);
	}

	/// Backs up the SQLite SQLCipher vault in zero-knowledge.
	Future<void> exportAndUploadBackup(String password) async {
		state = state.copyWith(isLoading: true, error: null);
		final activeAccountId = ref.read(accountProvider).activeAccountId ?? 'default';
		final service = ref.read(backupServiceProvider);

		try {
			final db = await DatabaseService().getDatabase(activeAccountId);

			// 1. Fetch all local SQLite tables
			final conversations = await db.query('conversations');
			final messages = await db.query('messages');
			final signalKeys = await db.query('signal_keys');

			// 2. Build structured JSON payload
			final payloadMap = {
				'conversations': conversations,
				'messages': messages,
				'signal_keys': signalKeys,
			};
			final payloadString = jsonEncode(payloadMap);
			final payloadBytes = utf8.encode(payloadString);

			// 3. Generate salt and derive encryption key
			final saltBytes = _generateSalt();
			final secretKey = await _deriveKey(password, saltBytes);

			// 4. Encrypt using AES-256-GCM
			final nonce = _aesGcm.newNonce();
			final secretBox = await _aesGcm.encrypt(
				payloadBytes,
				secretKey: secretKey,
				nonce: nonce,
			);

			final encryptedBytes = Uint8List.fromList(secretBox.concatenation());
			final encryptedBlobBase64 = base64Encode(encryptedBytes);
			final saltBase64 = base64Encode(saltBytes);

			// 5. Upload backup to backend
			await service.saveBackup(encryptedBlobBase64, saltBase64);

			state = state.copyWith(
				isLoading: false,
				isSuccess: true,
				lastBackupAt: DateTime.now(),
			);
		} catch (e) {
			debugPrint('Failed to export backup: $e');
			state = state.copyWith(
				isLoading: false,
				error: 'Yedekleme başarısız: $e',
			);
			rethrow;
		}
	}

	/// Restores the SQLite database in zero-knowledge.
	Future<void> downloadAndRestoreBackup(String password) async {
		state = state.copyWith(isLoading: true, error: null);
		final activeAccountId = ref.read(accountProvider).activeAccountId ?? 'default';
		final service = ref.read(backupServiceProvider);

		try {
			// 1. Fetch active backup from cloud
			final backup = await service.getBackup();
			if (backup == null) {
				throw 'Sistemde kayıtlı yedekleme bulunamadı';
			}

			final encryptedBlobBase64 = backup['encrypted_blob'] as String;
			final saltBase64 = backup['salt'] as String;
			final createdAtStr = backup['created_at'] as String;

			final encryptedBytes = base64Decode(encryptedBlobBase64);
			final saltBytes = base64Decode(saltBase64);

			// 2. Derive decryption key using PBKDF2
			final secretKey = await _deriveKey(password, saltBytes);

			// 3. Reconstruct SecretBox and decrypt GCM payload
			final secretBox = SecretBox.fromConcatenation(
				encryptedBytes,
				nonceLength: 12,
				macLength: 16,
			);

			final decryptedBytes = await _aesGcm.decrypt(
				secretBox,
				secretKey: secretKey,
			);

			final payloadString = utf8.decode(decryptedBytes);
			final payloadMap = jsonDecode(payloadString) as Map<String, dynamic>;

			// 4. Overwrite SQLite database records
			final db = await DatabaseService().getDatabase(activeAccountId);

			await db.transaction((txn) async {
				// Clear current tables
				await txn.delete('conversations');
				await txn.delete('messages');
				await txn.delete('signal_keys');

				// Restore Conversations
				final convRows = payloadMap['conversations'] as List<dynamic>? ?? [];
				for (final row in convRows) {
					await txn.insert('conversations', Map<String, dynamic>.from(row));
				}

				// Restore Messages
				final msgRows = payloadMap['messages'] as List<dynamic>? ?? [];
				for (final row in msgRows) {
					await txn.insert('messages', Map<String, dynamic>.from(row));
				}

				// Restore Signal Keys
				final keyRows = payloadMap['signal_keys'] as List<dynamic>? ?? [];
				for (final row in keyRows) {
					await txn.insert('signal_keys', Map<String, dynamic>.from(row));
				}
			});

			// 5. Force refresh conversation notifier state to render the restored history
			ref.read(conversationProvider.notifier).loadConversations();

			state = state.copyWith(
				isLoading: false,
				isSuccess: true,
				lastBackupAt: DateTime.parse(createdAtStr),
			);
		} catch (e) {
			debugPrint('Failed to restore backup: $e');
			state = state.copyWith(
				isLoading: false,
				error: 'Geri yükleme başarısız. Şifrenizi kontrol edin.',
			);
			rethrow;
		}
	}
}

final backupProvider = NotifierProvider<BackupNotifier, BackupState>(BackupNotifier.new);
