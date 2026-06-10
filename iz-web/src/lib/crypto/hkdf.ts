import { hkdf } from '@noble/hashes/hkdf.js';
import { sha256 } from '@noble/hashes/sha2.js';

/**
 * Derives a key of specific length using HKDF-SHA256.
 * @param secret The input keying material (shared secret).
 * @param salt Optional salt.
 * @param info Optional context information.
 * @param length Desired output length in bytes.
 */
export function deriveKey(secret: Uint8Array, salt: Uint8Array | undefined, info: string, length: number): Uint8Array {
  const infoBytes = new TextEncoder().encode(info);
  return hkdf(sha256, secret, salt, infoBytes, length);
}

/**
 * Simple SHA-256 hash.
 */
export function hash(data: Uint8Array): Uint8Array {
  return sha256(data);
}
