import 'dart:typed_data';
import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'crypto_service.dart';
import 'ratchet_state.dart';

class RatchetService {
  final hmacSha256 = Hmac.sha256();
  final CryptoService _crypto;

  RatchetService(this._crypto);

  // Alice/Bob initial setup
  Future<RatchetState> initRatchet({
    required String conversationId,
    required Uint8List sharedSecret,
    required SimpleKeyPair localDhKeyPair,
    SimplePublicKey? remoteDhPub,
  }) async {
    // KDF_RK(shared_secret) -> root_key, chain_key
    // For Alice (sender), we set the send chain. For Bob, we wait for first message.
    final keys = await kdfRoot(sharedSecret, sharedSecret); // Simplified initial root
    
    return RatchetState(
      conversationId: conversationId,
      rootKey: keys['rootKey']!,
      sendChainKey: keys['chainKey'],
      dhKeyPair: localDhKeyPair,
      remoteDhPub: remoteDhPub,
    );
  }

  // Symmetric-key ratchet for sending
  Future<Map<String, dynamic>> encryptStep(RatchetState state) async {
    final chainKeys = await kdfChain(state.sendChainKey!);
    state.sendChainKey = chainKeys['chainKey'];
    final messageKey = chainKeys['messageKey'];
    final counter = state.sendCounter;
    state.sendCounter++;

    return {
      'messageKey': messageKey,
      'counter': counter,
    };
  }

  // DH and Symmetric-key ratchet for receiving
  Future<Uint8List> decryptStep(RatchetState state, SimplePublicKey remoteDhPub, int msgCounter) async {
    // 1. Check for DH ratchet step
    if (state.remoteDhPub == null || remoteDhPub.bytes != state.remoteDhPub!.bytes) {
      state.prevSendCounter = state.sendCounter;
      state.sendCounter = 0;
      state.recvCounter = 0;
      state.remoteDhPub = remoteDhPub;

      // DH Ratchet Step
      final dhSecret = await _crypto.calculateSharedSecret(state.dhKeyPair, remoteDhPub);
      final rootKeys = await kdfRoot(state.rootKey, dhSecret);
      state.rootKey = rootKeys['rootKey']!;
      state.recvChainKey = rootKeys['chainKey']!;

      // New DH key for next sending ratchet
      state.dhKeyPair = await _crypto.generateKeyPair();
      final newDhSecret = await _crypto.calculateSharedSecret(state.dhKeyPair, remoteDhPub);
      final nextRootKeys = await kdfRoot(state.rootKey, newDhSecret);
      state.rootKey = nextRootKeys['rootKey']!;
      state.sendChainKey = nextRootKeys['chainKey']!;
    }

    // 2. Symmetric-key ratchet for receiving
    // Skip messages if counter is ahead (TODO: store skipped keys)
    while (state.recvCounter < msgCounter) {
      final keys = await kdfChain(state.recvChainKey!);
      state.recvChainKey = keys['chainKey'];
      // Store skipped message key...
      state.recvCounter++;
    }

    final keys = await kdfChain(state.recvChainKey!);
    state.recvChainKey = keys['chainKey'];
    state.recvCounter++;
    return keys['messageKey']!;
  }

  // Root KDF: derived from shared secret and old root key
  Future<Map<String, Uint8List>> kdfRoot(Uint8List rootKey, Uint8List dhSecret) async {
    final hkdf = Hkdf(
      hmac: hmacSha256,
      outputLength: 64,
    );
    
    final output = await hkdf.deriveKey(
      secretKey: SecretKey(dhSecret),
      nonce: rootKey,
      info: utf8.encode('WhisperRatchet'),
    );
    
    final bytes = await output.extractBytes();
    return {
      'rootKey': Uint8List.fromList(bytes.sublist(0, 32)),
      'chainKey': Uint8List.fromList(bytes.sublist(32, 64)),
    };
  }

  // Chain KDF: advances chain and produces message key
  Future<Map<String, Uint8List>> kdfChain(Uint8List chainKey) async {
    final hmac = Hmac.sha256();
    
    // Message key = HMAC(ChainKey, 0x01)
    final messageKeyOutput = await hmac.calculateMac(
      [0x01],
      secretKey: SecretKey(chainKey),
    );
    
    // Next chain key = HMAC(ChainKey, 0x02)
    final nextChainKeyOutput = await hmac.calculateMac(
      [0x02],
      secretKey: SecretKey(chainKey),
    );

    return {
      'messageKey': Uint8List.fromList(messageKeyOutput.bytes),
      'chainKey': Uint8List.fromList(nextChainKeyOutput.bytes),
    };
  }
}
