import { generateKeyPair, sharedSecret, KeyPair } from './x25519';
import { deriveKey } from './hkdf';

export interface PreKeyBundle {
  identityKey: Uint8Array;
  signedPreKey: Uint8Array;
  signedPreKeySig: Uint8Array;
  oneTimePreKey?: Uint8Array;
}

/**
 * Initiator (Alice) calculates the initial shared secret for X3DH.
 * DH1 = SharedSecret(Alice_IdentityPriv, Bob_SignedPreKeyPub)
 * DH2 = SharedSecret(Alice_EphemeralPriv, Bob_IdentityKeyPub)
 * DH3 = SharedSecret(Alice_EphemeralPriv, Bob_SignedPreKeyPub)
 * DH4 = SharedSecret(Alice_EphemeralPriv, Bob_OneTimePreKeyPub) (optional)
 */
export function calculateInitiatorSecret(
  aliceIdentity: KeyPair,
  aliceEphemeral: KeyPair,
  bobBundle: PreKeyBundle
): Uint8Array {
  const dh1 = sharedSecret(aliceIdentity.privateKey, bobBundle.signedPreKey);
  const dh2 = sharedSecret(aliceEphemeral.privateKey, bobBundle.identityKey);
  const dh3 = sharedSecret(aliceEphemeral.privateKey, bobBundle.signedPreKey);

  let secret = new Uint8Array(dh1.length + dh2.length + dh3.length);
  secret.set(dh1);
  secret.set(dh2, dh1.length);
  secret.set(dh3, dh1.length + dh2.length);

  if (bobBundle.oneTimePreKey) {
    const dh4 = sharedSecret(aliceEphemeral.privateKey, bobBundle.oneTimePreKey);
    const newSecret = new Uint8Array(secret.length + dh4.length);
    newSecret.set(secret);
    newSecret.set(dh4, secret.length);
    secret = newSecret;
  }

  // Derive root key using HKDF
  return deriveKey(secret, undefined, 'WhisperText', 32);
}

/**
 * Receiver (Bob) calculates the initial shared secret for X3DH.
 */
export function calculateReceiverSecret(
  bobIdentity: KeyPair,
  bobSignedPreKey: KeyPair,
  bobOneTimePreKey: KeyPair | undefined,
  aliceIdentityPub: Uint8Array,
  aliceEphemeralPub: Uint8Array
): Uint8Array {
  const dh1 = sharedSecret(bobSignedPreKey.privateKey, aliceIdentityPub);
  const dh2 = sharedSecret(bobIdentity.privateKey, aliceEphemeralPub);
  const dh3 = sharedSecret(bobSignedPreKey.privateKey, aliceEphemeralPub);

  let secret = new Uint8Array(dh1.length + dh2.length + dh3.length);
  secret.set(dh1);
  secret.set(dh2, dh1.length);
  secret.set(dh3, dh1.length + dh2.length);

  if (bobOneTimePreKey) {
    const dh4 = sharedSecret(bobOneTimePreKey.privateKey, aliceEphemeralPub);
    const newSecret = new Uint8Array(secret.length + dh4.length);
    newSecret.set(secret);
    newSecret.set(dh4, secret.length);
    secret = newSecret;
  }

  return deriveKey(secret, undefined, 'WhisperText', 32);
}
