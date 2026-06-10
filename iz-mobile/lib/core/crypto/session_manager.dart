import 'dart:typed_data';
import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'crypto_service.dart';
import 'ratchet_service.dart';
import 'ratchet_state.dart';

class SessionManager {
  final CryptoService _crypto;
  final RatchetService _ratchet;

  // In-memory session cache (should be persisted in DB)
  final Map<String, RatchetState> _sessions = {};

  SessionManager(this._crypto, this._ratchet);

  // Alice starts a session with Bob
  Future<Map<String, dynamic>> establishSession({
    required String conversationId,
    required SimpleKeyPair aliceIdentityKeyPair,
    required Map<String, dynamic> bobBundle, // Fetched from server
  }) async {
    // Check if session already exists
    if (_sessions.containsKey(conversationId)) {
      final state = _sessions[conversationId]!;
      final ephPub = await state.dhKeyPair.extractPublicKey();
      return {
        'sharedKey': null, // Not needed if session exists
        'aliceEphemeralPub': _crypto.toBase64(Uint8List.fromList(ephPub.bytes)),
        'state': state,
      };
    }

    // 1. Generate Ephemeral Key Pair (EK_A)
    final ephemeralKeyPair = await _crypto.generateKeyPair();
    final ephemeralPublicKey = await ephemeralKeyPair.extractPublicKey();

    // Bob's Keys from Bundle
    final bobIdentityPub = _decodePublicKey(bobBundle['identity_key']);
    final bobSignedPreKeyPub = _decodePublicKey(bobBundle['signed_prekey']);
    final bobOPKPub = bobBundle['one_time_prekey'] != null 
        ? _decodePublicKey(bobBundle['one_time_prekey']) 
        : null;

    // 2. Perform X3DH shared secret calculation
    final dh1 = await _crypto.calculateSharedSecret(aliceIdentityKeyPair, bobSignedPreKeyPub);
    final dh2 = await _crypto.calculateSharedSecret(ephemeralKeyPair, bobIdentityPub);
    final dh3 = await _crypto.calculateSharedSecret(ephemeralKeyPair, bobSignedPreKeyPub);

    final List<int> dhInput = [...dh1, ...dh2, ...dh3];
    if (bobOPKPub != null) {
      final dh4 = await _crypto.calculateSharedSecret(ephemeralKeyPair, bobOPKPub);
      dhInput.addAll(dh4);
    }

    // 3. Derive Shared Key
    final f = Uint8List(32)..fillRange(0, 32, 0xFF);
    final ikm = Uint8List.fromList([...f, ...dhInput]);
    final sharedKey = await _crypto.hkdf(ikm, info: utf8.encode('iz_x3dh_v1'));

    // 4. Initialize Double Ratchet
    final state = await _ratchet.initRatchet(
      conversationId: conversationId,
      sharedSecret: sharedKey,
      localDhKeyPair: ephemeralKeyPair,
      remoteDhPub: bobSignedPreKeyPub, // Initial remote DH key is Bob's SPK
    );
    
    _sessions[conversationId] = state;
    
    return {
      'sharedKey': sharedKey,
      'aliceEphemeralPub': _crypto.toBase64(Uint8List.fromList(ephemeralPublicKey.bytes)),
      'state': state,
    };
  }

  // Bob receives the first message from Alice
  Future<RatchetState> receiveSession({
    required String conversationId,
    required SimpleKeyPair bobIdentityKeyPair,
    required SimpleKeyPair bobSignedPreKeyPairs,
    required String aliceIdentityPubBase64,
    required String aliceEphemeralPubBase64,
  }) async {
    if (_sessions.containsKey(conversationId)) return _sessions[conversationId]!;

    final aliceIdentityPub = _decodePublicKey(aliceIdentityPubBase64);
    final aliceEphemeralPub = _decodePublicKey(aliceEphemeralPubBase64);

    // DH1, DH2, DH3
    final dh1 = await _crypto.calculateSharedSecret(bobSignedPreKeyPairs, aliceIdentityPub);
    final dh2 = await _crypto.calculateSharedSecret(bobIdentityKeyPair, aliceEphemeralPub);
    final dh3 = await _crypto.calculateSharedSecret(bobSignedPreKeyPairs, aliceEphemeralPub);

    final List<int> dhInput = [...dh1, ...dh2, ...dh3];

    final f = Uint8List(32)..fillRange(0, 32, 0xFF);
    final ikm = Uint8List.fromList([...f, ...dhInput]);
    final sharedKey = await _crypto.hkdf(ikm, info: utf8.encode('iz_x3dh_v1'));

    final state = await _ratchet.initRatchet(
      conversationId: conversationId,
      sharedSecret: sharedKey,
      localDhKeyPair: bobSignedPreKeyPairs,
      remoteDhPub: aliceEphemeralPub,
    );
    
    _sessions[conversationId] = state;
    return state;
  }

  // Encrypt with Ratchet
  Future<Map<String, dynamic>> encryptMessage(String conversationId, String plaintext) async {
    final state = _sessions[conversationId];
    if (state == null) throw 'Oturum bulunamadı';

    final step = await _ratchet.encryptStep(state);
    final ciphertext = await _crypto.encrypt(utf8.encode(plaintext), step['messageKey']);

    final dhPub = await state.dhKeyPair.extractPublicKey();
    
    return {
      'ciphertext': ciphertext,
      'counter': step['counter'],
      'ratchet_key': _crypto.toBase64(Uint8List.fromList(dhPub.bytes)),
    };
  }

  // Decrypt with Ratchet
  Future<String> decryptMessage(String conversationId, String ciphertext, String remoteDhPubBase64, int counter) async {
    final state = _sessions[conversationId];
    if (state == null) throw 'Oturum bulunamadı';

    final remoteDhPub = _decodePublicKey(remoteDhPubBase64);
    final messageKey = await _ratchet.decryptStep(state, remoteDhPub, counter);
    
    final plaintextBytes = await _crypto.decrypt(ciphertext, messageKey);
    return utf8.decode(plaintextBytes);
  }

  SimplePublicKey _decodePublicKey(String base64) {
    final bytes = _crypto.fromBase64(base64);
    return SimplePublicKey(bytes, type: KeyPairType.x25519);
  }
}
