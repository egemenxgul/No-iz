// Package signal — Sender Keys Protocol (simplified Signal-compatible)
//
// Sender Keys allow efficient group messaging:
//  - The sender generates one key and encrypts the message ONCE.
//  - Recipients decrypt using the sender's public Sender Key (distributed out-of-band).
//  - The chain ratchets forward on every message (iteration counter).
//
// Server stores encrypted group messages (ciphertext) and is always blind to plaintext.

package signal

import (
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"fmt"
)

// SenderKeyState holds the Sender Key ratchet state for one (group, sender) pair.
type SenderKeyState struct {
	// SigningKey is the ECDSA key used to authenticate sender key messages.
	SigningKey     *ecdsa.PrivateKey
	SigningKeyPub  *ecdsa.PublicKey

	// ChainKey is the current ratchet chain key.
	ChainKey  []byte
	Iteration uint32
}

// SenderKeyDistribution is the record a sender shares with each group member
// so they can decrypt future messages. It is distributed encrypted (using X3DH/DH)
// to each individual member.
type SenderKeyDistribution struct {
	SigningKeyPub string `json:"sig_key"` // base64 ECDSA P-256 public key
	ChainKey      string `json:"ck"`      // base64 current chain key
	Iteration     uint32 `json:"it"`
}

// GenerateSenderKey creates a fresh Sender Key state for a new group member.
func GenerateSenderKey() (*SenderKeyState, error) {
	// Signing key (ECDSA P-256)
	privKey, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		return nil, fmt.Errorf("generate sender signing key: %w", err)
	}

	// Initial chain key (random 32 bytes)
	chainKey := make([]byte, 32)
	if _, err := rand.Read(chainKey); err != nil {
		return nil, fmt.Errorf("generate chain key: %w", err)
	}

	return &SenderKeyState{
		SigningKey:    privKey,
		SigningKeyPub: &privKey.PublicKey,
		ChainKey:      chainKey,
		Iteration:     0,
	}, nil
}

// Distribution produces the SenderKeyDistribution record to share with group members.
func (s *SenderKeyState) Distribution() (*SenderKeyDistribution, error) {
	pub := elliptic.Marshal(s.SigningKeyPub.Curve, s.SigningKeyPub.X, s.SigningKeyPub.Y)
	return &SenderKeyDistribution{
		SigningKeyPub: base64.StdEncoding.EncodeToString(pub),
		ChainKey:      base64.StdEncoding.EncodeToString(s.ChainKey),
		Iteration:     s.Iteration,
	}, nil
}

// EncryptGroupMessage encrypts a plaintext for group delivery.
// It advances the ratchet (iteration + 1) and signs the ciphertext.
func (s *SenderKeyState) EncryptGroupMessage(plaintext []byte) (ciphertext []byte, iteration uint32, sig []byte, err error) {
	// Derive message key from current chain key
	nextCK, msgKey := KDFChain(s.ChainKey)
	s.ChainKey = nextCK
	s.Iteration++

	ct, err := Encrypt(msgKey, plaintext, nil)
	if err != nil {
		return nil, 0, nil, fmt.Errorf("encrypt group msg: %w", err)
	}

	// Sign the ciphertext so recipients can verify sender authenticity
	hash := sha256.Sum256(ct)
	r, sigS, err := ecdsa.Sign(rand.Reader, s.SigningKey, hash[:])
	if err != nil {
		return nil, 0, nil, fmt.Errorf("sign group msg: %w", err)
	}
	// Compact DER-like: r || s (32 bytes each for P-256)
	sigBytes := append(r.Bytes(), sigS.Bytes()...)

	return ct, s.Iteration, sigBytes, nil
}

// DecryptGroupMessage decrypts a group message using the stored chain key at the given iteration.
// In a full implementation you would advance a per-sender ratchet; here we derive the message
// key by iterating forward from the current state.
func DecryptGroupMessage(dist *SenderKeyDistribution, ciphertext []byte, iteration uint32) ([]byte, error) {
	ck, err := base64.StdEncoding.DecodeString(dist.ChainKey)
	if err != nil {
		return nil, fmt.Errorf("decode chain key: %w", err)
	}

	// Advance chain key to reach the target iteration
	for i := dist.Iteration; i < iteration; i++ {
		ck, _ = KDFChain(ck)
	}
	// The message key is derived from the iteration-th chain key
	_, msgKey := KDFChain(ck)

	return Decrypt(msgKey, ciphertext, nil)
}

// EncodeSenderKeyDistribution serialises a distribution to JSON.
func EncodeSenderKeyDistribution(d *SenderKeyDistribution) (string, error) {
	b, err := json.Marshal(d)
	if err != nil {
		return "", err
	}
	return string(b), nil
}

// DecodeSenderKeyDistribution deserialises a distribution from JSON.
func DecodeSenderKeyDistribution(s string) (*SenderKeyDistribution, error) {
	var d SenderKeyDistribution
	if err := json.Unmarshal([]byte(s), &d); err != nil {
		return nil, err
	}
	return &d, nil
}
