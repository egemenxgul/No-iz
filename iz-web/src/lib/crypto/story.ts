const STORY_KEYS_KEY = 'iz_story_keys';

/**
 * Loads all story keys from local storage.
 * Maps Story ID to Media Key (Base64 string).
 */
export function loadStoryKeys(): Record<string, string> {
  if (typeof window === 'undefined') return {};
  try {
    const raw = localStorage.getItem(STORY_KEYS_KEY);
    if (!raw) return {};
    return JSON.parse(raw);
  } catch {
    return {};
  }
}

/**
 * Saves a new story key to local storage.
 */
export function saveStoryKey(storyID: string, mediaKey: string): void {
  if (typeof window === 'undefined') return;
  const keys = loadStoryKeys();
  keys[storyID] = mediaKey;
  localStorage.setItem(STORY_KEYS_KEY, JSON.stringify(keys));
}

/**
 * Retrieves a story key for decryption.
 */
export function getStoryKey(storyID: string): string | null {
  const keys = loadStoryKeys();
  return keys[storyID] || null;
}

/**
 * Encrypts a caption using the media key.
 */
export async function encryptStoryCaption(caption: string, base64Key: string): Promise<string> {
  const binaryKey = atob(base64Key);
  const keyBytes = new Uint8Array(binaryKey.length);
  for (let i = 0; i < binaryKey.length; i++) {
    keyBytes[i] = binaryKey.charCodeAt(i);
  }

  const cryptoKey = await window.crypto.subtle.importKey(
    'raw',
    keyBytes,
    'AES-GCM',
    false,
    ['encrypt']
  );

  const iv = window.crypto.getRandomValues(new Uint8Array(12));
  const encodedText = new TextEncoder().encode(caption);

  const encryptedBuf = await window.crypto.subtle.encrypt(
    { name: 'AES-GCM', iv },
    cryptoKey,
    encodedText
  );

  const payload = new Uint8Array(12 + encryptedBuf.byteLength);
  payload.set(iv, 0);
  payload.set(new Uint8Array(encryptedBuf), 12);

  let binary = '';
  for (let i = 0; i < payload.byteLength; i++) {
    binary += String.fromCharCode(payload[i]);
  }
  return btoa(binary);
}

/**
 * Decrypts a caption using the media key.
 */
export async function decryptStoryCaption(encryptedCaptionBase64: string, base64Key: string): Promise<string> {
  try {
    const binaryKey = atob(base64Key);
    const keyBytes = new Uint8Array(binaryKey.length);
    for (let i = 0; i < binaryKey.length; i++) {
      keyBytes[i] = binaryKey.charCodeAt(i);
    }

    const cryptoKey = await window.crypto.subtle.importKey(
      'raw',
      keyBytes,
      'AES-GCM',
      false,
      ['decrypt']
    );

    const binaryPayload = atob(encryptedCaptionBase64);
    const payloadBytes = new Uint8Array(binaryPayload.length);
    for (let i = 0; i < binaryPayload.length; i++) {
      payloadBytes[i] = binaryPayload.charCodeAt(i);
    }

    if (payloadBytes.length < 12) return '';

    const iv = payloadBytes.slice(0, 12);
    const ciphertext = payloadBytes.slice(12);

    const decryptedBuf = await window.crypto.subtle.decrypt(
      { name: 'AES-GCM', iv },
      cryptoKey,
      ciphertext
    );

    return new TextDecoder().decode(decryptedBuf);
  } catch (e) {
    console.error('Failed to decrypt caption', e);
    return '*(Şifrelenmiş Metin)*';
  }
}
