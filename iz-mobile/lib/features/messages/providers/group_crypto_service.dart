import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../core/network/dio_provider.dart';
import '../../../core/crypto/crypto_providers.dart';
import '../../../core/crypto/session_manager.dart';
import '../../../core/crypto/identity_manager.dart';
import '../../auth/providers/auth_provider.dart';

final groupCryptoServiceProvider = Provider<GroupCryptoService>((ref) {
  return GroupCryptoService(
    dio: ref.watch(dioProvider),
    sessionManager: ref.watch(sessionManagerProvider),
    identityManager: ref.watch(identityManagerProvider),
    authService: ref.watch(authServiceProvider),
  );
});

/// GroupCryptoService manages Sender Keys (AES-GCM) for group chats.
/// It uses cryptography package for true AES-256-GCM.
class GroupCryptoService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final Dio dio;
  final SessionManager sessionManager;
  final IdentityManager identityManager;
  final AuthService authService;
  
  GroupCryptoService({
    required this.dio,
    required this.sessionManager,
    required this.identityManager,
    required this.authService,
  });

  /// Generates a random 32-byte AES-GCM Sender Key.
  Future<String> generateSenderKey() async {
    final random = Random.secure();
    final keyBytes = Uint8List.fromList(List.generate(32, (_) => random.nextInt(256)));
    return base64Encode(keyBytes);
  }

  /// Saves a sender key locally.
  Future<void> saveSenderKeyLocally(String groupId, String senderId, String base64Key) async {
    final key = 'group_${groupId}_$senderId';
    await _storage.write(key: key, value: base64Key);
  }

  /// Retrieves a sender key from local storage.
  Future<String?> getSenderKey(String groupId, String senderId) async {
    final key = 'group_${groupId}_$senderId';
    return await _storage.read(key: key);
  }

  /// Encrypts the plaintext with AES-GCM using the user's Sender Key.
  Future<Map<String, String>> encryptGroupMessage(String groupId, String myUserId, String plaintext) async {
    var senderKeyB64 = await getSenderKey(groupId, myUserId);
    if (senderKeyB64 == null) {
      throw Exception('Sender key not found for group $groupId');
    }

    final keyBytes = base64Decode(senderKeyB64);
    final secretKey = SecretKey(keyBytes);

    final random = Random.secure();
    final nonce = List<int>.generate(12, (_) => random.nextInt(256));

    final algorithm = AesGcm.with256bits();
    final secretBox = await algorithm.encrypt(
      utf8.encode(plaintext),
      secretKey: secretKey,
      nonce: nonce,
    );

    return {
      'ciphertext': base64Encode(secretBox.cipherText),
      'iv': base64Encode(secretBox.nonce),
      'mac': base64Encode(secretBox.mac.bytes),
    };
  }

  /// Decrypts the ciphertext with AES-GCM using the given sender's Sender Key.
  Future<String> decryptGroupMessage(String groupId, String senderId, String ciphertextB64, String ivB64, String macB64) async {
    final senderKeyB64 = await getSenderKey(groupId, senderId);
    if (senderKeyB64 == null) {
      throw Exception('Sender key missing for $senderId in group $groupId. Fetching required.');
    }

    final keyBytes = base64Decode(senderKeyB64);
    final secretKey = SecretKey(keyBytes);

    final cipherText = base64Decode(ciphertextB64);
    final nonce = base64Decode(ivB64);
    final macBytes = base64Decode(macB64);

    final secretBox = SecretBox(
      cipherText,
      nonce: nonce,
      mac: Mac(macBytes),
    );

    final algorithm = AesGcm.with256bits();
    final clearText = await algorithm.decrypt(
      secretBox,
      secretKey: secretKey,
    );

    return utf8.decode(clearText);
  }

  /// Distributes the Sender Key to all group members using 1-to-1 ECDH encryption.
  Future<void> distributeSenderKey(String groupId, String senderKeyB64, String myUserId) async {
    // 1. Fetch group members
    final membersRes = await dio.get('/api/groups/$groupId/members');
    final members = (membersRes.data['members'] as List).cast<Map<String, dynamic>>();

    // 2. Get our identity for 1-1 session establishment
    final aliceIdentityKeyPair = await identityManager.getIdentityKeyPair();
    if (aliceIdentityKeyPair == null) throw Exception('Local identity key not found');

    List<Map<String, dynamic>> distributionRecords = [];

    // 3. Encrypt the Sender Key individually for each member
    for (var member in members) {
      final String memberId = member['user_id'];
      if (memberId == myUserId) continue;

      try {
        // Establish 1-1 session
        final bobBundle = await authService.getUserBundle(memberId);
        await sessionManager.establishSession(
          conversationId: memberId,
          aliceIdentityKeyPair: aliceIdentityKeyPair,
          bobBundle: bobBundle,
        );

        // Encrypt the sender key
        final encryptedRecord = await sessionManager.encryptMessage(memberId, senderKeyB64);
        
        distributionRecords.add({
          'recipient_id': memberId,
          'encrypted_key': encryptedRecord,
        });
      } catch (e) {
        // Log error but continue with other members
        print('Failed to distribute sender key to $memberId: $e');
      }
    }

    // 4. Upload to backend
    final distributionJson = jsonEncode(distributionRecords);
    await dio.post('/api/groups/$groupId/sender_keys', data: {
      'distribution': distributionJson,
    });
  }

  /// Syncs SenderKeys from the backend for the current user.
  Future<void> syncSenderKeys(String groupId, String myUserId) async {
    try {
      final response = await dio.get('/api/groups/$groupId/sender_keys');
      final senderKeys = (response.data['sender_keys'] as List?)?.cast<Map<String, dynamic>>() ?? [];

      for (var sk in senderKeys) {
        final senderId = sk['sender_id'];
        if (senderId == myUserId) continue; // Skip our own

        final distributionStr = sk['distribution'] as String;
        if (distributionStr.isEmpty) continue;

        final distributionArr = jsonDecode(distributionStr) as List<dynamic>;
        
        for (var record in distributionArr) {
          if (record['recipient_id'] == myUserId) {
            // Found our copy! Decrypt using 1-1 session with senderId
            try {
              final encKey = record['encrypted_key'];
              final decryptedSenderKey = await sessionManager.decryptMessage(
                conversationId: senderId, // The 1-1 session is keyed by senderId
                ciphertextBase64: encKey['ciphertext'],
                aliceIdentityKeyBase64: encKey['alice_identity_key'],
                aliceEphemeralKeyBase64: encKey['alice_ephemeral_key'],
                msgType: encKey['msg_type'] ?? 'text',
              );
              
              if (decryptedSenderKey != null && decryptedSenderKey.isNotEmpty) {
                await saveSenderKeyLocally(groupId, senderId, decryptedSenderKey);
              }
            } catch (e) {
              print('Could not decrypt sender key from $senderId: $e');
            }
          }
        }
      }
    } catch (e) {
      print('Failed to sync sender keys: $e');
    }
  }
}
