import { sharedSecret, generateKeyPair, KeyPair, toHex } from './x25519';
import { deriveKey } from './hkdf';
import { encrypt, decrypt } from './aes-gcm';

export interface RatchetState {
  rootKey: Uint8Array;
  sendChainKey: Uint8Array | null;
  recvChainKey: Uint8Array | null;
  remoteRatchetPub: Uint8Array | null;
  localRatchetKeyPair: KeyPair;
  sendCount: number;
  recvCount: number;
  prevSendCount: number;
  skippedMessageKeys: Record<string, Uint8Array>; // { "pub_hex:index": key }
}

const MAX_SKIP = 1000;

/**
 * Initializes a new ratchet state for a conversation.
 */
export function initRatchet(rootKey: Uint8Array, remotePub: Uint8Array | null, isInitiator: boolean): RatchetState {
  const state: RatchetState = {
    rootKey,
    sendChainKey: null,
    recvChainKey: null,
    remoteRatchetPub: remotePub,
    localRatchetKeyPair: generateKeyPair(),
    sendCount: 0,
    recvCount: 0,
    prevSendCount: 0,
    skippedMessageKeys: {},
  };

  if (isInitiator && remotePub) {
    const { rootKey: newRoot, chainKey } = kdfRoot(state.rootKey, sharedSecret(state.localRatchetKeyPair.privateKey, remotePub));
    state.rootKey = newRoot;
    state.sendChainKey = chainKey;
  }

  return state;
}

/**
 * Encrypts a message and advances the sending chain.
 */
export async function ratchetEncrypt(state: RatchetState, plaintext: string) {
  if (!state.sendChainKey) {
    throw new Error('Ratchet not initialized for sending');
  }

  const { chainKey: newChain, messageKey } = kdfChain(state.sendChainKey);
  state.sendChainKey = newChain;

  const { ciphertext, iv } = await encrypt(plaintext, messageKey);
  
  const header = {
    ratchetPub: state.localRatchetKeyPair.publicKey,
    prevSendCount: state.prevSendCount,
    index: state.sendCount,
  };

  state.sendCount++;

  return {
    header,
    ciphertext,
    iv,
  };
}

/**
 * Decrypts a message and advances the receiving chain.
 */
export async function ratchetDecrypt(
  state: RatchetState,
  ciphertext: Uint8Array,
  iv: Uint8Array,
  header: { ratchetPub: Uint8Array; prevSendCount: number; index: number }
): Promise<string> {
  // 1. Check if message key was skipped and stored
  const keyTag = `${toHex(header.ratchetPub)}:${header.index}`;
  if (state.skippedMessageKeys[keyTag]) {
    const mk = state.skippedMessageKeys[keyTag];
    delete state.skippedMessageKeys[keyTag];
    return decrypt(ciphertext, mk, iv);
  }

  // 2. DH Ratchet if remote public key changed
  if (!state.remoteRatchetPub || !compareUint8Arrays(header.ratchetPub, state.remoteRatchetPub)) {
    skipMessageKeys(state, header.prevSendCount);
    dhRatchet(state, header.ratchetPub);
  }

  // 3. Skip message keys if index is ahead
  skipMessageKeys(state, header.index);

  // 4. Advance receiving chain
  if (!state.recvChainKey) throw new Error('No receiving chain');
  const { chainKey: newChain, messageKey } = kdfChain(state.recvChainKey);
  state.recvChainKey = newChain;
  state.recvCount++;

  return decrypt(ciphertext, messageKey, iv);
}

function dhRatchet(state: RatchetState, remotePub: Uint8Array) {
  state.prevSendCount = state.sendCount;
  state.sendCount = 0;
  state.recvCount = 0;
  state.remoteRatchetPub = remotePub;

  // Advance root key with new DH secret
  const { rootKey: r1, chainKey: c1 } = kdfRoot(state.rootKey, sharedSecret(state.localRatchetKeyPair.privateKey, remotePub));
  state.rootKey = r1;
  state.recvChainKey = c1;

  // Generate new local ratchet key pair
  state.localRatchetKeyPair = generateKeyPair();

  // Advance root key again for sending chain
  const { rootKey: r2, chainKey: c2 } = kdfRoot(state.rootKey, sharedSecret(state.localRatchetKeyPair.privateKey, remotePub));
  state.rootKey = r2;
  state.sendChainKey = c2;
}

function skipMessageKeys(state: RatchetState, untilIndex: number) {
  if (state.recvCount + MAX_SKIP < untilIndex) {
    throw new Error('Too many skipped messages');
  }
  if (state.recvChainKey) {
    while (state.recvCount < untilIndex) {
      const { chainKey: newChain, messageKey } = kdfChain(state.recvChainKey);
      state.recvChainKey = newChain;
      const keyTag = `${toHex(state.remoteRatchetPub!)}:${state.recvCount}`;
      state.skippedMessageKeys[keyTag] = messageKey;
      state.recvCount++;
    }
  }
}

function compareUint8Arrays(a: Uint8Array, b: Uint8Array): boolean {
  if (a.length !== b.length) return false;
  for (let i = 0; i < a.length; i++) {
    if (a[i] !== b[i]) return false;
  }
  return true;
}

// ─── Internal KDFs ─────────────────────────────────────────────────────────────

function kdfRoot(rootKey: Uint8Array, dhSecret: Uint8Array) {
  const output = deriveKey(dhSecret, rootKey, 'WhisperRatchet', 64);
  return {
    rootKey: output.slice(0, 32),
    chainKey: output.slice(32),
  };
}

function kdfChain(chainKey: Uint8Array) {
  const output = deriveKey(new Uint8Array([0x01]), chainKey, 'WhisperMessageKeys', 32);
  const nextChainKey = deriveKey(new Uint8Array([0x02]), chainKey, 'WhisperMessageKeys', 32);
  return {
    chainKey: nextChainKey,
    messageKey: output,
  };
}
