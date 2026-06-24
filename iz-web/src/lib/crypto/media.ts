import { getToken } from '@/store/auth';

/**
 * Fetch and decrypt media from the backend.
 * 
 * @param mediaUrl   The URL to the encrypted media (e.g., /api/media/download/...)
 * @param base64Key  The base64 encoded AES-GCM key used to encrypt the media
 * @param mimeType   The expected mime type of the decrypted file
 * @returns A local object URL pointing to the decrypted media Blob
 */
export async function fetchAndDecryptMedia(
  mediaUrl: string,
  base64Key: string,
  mimeType: string
): Promise<string> {
  const token = getToken();
  if (!token) throw new Error('No auth token');

  // 1. Fetch encrypted blob
  const res = await fetch(mediaUrl, {
    headers: {
      'Authorization': `Bearer ${token}`
    }
  });

  if (!res.ok) {
    throw new Error(`Failed to fetch media: ${res.status}`);
  }

  const encryptedBuf = await res.arrayBuffer();
  const encryptedBytes = new Uint8Array(encryptedBuf);

  // Payload format: [12 bytes IV][ciphertext...]
  if (encryptedBytes.length < 12) {
    throw new Error('Encrypted payload too short');
  }

  const iv = encryptedBytes.slice(0, 12);
  const ciphertext = encryptedBytes.slice(12);

  // 2. Decode base64 key
  const binaryKey = atob(base64Key);
  const keyBytes = new Uint8Array(binaryKey.length);
  for (let i = 0; i < binaryKey.length; i++) {
    keyBytes[i] = binaryKey.charCodeAt(i);
  }

  // 3. Import key and decrypt
  const cryptoKey = await window.crypto.subtle.importKey(
    'raw',
    keyBytes as unknown as BufferSource,
    'AES-GCM',
    false,
    ['decrypt']
  );

  const decryptedBuf = await window.crypto.subtle.decrypt(
    { name: 'AES-GCM', iv } as unknown as AesGcmParams,
    cryptoKey,
    ciphertext as unknown as BufferSource
  );

  // 4. Create object URL
  const blob = new Blob([decryptedBuf], { type: mimeType });
  return URL.createObjectURL(blob);
}
