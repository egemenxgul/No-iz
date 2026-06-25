import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'crypto_service.dart';
import 'dart:convert';

class IdentityManager {
  final CryptoService _crypto;
  final FlutterSecureStorage _storage;

  static const _keyIdentityPriv = 'auth_identity_priv';
  static const _keyIdentityPub = 'auth_identity_pub';
  static const _keySignedPreKeyPriv = 'auth_spk_priv';
  static const _keySignedPreKeyPub = 'auth_spk_pub';

  IdentityManager(this._crypto, this._storage);

  Future<void> generateAndStoreIdentity() async {
    // 1. Generate Identity Key Pair (Ed25519 for signing)
    final identityKeyPair = await _crypto.generateIdentityKeyPair();
    final identityPub = await identityKeyPair.extractPublicKey();
    final identityPriv = await identityKeyPair.extractPrivateKeyBytes();

    // 2. Generate Signed PreKey (X25519 for DH)
    final spkKeyPair = await _crypto.generateKeyPair();
    final spkPub = await spkKeyPair.extractPublicKey();
    final spkPriv = await spkKeyPair.extractPrivateKeyBytes();

    // 3. Store securely
    await _storage.write(key: _keyIdentityPriv, value: base64Encode(identityPriv));
    await _storage.write(key: _keyIdentityPub, value: base64Encode(identityPub.bytes));
    await _storage.write(key: _keySignedPreKeyPriv, value: base64Encode(spkPriv));
    await _storage.write(key: _keySignedPreKeyPub, value: base64Encode(spkPub.bytes));
  }

  Future<SimpleKeyPair?> getIdentityKeyPair() async {
    final privBase64 = await _storage.read(key: _keyIdentityPriv);
    if (privBase64 == null) return null;
    
    final privBytes = base64Decode(privBase64);
    return SimpleKeyPairData(
      privBytes,
      publicKey: await (await Ed25519().newKeyPairFromSeed(privBytes)).extractPublicKey(),
      type: KeyPairType.ed25519,
    );
  }

  Future<SimpleKeyPair?> getSignedPreKeyPair() async {
    final privBase64 = await _storage.read(key: _keySignedPreKeyPriv);
    if (privBase64 == null) return null;
    
    final privBytes = base64Decode(privBase64);
    final pubBytes = base64Decode(await _storage.read(key: _keySignedPreKeyPub) ?? '');
    
    return SimpleKeyPairData(
      privBytes,
      publicKey: SimplePublicKey(pubBytes, type: KeyPairType.x25519),
      type: KeyPairType.x25519,
    );
  }

  Future<Map<String, String>> getPublicBundle() async {
    return {
      'identity_key': await _storage.read(key: _keyIdentityPub) ?? '',
      'signed_prekey': await _storage.read(key: _keySignedPreKeyPub) ?? '',
    };
  }

  /// Generates [count] new one-time prekeys for Signal Protocol.
  /// Each key is a fresh X25519 key pair; only the public key is returned.
  /// The private keys are stored in secure storage under their key ID.
  Future<List<Map<String, dynamic>>> generateOneTimePrekeys(int count) async {
    final keys = <Map<String, dynamic>>[];

    // Load the current highest key ID from storage to avoid collisions
    final lastIdStr = await _storage.read(key: '_otpk_last_id') ?? '0';
    int nextId = int.parse(lastIdStr) + 1;

    for (int i = 0; i < count; i++) {
      final keyPair = await _crypto.generateKeyPair();
      final pub = await keyPair.extractPublicKey();
      final priv = await keyPair.extractPrivateKeyBytes();
      final keyId = nextId + i;

      // Store private key securely
      await _storage.write(
        key: '_otpk_priv_$keyId',
        value: base64Encode(priv),
      );

      keys.add({
        'key_id': keyId,
        'public_key': base64Encode(pub.bytes),
      });
    }

    // Persist last ID
    await _storage.write(
      key: '_otpk_last_id',
      value: '${nextId + count - 1}',
    );

    return keys;
  }
}
