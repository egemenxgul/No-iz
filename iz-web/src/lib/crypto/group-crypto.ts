import { fromBase64, toBase64 } from './x25519';

// Gruptaki her sohbet için Sender Key (AES-GCM) oluşturulması ve yönetimi
const GROUP_KEYS_STORAGE = 'iz_group_keys';

interface GroupKeyStore {
  // groupId -> senderId -> CryptoKey stringified (or raw bytes in base64)
  [groupId: string]: {
    [senderId: string]: string; // base64 encoded raw key
  };
}

export function loadGroupKeys(): GroupKeyStore {
  if (typeof window === 'undefined') return {};
  const raw = localStorage.getItem(GROUP_KEYS_STORAGE);
  if (!raw) return {};
  try {
    return JSON.parse(raw);
  } catch {
    return {};
  }
}

export function saveGroupKeys(store: GroupKeyStore) {
  if (typeof window === 'undefined') return;
  localStorage.setItem(GROUP_KEYS_STORAGE, JSON.stringify(store));
}

// Generate a new 256-bit AES-GCM key for a group
export async function generateGroupKey(): Promise<CryptoKey> {
  return await crypto.subtle.generateKey(
    { name: 'AES-GCM', length: 256 },
    true,
    ['encrypt', 'decrypt']
  );
}

// Export CryptoKey to Base64
export async function exportKeyToBase64(key: CryptoKey): Promise<string> {
  const exported = await crypto.subtle.exportKey('raw', key);
  return toBase64(new Uint8Array(exported));
}

// Import CryptoKey from Base64
export async function importKeyFromBase64(base64Str: string): Promise<CryptoKey> {
  const raw = fromBase64(base64Str);
  return await crypto.subtle.importKey(
    'raw',
    raw.buffer as ArrayBuffer,
    { name: 'AES-GCM' },
    true,
    ['encrypt', 'decrypt']
  );
}

// Get or Create our own Sender Key for a group
export async function getOrCreateMySenderKey(groupId: string, myUserId: string): Promise<CryptoKey> {
  const store = loadGroupKeys();
  if (!store[groupId]) store[groupId] = {};

  if (store[groupId][myUserId]) {
    return await importKeyFromBase64(store[groupId][myUserId]);
  }

  const newKey = await generateGroupKey();
  store[groupId][myUserId] = await exportKeyToBase64(newKey);
  saveGroupKeys(store);
  return newKey;
}

export async function encryptGroupMessage(groupId: string, myUserId: string, plaintext: string) {
  const key = await getOrCreateMySenderKey(groupId, myUserId);
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const encodedText = new TextEncoder().encode(plaintext);

  const ciphertextBuffer = await crypto.subtle.encrypt(
    { name: 'AES-GCM', iv },
    key,
    encodedText
  );

  return {
    ciphertext: toBase64(new Uint8Array(ciphertextBuffer)),
    iv: toBase64(iv),
  };
}

export async function decryptGroupMessage(groupId: string, senderId: string, ciphertextB64: string, ivB64: string): Promise<string> {
  const store = loadGroupKeys();
  const base64Key = store[groupId]?.[senderId];
  if (!base64Key) throw new Error('Sender key not found for this user in the group');

  const key = await importKeyFromBase64(base64Key);
  const iv = fromBase64(ivB64);
  const ciphertext = fromBase64(ciphertextB64);

  const decryptedBuffer = await crypto.subtle.decrypt(
    { name: 'AES-GCM', iv: iv.buffer as ArrayBuffer },
    key,
    ciphertext.buffer as ArrayBuffer
  );

  return new TextDecoder().decode(decryptedBuffer);
}
