package auth

import (
	"context"
	"fmt"


	"github.com/google/uuid"
	"golang.org/x/crypto/argon2"
)

func (s *Service) SetupPINAndKeys(ctx context.Context, userIDStr, pin, identityKey, signedPrekey, signedPrekeySig string, otpReq []prekeyRequest) error {
	userID, err := uuid.Parse(userIDStr)
	if err != nil {
		return err
	}

	// Hash the PIN using Argon2id (same as password hashing)
	salt := make([]byte, 16)
	hash := argon2.IDKey([]byte(pin), salt, 1, 64*1024, 4, 32)
	passwordHash := fmt.Sprintf("%x.%x", salt, hash)

	// Update user's password_hash and mark last_pin_prompt_at = NOW()
	_, err = s.db.Exec(ctx, `
		UPDATE users 
		SET password_hash = $1, last_pin_prompt_at = NOW(), updated_at = NOW()
		WHERE id = $2
	`, passwordHash, userID)
	if err != nil {
		return fmt.Errorf("update pin: %w", err)
	}

	// Insert keys
	var prekeys []OneTimePrekey
	for _, pk := range otpReq {
		prekeys = append(prekeys, OneTimePrekey{KeyID: pk.KeyID, PublicKey: pk.PublicKey})
	}

	err = s.ReplenishPrekeys(ctx, userID, prekeys)
	if err != nil {
		return fmt.Errorf("replenish prekeys: %w", err)
	}

	return nil
}

func (s *Service) VerifyPIN(ctx context.Context, userIDStr, pin string) error {
	userID, err := uuid.Parse(userIDStr)
	if err != nil {
		return err
	}

	var passwordHash string
	err = s.db.QueryRow(ctx, "SELECT password_hash FROM users WHERE id = $1", userID).Scan(&passwordHash)
	if err != nil {
		return err
	}

	// Compare PIN
	if !s.verifyPassword(pin, passwordHash) {
		return fmt.Errorf("invalid pin")
	}

	// Update last_pin_prompt_at
	_, err = s.db.Exec(ctx, "UPDATE users SET last_pin_prompt_at = NOW() WHERE id = $1", userID)
	return err
}
