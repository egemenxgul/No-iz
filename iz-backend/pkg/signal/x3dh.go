package signal

import (
	"crypto/ecdh"
	"crypto/sha256"
	"io"

	"golang.org/x/crypto/hkdf"
)

const x3dhInfo = "iz_x3dh_v1"

// X3DHBundle holds Bob's public key bundle (fetched from the server).
type X3DHBundle struct {
	IdentityKey   *ecdh.PublicKey
	SignedPrekey  *ecdh.PublicKey
	OneTimePrekey *ecdh.PublicKey // optional; nil if unavailable
	OPKIndex      int             // which OPK was used, -1 if none
}

// X3DHSenderResult is returned to Alice after performing X3DH.
type X3DHSenderResult struct {
	SharedKey    []byte
	EphemeralKey *ecdh.PublicKey // Alice must send this to Bob
	UsedOPKIndex int             // -1 if no OPK was used
}

// X3DHSenderInit performs the X3DH key agreement from the sender's (Alice's) perspective.
// Alice needs her identity private key and Bob's public key bundle.
func X3DHSenderInit(aliceIdentityPriv *ecdh.PrivateKey, bob *X3DHBundle) (*X3DHSenderResult, error) {
	// Generate ephemeral key pair EK_A
	ephPriv, ephPub, err := GenerateKeyPair()
	if err != nil {
		return nil, err
	}

	// DH1 = DH(IK_A, SPK_B)
	dh1, err := DH(aliceIdentityPriv, bob.SignedPrekey)
	if err != nil {
		return nil, err
	}
	// DH2 = DH(EK_A, IK_B)
	dh2, err := DH(ephPriv, bob.IdentityKey)
	if err != nil {
		return nil, err
	}
	// DH3 = DH(EK_A, SPK_B)
	dh3, err := DH(ephPriv, bob.SignedPrekey)
	if err != nil {
		return nil, err
	}

	dhInput := concat(dh1, dh2, dh3)
	usedOPK := -1

	// DH4 = DH(EK_A, OPK_B) — optional
	if bob.OneTimePrekey != nil {
		dh4, err := DH(ephPriv, bob.OneTimePrekey)
		if err != nil {
			return nil, err
		}
		dhInput = append(dhInput, dh4...)
		usedOPK = bob.OPKIndex
	}

	sharedKey, err := x3dhKDF(dhInput)
	if err != nil {
		return nil, err
	}

	return &X3DHSenderResult{
		SharedKey:    sharedKey,
		EphemeralKey: ephPub,
		UsedOPKIndex: usedOPK,
	}, nil
}

// X3DHReceiverInit performs X3DH from the receiver's (Bob's) perspective.
// Bob uses Alice's public keys (sent in the initial message) to derive the same shared key.
func X3DHReceiverInit(
	bobIdentityPriv *ecdh.PrivateKey,
	bobSignedPrekeyPriv *ecdh.PrivateKey,
	bobOPKPriv *ecdh.PrivateKey, // nil if not used
	aliceIdentityPub *ecdh.PublicKey,
	aliceEphemeralPub *ecdh.PublicKey,
) ([]byte, error) {
	// DH1 = DH(SPK_B, IK_A)
	dh1, err := DH(bobSignedPrekeyPriv, aliceIdentityPub)
	if err != nil {
		return nil, err
	}
	// DH2 = DH(IK_B, EK_A)
	dh2, err := DH(bobIdentityPriv, aliceEphemeralPub)
	if err != nil {
		return nil, err
	}
	// DH3 = DH(SPK_B, EK_A)
	dh3, err := DH(bobSignedPrekeyPriv, aliceEphemeralPub)
	if err != nil {
		return nil, err
	}

	dhInput := concat(dh1, dh2, dh3)

	// DH4 = DH(OPK_B, EK_A) — optional
	if bobOPKPriv != nil {
		dh4, err := DH(bobOPKPriv, aliceEphemeralPub)
		if err != nil {
			return nil, err
		}
		dhInput = append(dhInput, dh4...)
	}

	return x3dhKDF(dhInput)
}

// x3dhKDF derives a 32-byte shared key using HKDF-SHA256 with the Signal spec F||KM input.
func x3dhKDF(dhInput []byte) ([]byte, error) {
	// F = 0xFF * 32 (as per Signal spec)
	f := make([]byte, 32)
	for i := range f {
		f[i] = 0xFF
	}
	ikm := append(f, dhInput...)
	h := hkdf.New(sha256.New, ikm, nil, []byte(x3dhInfo))
	key := make([]byte, 32)
	_, err := io.ReadFull(h, key)
	return key, err
}

func concat(parts ...[]byte) []byte {
	var out []byte
	for _, p := range parts {
		out = append(out, p...)
	}
	return out
}
