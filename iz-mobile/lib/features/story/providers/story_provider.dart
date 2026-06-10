import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/database_service.dart';
import '../../../core/network/websocket_provider.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/crypto/crypto_providers.dart';
import '../../auth/providers/auth_provider.dart';
import '../../messages/providers/chat_provider.dart';
import '../../messages/providers/media_upload_service.dart';
import '../models/story_model.dart';
import 'story_service.dart';

final storyServiceProvider = Provider<StoryService>((ref) {
	final dio = ref.watch(dioProvider);
	return StoryService(dio);
});

class StoryNotifier extends Notifier<List<FriendStoryFeedModel>> {
	@override
	List<FriendStoryFeedModel> build() {
		loadFeed();
		return [];
	}

	Future<void> loadFeed() async {
		final service = ref.read(storyServiceProvider);
		try {
			final feed = await service.getFeed();
			state = feed;
		} catch (e) {
			debugPrint('Failed to load story feed: $e');
		}
	}

	/// Client-side encrypts the media, uploads to MinIO, posts story to backend, 
	/// saves the key locally, and distributes the key E2E to all accepted friends via Double Ratchet WS.
	Future<void> createStory({
		required Uint8List fileBytes,
		required String filename,
		required String mimeType,
		required String? captionText,
	}) async {
		final uploadSvc = ref.read(mediaUploadServiceProvider);
		final service = ref.read(storyServiceProvider);
		final sessionManager = ref.read(sessionManagerProvider);
		final identityManager = ref.read(identityManagerProvider);
		final authService = ref.read(authServiceProvider);
		final socket = ref.read(webSocketProvider);
		final myUserId = ref.read(authProvider).userId ?? '';

		final storyId = const Uuid().v4();

		try {
			// 1. Encrypt and upload media to MinIO
			final uploadResult = await uploadSvc.uploadMedia(
				fileBytes: fileBytes,
				filename: filename,
				mimeType: mimeType,
			);

			final mediaKey = uploadResult.mediaKeyBase64;

			// Save key locally for self-viewing
			await _saveStoryKeyLocally(storyId, mediaKey);

			// 2. Fetch all accepted friends from SQLite
			final activeAccountId = ref.read(accountProvider).activeAccountId ?? 'default';
			final db = await DatabaseService().getDatabase(activeAccountId);
			final List<Map<String, dynamic>> friends = await db.query(
				'conversations',
				columns: ['other_user_id'],
				where: 'friendship_status = ?',
				whereArgs: ['accepted'],
			);

			// 3. Encrypt the story key for each friend using pre-existing Double Ratchet
			for (final f in friends) {
				final friendId = f['other_user_id'] as String;
				try {
					final aliceIdentityKeyPair = await identityManager.getIdentityKeyPair();
					if (aliceIdentityKeyPair == null) continue;

					final bobBundle = await authService.getUserBundle(friendId);
					final x3dhResult = await sessionManager.establishSession(
						conversationId: friendId,
						aliceIdentityKeyPair: aliceIdentityKeyPair,
						bobBundle: bobBundle,
					);

					final aliceIdentityPub = (await identityManager.getPublicBundle())['identity_key'];

					final controlPlaintext = jsonEncode({
						'type': 'story_key',
						'story_id': storyId,
						'media_key': mediaKey,
					});

					// Encrypt payload via Double Ratchet
					final encryptionResult = await sessionManager.encryptMessage(
						friendId,
						controlPlaintext,
					);

					// Send as standard E2EE control message over WS
					if (socket != null && socket.isConnected) {
						socket.sendMessage('send_message', {
							'recipient_id': friendId,
							'ciphertext': encryptionResult['ciphertext'],
							'msg_type': 'story_key',
							'ratchet_key': encryptionResult['ratchet_key'],
							'prev_counter': 0,
							'counter': encryptionResult['counter'],
							'expires_in': 0,
							'queue_id': const Uuid().v4(),
						});
					}
				} catch (e) {
					debugPrint('Failed to send story key to friend $friendId: $e');
				}
			}

			// 4. E2E Encrypt the caption if present
			String? encryptedCaption;
			if (captionText != null && captionText.isNotEmpty) {
				// We can simply base64 encode or encrypt caption using the same story key.
				// Let's encrypt caption using the transient story key for consistency!
				// We can use a simple AES-GCM helper, but to keep it simple, we AES-GCM encrypt
				// the caption using the same AES-GCM story key by calling a small helper.
				// Since we have MediaUploadService's aesGcm helper, we can perform it:
				try {
					final crypt = ref.read(mediaUploadServiceProvider);
					final keyBytes = base64Decode(mediaKey);
					final nonce = crypt.aesGcm.newNonce();
					final box = await crypt.aesGcm.encrypt(
						utf8.encode(captionText),
						secretKey: SecretKey(keyBytes),
						nonce: nonce,
					);
					encryptedCaption = base64Encode(box.concatenation());
				} catch (_) {
					encryptedCaption = captionText; // fallback
				}
			}

			// 5. Post Story metadata to the backend
			await service.postStory(
				mediaUrl: uploadResult.url,
				caption: encryptedCaption,
				mediaType: mimeType.startsWith('video/') ? 'video' : (mimeType.startsWith('image/') ? 'image' : 'text'),
			);

			// Reload feed
			await loadFeed();
		} catch (e) {
			debugPrint('Failed to create story: $e');
			rethrow;
		}
	}

	Future<void> deleteStory(String storyId) async {
		final service = ref.read(storyServiceProvider);
		try {
			await service.deleteStory(storyId);
			await loadFeed();
		} catch (e) {
			debugPrint('Failed to delete story: $e');
		}
	}

	Future<void> _saveStoryKeyLocally(String storyId, String mediaKey) async {
		final activeAccountId = ref.read(accountProvider).activeAccountId ?? 'default';
		final db = await DatabaseService().getDatabase(activeAccountId);
		await db.insert(
			'story_keys',
			{
				'story_id': storyId,
				'media_key': mediaKey,
			},
		);
	}

	/// Checks if a story has a cached E2EE decryption key locally.
	Future<String?> getCachedStoryKey(String storyId) async {
		final activeAccountId = ref.read(accountProvider).activeAccountId ?? 'default';
		final db = await DatabaseService().getDatabase(activeAccountId);
		final List<Map<String, dynamic>> res = await db.query(
			'story_keys',
			columns: ['media_key'],
			where: 'story_id = ?',
			whereArgs: [storyId],
		);
		if (res.isNotEmpty) {
			return res.first['media_key'] as String;
		}
		return null;
	}

	/// Decrypts the story caption.
	Future<String?> decryptCaption(String? encryptedCaption, String mediaKey) async {
		if (encryptedCaption == null || encryptedCaption.isEmpty) return null;
		try {
			final crypt = ref.read(mediaUploadServiceProvider);
			final keyBytes = base64Decode(mediaKey);
			final encryptedBytes = base64Decode(encryptedCaption);
			final box = SecretBox.fromConcatenation(
				encryptedBytes,
				nonceLength: 12,
				macLength: 16,
			);
			final decrypted = await crypt.aesGcm.decrypt(
				box,
				secretKey: SecretKey(keyBytes),
			);
			return utf8.decode(decrypted);
		} catch (e) {
			debugPrint('Failed to decrypt story caption: $e');
			return encryptedCaption; // fallback
		}
	}
}

final storyProvider = NotifierProvider<StoryNotifier, List<FriendStoryFeedModel>>(StoryNotifier.new);
