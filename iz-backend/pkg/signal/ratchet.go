package signal

import (
	"crypto/ecdh"
	"encoding/json"
	"errors"
	"fmt"
	"sync"
)

const (
	maxSkip      = 1000
	ratchetInfo  = "iz_ratchet_v1"
)

// RatchetHeader is included in every encrypted message so the recipient
// can advance their ratchet state.
type RatchetHeader struct {
	DHPublicKey string `json:"dh"`  // sender's current ratchet public key (base64)
	PrevCounter int    `json:"pn"`  // previous sending chain length
	Counter     int    `json:"n"`   // current message number
}

// EncryptedMessage is a Double Ratchet encrypted message ready to send over the wire.
type EncryptedMessage struct {
	Header     RatchetHeader `json:"header"`
	Ciphertext []byte        `json:"ciphertext"` // AES-256-GCM; header bytes used as AAD
}

// RatchetState holds the full Double Ratchet session state for one conversation.
// It must be serialised and stored (encrypted) by the client between sessions.
type RatchetState struct {
	mu sync.Mutex

	// Ratchet key pair for the sending direction
	DHSendPriv *ecdh.PrivateKey
	DHRecvPub  *ecdh.PublicKey

	RootKey      []byte
	SendChainKey []byte
	RecvChainKey []byte

	SendCount     int
	RecvCount     int
	PrevSendCount int

	// Skipped message keys: "b64pubkey:counter" -> msgKey
	SkippedKeys map[string][]byte
}

// InitSender initialises a RatchetState for the party that sends the first message (Alice).
// sharedKey comes from X3DH; bobSPKPub is Bob's signed prekey public key.
func InitSender(sharedKey []byte, bobSPKPub *ecdh.PublicKey) (*RatchetState, error) {
	// Generate Alice's initial sending ratchet key pair
	sendPriv, _, err := GenerateKeyPair()
	if err != nil {
		return nil, err
	}

	// Perform one ratchet step to derive the first sending chain
	dh, err := DH(sendPriv, bobSPKPub)
	if err != nil {
		return nil, err
	}
	rootKey, sendCK, err := HKDF(append(sharedKey, dh...), ratchetInfo)
	if err != nil {
		return nil, err
	}

	return &RatchetState{
		DHSendPriv:  sendPriv,
		DHRecvPub:   bobSPKPub,
		RootKey:     rootKey,
		SendChainKey: sendCK,
		SkippedKeys:  make(map[string][]byte),
	}, nil
}

// InitReceiver initialises a RatchetState for the party that receives the first message (Bob).
// sharedKey comes from X3DH; bobSPKPriv is Bob's signed prekey private key.
func InitReceiver(sharedKey []byte, bobSPKPriv *ecdh.PrivateKey, aliceRatchetPub *ecdh.PublicKey) (*RatchetState, error) {
	// Perform one receive ratchet step
	dh, err := DH(bobSPKPriv, aliceRatchetPub)
	if err != nil {
		return nil, err
	}
	rootKey, recvCK, err := HKDF(append(sharedKey, dh...), ratchetInfo)
	if err != nil {
		return nil, err
	}

	// Bob generates his own sending ratchet key pair
	sendPriv, _, err := GenerateKeyPair()
	if err != nil {
		return nil, err
	}
	dh2, err := DH(sendPriv, aliceRatchetPub)
	if err != nil {
		return nil, err
	}
	rootKey2, sendCK, err := HKDF(append(rootKey, dh2...), ratchetInfo)
	if err != nil {
		return nil, err
	}

	return &RatchetState{
		DHSendPriv:  sendPriv,
		DHRecvPub:   aliceRatchetPub,
		RootKey:     rootKey2,
		SendChainKey: sendCK,
		RecvChainKey: recvCK,
		SkippedKeys:  make(map[string][]byte),
	}, nil
}

// RatchetEncrypt encrypts a plaintext message, advancing the sending chain.
func (s *RatchetState) RatchetEncrypt(plaintext []byte) (*EncryptedMessage, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	nextCK, msgKey := KDFChain(s.SendChainKey)
	s.SendChainKey = nextCK

	header := RatchetHeader{
		DHPublicKey: EncodePublicKey(s.DHSendPriv.PublicKey()),
		PrevCounter: s.PrevSendCount,
		Counter:     s.SendCount,
	}
	s.SendCount++

	headerBytes, err := json.Marshal(header)
	if err != nil {
		return nil, err
	}
	ct, err := Encrypt(msgKey, plaintext, headerBytes)
	if err != nil {
		return nil, err
	}
	return &EncryptedMessage{Header: header, Ciphertext: ct}, nil
}

// RatchetDecrypt decrypts an incoming message, performing a DH ratchet step if necessary.
func (s *RatchetState) RatchetDecrypt(msg *EncryptedMessage) ([]byte, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	headerBytes, err := json.Marshal(msg.Header)
	if err != nil {
		return nil, err
	}

	// Check skipped message keys first
	if pt := s.trySkipped(msg.Header, headerBytes, msg.Ciphertext); pt != nil {
		return pt, nil
	}

	dhPub, err := DecodePublicKey(msg.Header.DHPublicKey)
	if err != nil {
		return nil, err
	}

	// Do we need a DH ratchet step?
	currentPub := ""
	if s.DHRecvPub != nil {
		currentPub = EncodePublicKey(s.DHRecvPub)
	}
	if currentPub != msg.Header.DHPublicKey {
		if err := s.skipKeys(msg.Header.PrevCounter); err != nil {
			return nil, err
		}
		if err := s.dhRatchet(dhPub); err != nil {
			return nil, err
		}
	}

	if err := s.skipKeys(msg.Header.Counter); err != nil {
		return nil, err
	}

	nextCK, msgKey := KDFChain(s.RecvChainKey)
	s.RecvChainKey = nextCK
	s.RecvCount++

	return Decrypt(msgKey, msg.Ciphertext, headerBytes)
}

// dhRatchet performs one DH ratchet step (receiving side).
func (s *RatchetState) dhRatchet(newDHPub *ecdh.PublicKey) error {
	s.PrevSendCount = s.SendCount
	s.SendCount = 0
	s.RecvCount = 0
	s.DHRecvPub = newDHPub

	dh, err := DH(s.DHSendPriv, newDHPub)
	if err != nil {
		return err
	}
	rootKey, recvCK, err := HKDF(append(s.RootKey, dh...), ratchetInfo)
	if err != nil {
		return err
	}
	s.RootKey = rootKey
	s.RecvChainKey = recvCK

	// Generate new sending ratchet key pair
	newSendPriv, _, err := GenerateKeyPair()
	if err != nil {
		return err
	}
	s.DHSendPriv = newSendPriv

	dh2, err := DH(newSendPriv, newDHPub)
	if err != nil {
		return err
	}
	rootKey2, sendCK, err := HKDF(append(s.RootKey, dh2...), ratchetInfo)
	if err != nil {
		return err
	}
	s.RootKey = rootKey2
	s.SendChainKey = sendCK
	return nil
}

// skipKeys stores skipped message keys up to the given counter.
func (s *RatchetState) skipKeys(until int) error {
	if s.RecvCount+maxSkip < until {
		return errors.New("too many skipped messages")
	}
	for s.RecvCount < until {
		nextCK, msgKey := KDFChain(s.RecvChainKey)
		s.RecvChainKey = nextCK
		k := fmt.Sprintf("%s:%d", EncodePublicKey(s.DHRecvPub), s.RecvCount)
		s.SkippedKeys[k] = msgKey
		s.RecvCount++
	}
	return nil
}

// trySkipped checks the skipped key map for the message key.
func (s *RatchetState) trySkipped(h RatchetHeader, headerBytes, ct []byte) []byte {
	k := fmt.Sprintf("%s:%d", h.DHPublicKey, h.Counter)
	msgKey, ok := s.SkippedKeys[k]
	if !ok {
		return nil
	}
	delete(s.SkippedKeys, k)
	pt, err := Decrypt(msgKey, ct, headerBytes)
	if err != nil {
		return nil
	}
	return pt
}
