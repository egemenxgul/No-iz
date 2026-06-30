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

/**
 * Encrypts a Blob/File and uploads it to the backend.
 * 
 * @param file       The File or Blob to upload
 * @param filename   Optional filename
 * @returns An object containing mediaUrl, base64Key, and mimeType
 */
export async function encryptAndUploadMedia(
  file: Blob,
  filename: string = 'media.webm'
): Promise<{ mediaUrl: string; base64Key: string; mimeType: string }> {
  const token = getToken();
  if (!token) throw new Error('No auth token');

  const fileBuffer = await file.arrayBuffer();

  // 1. Generate AES-GCM Key (32 bytes)
  const cryptoKey = await window.crypto.subtle.generateKey(
    { name: 'AES-GCM', length: 256 },
    true,
    ['encrypt', 'decrypt']
  );

  // 2. Generate IV (12 bytes)
  const iv = window.crypto.getRandomValues(new Uint8Array(12));

  // 3. Encrypt
  const encryptedBuf = await window.crypto.subtle.encrypt(
    { name: 'AES-GCM', iv },
    cryptoKey,
    fileBuffer
  );

  // 4. Combine IV and Ciphertext
  const payload = new Uint8Array(iv.length + encryptedBuf.byteLength);
  payload.set(iv, 0);
  payload.set(new Uint8Array(encryptedBuf), iv.length);

  // 5. Upload to /api/media/upload
  const formData = new FormData();
  const encryptedBlob = new Blob([payload], { type: 'application/octet-stream' });
  formData.append('file', encryptedBlob, filename);

  const res = await fetch('/api/media/upload', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${token}`
    },
    body: formData
  });

  if (!res.ok) {
    throw new Error(`Upload failed: ${res.status}`);
  }

  const data = await res.json();
  const mediaUrl = data.url;

  // 6. Export Key as Base64
  const rawKey = await window.crypto.subtle.exportKey('raw', cryptoKey);
  const keyBytes = new Uint8Array(rawKey);
  let binaryString = '';
  for (let i = 0; i < keyBytes.byteLength; i++) {
    binaryString += String.fromCharCode(keyBytes[i]);
  }
  const base64Key = btoa(binaryString);

  return {
    mediaUrl,
    base64Key,
    mimeType: file.type || 'application/octet-stream'
  };
}
