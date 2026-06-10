import 'package:cryptography/cryptography.dart';
import 'dart:convert';
import 'dart:typed_data';

class CryptoService {
  final x25519 = X25519();
  final ed25519 = Ed25519();
  final aesGcm = AesGcm.with256bits();

  // Generate a new X25519 key pair (for DH)
  Future<SimpleKeyPair> generateKeyPair() async {
    return await x25519.newKeyPair();
  }

  // Generate a new Ed25519 key pair (for Identity/Signing)
  Future<SimpleKeyPair> generateIdentityKeyPair() async {
    return await ed25519.newKeyPair();
  }

  // Calculate shared secret using X25519
  Future<Uint8List> calculateSharedSecret(SimpleKeyPair localPrivate, SimplePublicKey remotePublic) async {
    final secret = await x25519.sharedSecretKey(
      keyPair: localPrivate,
      remotePublicKey: remotePublic,
    );
    final bytes = await secret.extractBytes();
    return Uint8List.fromList(bytes);
  }

  // HKDF-SHA256 for key derivation (Signal spec)
  Future<Uint8List> hkdf(Uint8List ikm, {Uint8List? salt, List<int>? info}) async {
    final algorithm = Hkdf(
      hmac: Hmac.sha256(),
      outputLength: 32,
    );
    final secretKey = SecretKey(ikm);
    final output = await algorithm.deriveKey(
      secretKey: secretKey,
      nonce: salt ?? Uint8List(0),
      info: info ?? [],
    );
    final bytes = await output.extractBytes();
    return Uint8List.fromList(bytes);
  }

  // AES-GCM Encryption
  Future<String> encrypt(Uint8List plaintext, Uint8List key) async {
    final secretKey = SecretKey(key);
    final nonce = aesGcm.newNonce();
    final secretBox = await aesGcm.encrypt(
      plaintext,
      secretKey: secretKey,
      nonce: nonce,
    );
    return base64Encode(secretBox.concatenation());
  }

  // AES-GCM Decryption
  Future<Uint8List> decrypt(String ciphertextBase64, Uint8List key) async {
    final secretKey = SecretKey(key);
    final data = base64Decode(ciphertextBase64);
    final secretBox = SecretBox.fromConcatenation(data, nonceLength: 12, macLength: 16);
    final cleartext = await aesGcm.decrypt(
      secretBox,
      secretKey: secretKey,
    );
    return Uint8List.fromList(cleartext);
  }

  // Sign data using Ed25519
  Future<String> sign(SimpleKeyPair keyPair, Uint8List data) async {
    final signature = await ed25519.sign(data, keyPair: keyPair);
    return base64Encode(signature.bytes);
  }

  // Helpers
  Uint8List fromBase64(String base64) => base64Decode(base64);
  String toBase64(Uint8List bytes) => base64Encode(bytes);
}
