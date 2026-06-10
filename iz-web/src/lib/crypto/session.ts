import { api } from '@/lib/api';
import { calculateInitiatorSecret, calculateReceiverSecret, PreKeyBundle } from './x3dh';
import { initRatchet, ratchetEncrypt, ratchetDecrypt, RatchetState } from './ratchet';
import { fromBase64, toBase64, generateKeyPair } from './x25519';

const SESSIONS_KEY = 'iz_sessions';

export interface Session {
  state: RatchetState;
  remoteUserID: string;
}

/**
 * Loads all sessions from local storage.
 */
export function loadSessions(): Record<string, Session> {
  if (typeof window === 'undefined') return {};
  const raw = localStorage.getItem(SESSIONS_KEY);
  if (!raw) return {};
  try {
    // Note: In a real app, you'd need to deserialize Uint8Arrays from Base64
    return JSON.parse(raw);
  } catch {
    return {};
  }
}

/**
 * Saves all sessions to local storage.
 */
export function saveSessions(sessions: Record<string, Session>) {
  if (typeof window === 'undefined') return;
  localStorage.setItem(SESSIONS_KEY, JSON.stringify(sessions));
}

/**
 * Establishes a new E2EE session with a remote user (Initiator side).
 */
export async function establishSession(remoteUserID: string, localIdentityRaw: any): Promise<Session> {
  const localIdentity = {
    publicKey: fromBase64(localIdentityRaw.publicKey),
    privateKey: fromBase64(localIdentityRaw.privateKey),
  };

  // 1. Fetch remote user's bundle
  const bundleRaw = await api.auth.getUserBundle(remoteUserID);
  
  const bobBundle: PreKeyBundle = {
    identityKey: fromBase64(bundleRaw.identity_key),
    signedPreKey: fromBase64(bundleRaw.signed_prekey),
    signedPreKeySig: fromBase64(bundleRaw.signed_prekey_sig),
    oneTimePreKey: bundleRaw.one_time_prekey ? fromBase64(bundleRaw.one_time_prekey.public_key) : undefined,
  };

  // 2. Generate ephemeral key pair for Alice
  const aliceEphemeral = generateKeyPair();

  // 3. Calculate initial root key
  const rootKey = calculateInitiatorSecret(localIdentity, aliceEphemeral, bobBundle);

  // 4. Initialize Ratchet
  const state = initRatchet(rootKey, bobBundle.signedPreKey, true);

  const session: Session = {
    state,
    remoteUserID,
  };

  // 5. Store session
  const sessions = loadSessions();
  sessions[remoteUserID] = session;
  saveSessions(sessions);

  return session;
}

/**
 * Encrypts a message for a specific session.
 */
export async function sendEncrypted(remoteUserID: string, plaintext: string) {
  const sessions = loadSessions();
  const session = sessions[remoteUserID];
  if (!session) throw new Error('No session established');

  const { header, ciphertext, iv } = await ratchetEncrypt(session.state, plaintext);
  
  // Save updated state
  saveSessions(sessions);

  return {
    ciphertext: toBase64(ciphertext),
    iv: toBase64(iv),
    ratchet_key: toBase64(header.ratchetPub),
    counter: header.index,
    prev_counter: header.prevSendCount,
  };
}

/**
 * Decrypts a message from a specific session.
 */
export async function receiveDecrypted(remoteUserID: string, payload: any): Promise<string> {
  const sessions = loadSessions();
  let session = sessions[remoteUserID];
  
  // If no session, this might be the initial message (Alice to Bob)
  if (!session) {
    // In a real app, Bob would use Alice's bundle from the message header
    // For this demo, we'll assume a session must exist or be handled by X3DH
    throw new Error('Session not found for decryption');
  }

  const plaintext = await ratchetDecrypt(
    session.state,
    fromBase64(payload.ciphertext),
    fromBase64(payload.iv),
    {
      ratchetPub: fromBase64(payload.ratchet_key),
      index: payload.counter,
      prevSendCount: payload.prev_counter,
    }
  );

  saveSessions(sessions);
  return plaintext;
}
