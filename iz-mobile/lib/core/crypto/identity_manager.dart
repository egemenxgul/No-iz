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
}
