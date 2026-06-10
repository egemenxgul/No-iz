// Package signal implements the cryptographic primitives used in the iz messaging system.
// It provides X25519 Diffie-Hellman, HKDF key derivation, and AES-256-GCM encryption
// as building blocks for X3DH and Double Ratchet.
package signal

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/ecdh"
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"errors"
	"io"

	"golang.org/x/crypto/hkdf"
)

// GenerateKeyPair generates a new X25519 key pair.
func GenerateKeyPair() (*ecdh.PrivateKey, *ecdh.PublicKey, error) {
	priv, err := ecdh.X25519().GenerateKey(rand.Reader)
	if err != nil {
		return nil, nil, err
	}
	return priv, priv.PublicKey(), nil
}

// DH performs a single X25519 Diffie-Hellman exchange.
func DH(priv *ecdh.PrivateKey, pub *ecdh.PublicKey) ([]byte, error) {
	return priv.ECDH(pub)
}

// HKDF derives two 32-byte keys (rootKey, chainKey) from input keying material.
func HKDF(ikm []byte, info string) (rootKey, chainKey []byte, err error) {
	h := hkdf.New(sha256.New, ikm, make([]byte, 32), []byte(info))
	rootKey = make([]byte, 32)
	chainKey = make([]byte, 32)
	if _, err = io.ReadFull(h, rootKey); err != nil {
		return nil, nil, err
	}
	_, err = io.ReadFull(h, chainKey)
	return rootKey, chainKey, err
}

// KDFChain advances a chain key, returning (nextChainKey, messageKey).
func KDFChain(chainKey []byte) (nextChainKey, msgKey []byte) {
	mac := hmac.New(sha256.New, chainKey)
	mac.Write([]byte{0x02})
	nextChainKey = mac.Sum(nil)

	mac.Reset()
	mac.Write([]byte{0x01})
	msgKey = mac.Sum(nil)
	return nextChainKey, msgKey
}

// Encrypt encrypts plaintext with AES-256-GCM. The nonce is prepended to the ciphertext.
func Encrypt(key, plaintext, aad []byte) ([]byte, error) {
	block, err := aes.NewCipher(key)
	if err != nil {
		return nil, err
	}
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return nil, err
	}
	nonce := make([]byte, gcm.NonceSize())
	if _, err = rand.Read(nonce); err != nil {
		return nil, err
	}
	return gcm.Seal(nonce, nonce, plaintext, aad), nil
}

// Decrypt decrypts an AES-256-GCM ciphertext (nonce prepended).
func Decrypt(key, ciphertext, aad []byte) ([]byte, error) {
	block, err := aes.NewCipher(key)
	if err != nil {
		return nil, err
	}
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return nil, err
	}
	ns := gcm.NonceSize()
	if len(ciphertext) < ns {
		return nil, errors.New("ciphertext too short")
	}
	return gcm.Open(nil, ciphertext[:ns], ciphertext[ns:], aad)
}

// EncodePublicKey encodes an X25519 public key to standard base64.
func EncodePublicKey(pub *ecdh.PublicKey) string {
	return base64.StdEncoding.EncodeToString(pub.Bytes())
}

// DecodePublicKey decodes a standard base64 X25519 public key.
func DecodePublicKey(encoded string) (*ecdh.PublicKey, error) {
	b, err := base64.StdEncoding.DecodeString(encoded)
	if err != nil {
		return nil, err
	}
	return ecdh.X25519().NewPublicKey(b)
}

// EncodePrivateKey encodes an X25519 private key to standard base64.
func EncodePrivateKey(priv *ecdh.PrivateKey) string {
	return base64.StdEncoding.EncodeToString(priv.Bytes())
}

// DecodePrivateKey decodes a standard base64 X25519 private key.
func DecodePrivateKey(encoded string) (*ecdh.PrivateKey, error) {
	b, err := base64.StdEncoding.DecodeString(encoded)
	if err != nil {
		return nil, err
	}
	return ecdh.X25519().NewPrivateKey(b)
}
