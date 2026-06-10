/**
 * AES-256-GCM encryption and decryption using Web Crypto API.
 */

const ALGO = 'AES-GCM';

/**
 * Encrypts plaintext using AES-GCM.
 * Returns [ciphertext, iv].
 */
export async function encrypt(plaintext: string, key: Uint8Array): Promise<{ ciphertext: Uint8Array; iv: Uint8Array }> {
  const cryptoKey = await window.crypto.subtle.importKey(
    'raw',
    key as any,
    ALGO,
    false,
    ['encrypt']
  );

  const iv = window.crypto.getRandomValues(new Uint8Array(12));
  const encoded = new TextEncoder().encode(plaintext);

  const encrypted = await window.crypto.subtle.encrypt(
    { name: ALGO, iv } as any,
    cryptoKey,
    encoded
  );

  return {
    ciphertext: new Uint8Array(encrypted),
    iv,
  };
}

/**
 * Decrypts ciphertext using AES-GCM.
 */
export async function decrypt(ciphertext: Uint8Array, key: Uint8Array, iv: Uint8Array): Promise<string> {
  const cryptoKey = await window.crypto.subtle.importKey(
    'raw',
    key as any,
    ALGO,
    false,
    ['decrypt']
  );

  const decrypted = await window.crypto.subtle.decrypt(
    { name: ALGO, iv } as any,
    cryptoKey,
    ciphertext as any
  );

  return new TextDecoder().decode(decrypted);
}
