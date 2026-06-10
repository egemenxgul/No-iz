import { x25519, ed25519 } from '@noble/curves/ed25519.js';

export interface KeyPair {
  publicKey: Uint8Array;
  privateKey: Uint8Array;
}

/**
 * Generates a new X25519 key pair for DH.
 */
export function generateKeyPair(): KeyPair {
  const privateKey = x25519.utils.randomSecretKey();
  const publicKey = x25519.getPublicKey(privateKey);
  return { publicKey, privateKey };
}

/**
 * Generates a new Ed25519 key pair for Signing.
 */
export function generateSigningKeyPair(): KeyPair {
  // Use manual random generation for robustness across versions
  const privateKey = window.crypto.getRandomValues(new Uint8Array(32));
  const publicKey = ed25519.getPublicKey(privateKey);
  return { publicKey, privateKey };
}

/**
 * Signs data using Ed25519 private key.
 */
export function sign(privateKey: Uint8Array, message: Uint8Array): Uint8Array {
  return ed25519.sign(message, privateKey);
}

/**
 * Computes the shared secret using Diffie-Hellman (X25519).
 */
export function sharedSecret(privateKey: Uint8Array, publicKey: Uint8Array): Uint8Array {
  return x25519.getSharedSecret(privateKey, publicKey);
}

/**
 * Helpers to convert between hex and Uint8Array.
 */
export function toHex(arr: Uint8Array): string {
  return Array.from(arr)
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

export function fromHex(hex: string): Uint8Array {
  const matches = hex.match(/.{1,2}/g);
  return new Uint8Array(matches ? matches.map((byte) => parseInt(byte, 16)) : []);
}

export function toBase64(arr: Uint8Array): string {
  return btoa(String.fromCharCode.apply(null, Array.from(arr)));
}

export function fromBase64(b64: string): Uint8Array {
  const binary = atob(b64);
  const arr = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    arr[i] = binary.charCodeAt(i);
  }
  return arr;
}
