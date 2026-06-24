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
    key as unknown as BufferSource,
    ALGO,
    false,
    ['encrypt']
  );

  const iv = window.crypto.getRandomValues(new Uint8Array(12));
  const encoded = new TextEncoder().encode(plaintext);

  const encrypted = await window.crypto.subtle.encrypt(
    { name: ALGO, iv } as unknown as AesGcmParams,
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
    key as unknown as BufferSource,
    ALGO,
    false,
    ['decrypt']
  );

  const decrypted = await window.crypto.subtle.decrypt(
    { name: ALGO, iv } as unknown as AesGcmParams,
    cryptoKey,
    ciphertext as unknown as BufferSource
  );

  return new TextDecoder().decode(decrypted);
}

/**
 * Decrypts a QR login payload using X25519 ECDH + HKDF-SHA256 + AES-256-GCM.
 *
 * Mobile payload format (base64):
 *   [32B mobilePub][12B nonce][N bytes ciphertext][16B GCM mac]
 *
 * Steps:
 *   1. Decode base64 blob and split into parts.
 *   2. Compute shared secret: X25519(webPriv, mobilePub).
 *   3. Derive AES key via HKDF-SHA256 with salt=mobilePub, info='iz-qr-login-v1'.
 *   4. AES-256-GCM decrypt with nonce and combined ct+mac.
 *
 * @param encryptedPayloadBase64 - base64-encoded blob from backend poll response
 * @param webPrivateKeyBase64    - base64-encoded web ephemeral private key (from localStorage)
 * @returns Decrypted JSON string
 */
export async function decryptQrPayload(
  encryptedPayloadBase64: string,
  webPrivateKeyBase64: string
): Promise<string> {
  // Helper: base64 → Uint8Array
  const fromBase64 = (b64: string): Uint8Array => {
    const binary = atob(b64);
    const arr = new Uint8Array(binary.length);
    for (let i = 0; i < binary.length; i++) arr[i] = binary.charCodeAt(i);
    return arr;
  };

  const blob = fromBase64(encryptedPayloadBase64);
  if (blob.length < 32 + 12 + 16) throw new Error('Invalid encrypted payload length');

  // 1. Split blob
  const mobilePub  = blob.slice(0, 32);   // X25519 ephemeral public key
  const nonce      = blob.slice(32, 44);  // 12-byte IV
  const ctWithMac  = blob.slice(44);      // ciphertext + 16-byte GCM tag

  const webPrivBytes = fromBase64(webPrivateKeyBase64);

  // 2. Import web private key as ECDH CryptoKey
  const webPrivCrypto = await window.crypto.subtle.importKey(
    'raw',
    webPrivBytes as unknown as BufferSource,
    { name: 'X25519' },
    false,
    ['deriveBits']
  );

  // 3. Import mobile public key as ECDH CryptoKey
  const mobilePubCrypto = await window.crypto.subtle.importKey(
    'raw',
    mobilePub as unknown as BufferSource,
    { name: 'X25519' },
    false,
    []
  );

  // 4. X25519 shared secret (32 bytes)
  const sharedBits = await window.crypto.subtle.deriveBits(
    { name: 'X25519', public: mobilePubCrypto },
    webPrivCrypto,
    256
  );

  // 5. HKDF-SHA256: salt=mobilePub, info='iz-qr-login-v1'
  const sharedKey = await window.crypto.subtle.importKey(
    'raw',
    sharedBits,
    { name: 'HKDF' },
    false,
    ['deriveKey']
  );

  const aesKey = await window.crypto.subtle.deriveKey(
    {
      name: 'HKDF',
      hash: 'SHA-256',
      salt: mobilePub as unknown as BufferSource,
      info: new TextEncoder().encode('iz-qr-login-v1'),
    },
    sharedKey,
    { name: 'AES-GCM', length: 256 },
    false,
    ['decrypt']
  );

  // 6. AES-256-GCM decrypt
  const decrypted = await window.crypto.subtle.decrypt(
    { name: 'AES-GCM', iv: nonce as unknown as BufferSource },
    aesKey,
    ctWithMac as unknown as BufferSource
  );

  return new TextDecoder().decode(decrypted);
}
