import { generateKeyPair, generateSigningKeyPair, KeyPair, toBase64, sign, fromBase64 } from './x25519';

const KEYS_KEY = 'iz_keys';

export interface UserKeys {
  identityKey: KeyPair;
  signedPreKey: KeyPair;
  oneTimePreKeys: KeyPair[];
}

/**
 * Generates a full Signal protocol key bundle for a new user.
 */
export function generateInitialKeys(): UserKeys {
  // Identity key is for signing
  const identityKey = generateSigningKeyPair();
  // Signed prekey is for DH
  const signedPreKey = generateKeyPair();
  // One-time prekeys are for DH
  const oneTimePreKeys = Array.from({ length: 50 }, () => generateKeyPair());

  return {
    identityKey,
    signedPreKey,
    oneTimePreKeys,
  };
}

/**
 * Encrypts and stores the user's private keys in local storage using their password.
 */
export async function storeLocalKeys(keys: UserKeys, password: string) {
  if (typeof window === 'undefined') return;
  
  const rawData = {
    identityKey: {
      publicKey: toBase64(keys.identityKey.publicKey),
      privateKey: toBase64(keys.identityKey.privateKey),
    },
    signedPreKey: {
      publicKey: toBase64(keys.signedPreKey.publicKey),
      privateKey: toBase64(keys.signedPreKey.privateKey),
    },
    oneTimePreKeys: keys.oneTimePreKeys.map(pk => ({
      publicKey: toBase64(pk.publicKey),
      privateKey: toBase64(pk.privateKey),
    })),
  };

  const jsonStr = JSON.stringify(rawData);
  const encryptedData = await encryptWithPassword(jsonStr, password);

  localStorage.setItem(KEYS_KEY, JSON.stringify(encryptedData));
}

/**
 * Prepares the keys to be sent to the server during registration.
 */
export function prepareRegistrationBundle(keys: UserKeys) {
  // Sign the public part of the signed prekey using the identity private key
  const signature = sign(keys.identityKey.privateKey, keys.signedPreKey.publicKey);

  return {
    identity_key: toBase64(keys.identityKey.publicKey),
    signed_prekey: toBase64(keys.signedPreKey.publicKey),
    signed_prekey_sig: toBase64(signature),
    one_time_prekeys: keys.oneTimePreKeys.map((pk, i) => ({
      key_id: i,
      public_key: toBase64(pk.publicKey),
    })),
  };
}

// ─── Web Crypto Encryption Helpers ───────────────────────────────────────────

async function encryptWithPassword(text: string, password: string) {
  const enc = new TextEncoder();
  const salt = window.crypto.getRandomValues(new Uint8Array(16));
  
  const keyMaterial = await window.crypto.subtle.importKey(
    "raw", enc.encode(password) as any, "PBKDF2", false, ["deriveKey"]
  );
  
  const key = await window.crypto.subtle.deriveKey(
    { name: "PBKDF2", salt: salt as any, iterations: 100000, hash: "SHA-256" },
    keyMaterial,
    { name: "AES-GCM", length: 256 },
    false,
    ["encrypt"]
  );
  
  const iv = window.crypto.getRandomValues(new Uint8Array(12));
  const ciphertext = await window.crypto.subtle.encrypt(
    { name: "AES-GCM", iv: iv as any },
    key,
    enc.encode(text) as any
  );
  
  return {
    ciphertext: toBase64(new Uint8Array(ciphertext)),
    iv: toBase64(iv),
    salt: toBase64(salt)
  };
}

export async function decryptLocalKeys(password: string): Promise<UserKeys | null> {
  const data = localStorage.getItem(KEYS_KEY);
  if (!data) return null;

  try {
    const encrypted = JSON.parse(data);
    const decryptedJson = await decryptWithPassword(encrypted, password);
    const raw = JSON.parse(decryptedJson);

    return {
      identityKey: {
        publicKey: fromBase64(raw.identityKey.publicKey),
        privateKey: fromBase64(raw.identityKey.privateKey),
      },
      signedPreKey: {
        publicKey: fromBase64(raw.signedPreKey.publicKey),
        privateKey: fromBase64(raw.signedPreKey.privateKey),
      },
      oneTimePreKeys: raw.oneTimePreKeys.map((pk: any) => ({
        publicKey: fromBase64(pk.publicKey),
        privateKey: fromBase64(pk.privateKey),
      })),
    };
  } catch (err) {
    console.error('Failed to decrypt keys:', err);
    return null;
  }
}

async function decryptWithPassword(data: { ciphertext: string; iv: string; salt: string }, password: string) {
  const enc = new TextEncoder();
  const dec = new TextDecoder();
  
  const keyMaterial = await window.crypto.subtle.importKey(
    "raw", enc.encode(password), "PBKDF2", false, ["deriveKey"]
  );
  
  const key = await window.crypto.subtle.deriveKey(
    { name: "PBKDF2", salt: fromBase64(data.salt) as any, iterations: 100000, hash: "SHA-256" },
    keyMaterial,
    { name: "AES-GCM", length: 256 },
    false,
    ["decrypt"]
  );
  
  const decrypted = await window.crypto.subtle.decrypt(
    { name: "AES-GCM", iv: fromBase64(data.iv) as any },
    key,
    fromBase64(data.ciphertext) as any
  );
  
  return dec.decode(decrypted);
}
