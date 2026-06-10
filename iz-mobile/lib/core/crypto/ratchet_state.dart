import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

class RatchetState {
  final String conversationId;
  Uint8List rootKey;
  Uint8List? sendChainKey;
  Uint8List? recvChainKey;
  SimpleKeyPair dhKeyPair;
  SimplePublicKey? remoteDhPub;
  int sendCounter;
  int recvCounter;
  int prevSendCounter;
  
  // Stores skipped message keys for out-of-order delivery
  final Map<int, Uint8List> skippedMessageKeys;

  RatchetState({
    required this.conversationId,
    required this.rootKey,
    this.sendChainKey,
    this.recvChainKey,
    required this.dhKeyPair,
    this.remoteDhPub,
    this.sendCounter = 0,
    this.recvCounter = 0,
    this.prevSendCounter = 0,
    Map<int, Uint8List>? skippedMessageKeys,
  }) : skippedMessageKeys = skippedMessageKeys ?? {};
}
