import { api } from '@/lib/api';

const SESSIONS_KEY = 'iz_sessions';
const KEYS_KEY = 'iz_keys';

// Helpers to convert ArrayBuffer <-> Base64
function bufferToBase64(buffer: ArrayBuffer): string {
  let binary = '';
  const bytes = new Uint8Array(buffer);
  for (let i = 0; i < bytes.byteLength; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary);
}

function base64ToBuffer(base64: string): ArrayBuffer {
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes.buffer;
}

// NIST SP 800-63B recommends >=310,000 for PBKDF2-SHA-256; 600,000 is the OWASP 2024 baseline.
const ITERATIONS = 600_000;

async function deriveKey(password: string, salt: Uint8Array): Promise<CryptoKey> {
  const enc = new TextEncoder();
  const keyMaterial = await window.crypto.subtle.importKey(
    'raw',
    enc.encode(password),
    { name: 'PBKDF2' },
    false,
    ['deriveKey']
  );

  return window.crypto.subtle.deriveKey(
    {
      name: 'PBKDF2',
      salt: salt.buffer as ArrayBuffer,
      iterations: ITERATIONS,
      hash: 'SHA-256',
    },
    keyMaterial,
    { name: 'AES-GCM', length: 256 },
    false,
    ['encrypt', 'decrypt']
  );
}

export async function exportAndUploadBackup(password: string): Promise<void> {
  // 1. Gather local data
  const sessions = localStorage.getItem(SESSIONS_KEY) || '{}';
  const keys = localStorage.getItem(KEYS_KEY) || 'null';

  const payload = JSON.stringify({
    iz_sessions: JSON.parse(sessions),
    iz_keys: JSON.parse(keys),
  });

  const payloadBytes = new TextEncoder().encode(payload);

  // 2. Generate Salt & Derive Key
  const salt = window.crypto.getRandomValues(new Uint8Array(16));
  const key = await deriveKey(password, salt);

  // 3. Encrypt AES-GCM
  const iv = window.crypto.getRandomValues(new Uint8Array(12));
  const encryptedBuf = await window.crypto.subtle.encrypt(
    { name: 'AES-GCM', iv },
    key,
    payloadBytes
  );

  // Concatenate: IV (12) + Ciphertext + MAC (16)
  // WebCrypto returns Ciphertext+MAC together.
  const encryptedData = new Uint8Array(encryptedBuf);
  const combined = new Uint8Array(iv.length + encryptedData.length);
  combined.set(iv, 0);
  combined.set(encryptedData, iv.length);

  // 4. Upload
  const encryptedBlob = bufferToBase64(combined.buffer);
  const saltStr = bufferToBase64(salt.buffer);

  await api.backup.save(encryptedBlob, saltStr);
}

export async function exportToFile(password: string): Promise<void> {
  const sessions = localStorage.getItem(SESSIONS_KEY) || '{}';
  const keys = localStorage.getItem(KEYS_KEY) || 'null';

  const payload = JSON.stringify({
    iz_sessions: JSON.parse(sessions),
    iz_keys: JSON.parse(keys),
  });

  const payloadBytes = new TextEncoder().encode(payload);
  const salt = window.crypto.getRandomValues(new Uint8Array(16));
  const key = await deriveKey(password, salt);

  const iv = window.crypto.getRandomValues(new Uint8Array(12));
  const encryptedBuf = await window.crypto.subtle.encrypt(
    { name: 'AES-GCM', iv },
    key,
    payloadBytes
  );

  const encryptedData = new Uint8Array(encryptedBuf);
  const combined = new Uint8Array(iv.length + encryptedData.length);
  combined.set(iv, 0);
  combined.set(encryptedData, iv.length);

  const backupObj = {
    salt: bufferToBase64(salt.buffer),
    encrypted_blob: bufferToBase64(combined.buffer)
  };

  const blob = new Blob([JSON.stringify(backupObj)], { type: 'application/json' });
  const url = URL.createObjectURL(blob);
  
  const a = document.createElement('a');
  a.href = url;
  const date = new Date().toISOString().split('T')[0];
  a.download = `iz_backup_${date}.iz`;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
}

export async function downloadAndRestoreBackup(password: string): Promise<void> {
  // 1. Fetch backup
  const backup = await api.backup.get();
  if (!backup) throw new Error('Yedek bulunamadı.');

  // 2. Parse Base64
  const salt = new Uint8Array(base64ToBuffer(backup.salt));
  const combined = new Uint8Array(base64ToBuffer(backup.encrypted_blob));

  // Extract IV (12 bytes) and ciphertext+MAC
  const iv = combined.slice(0, 12);
  const encryptedData = combined.slice(12);

  // 3. Derive Key & Decrypt
  const key = await deriveKey(password, salt);
  const decryptedBuf = await window.crypto.subtle.decrypt(
    { name: 'AES-GCM', iv },
    key,
    encryptedData
  );

  const payloadStr = new TextDecoder().decode(decryptedBuf);
  const payload = JSON.parse(payloadStr);

  // 4. Restore local data
  if (payload.iz_sessions) {
    localStorage.setItem(SESSIONS_KEY, JSON.stringify(payload.iz_sessions));
  }
  if (payload.iz_keys) {
    localStorage.setItem(KEYS_KEY, JSON.stringify(payload.iz_keys));
  }
}

export async function importFromFile(password: string, file: File): Promise<void> {
  const text = await file.text();
  let backup;
  try {
    backup = JSON.parse(text);
  } catch (e) {
    throw new Error('Geçersiz yedek dosyası formatı.');
  }

  if (!backup.salt || !backup.encrypted_blob) {
    throw new Error('Yedek dosyası bozuk veya eksik.');
  }

  const salt = new Uint8Array(base64ToBuffer(backup.salt));
  const combined = new Uint8Array(base64ToBuffer(backup.encrypted_blob));

  const iv = combined.slice(0, 12);
  const encryptedData = combined.slice(12);

  const key = await deriveKey(password, salt);
  const decryptedBuf = await window.crypto.subtle.decrypt(
    { name: 'AES-GCM', iv },
    key,
    encryptedData
  );

  const payloadStr = new TextDecoder().decode(decryptedBuf);
  const payload = JSON.parse(payloadStr);

  if (payload.iz_sessions) {
    localStorage.setItem(SESSIONS_KEY, JSON.stringify(payload.iz_sessions));
  }
  if (payload.iz_keys) {
    localStorage.setItem(KEYS_KEY, JSON.stringify(payload.iz_keys));
  }
}
