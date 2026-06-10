package auth

import (
	"context"
	"errors"
	"fmt"
)

// ChangePasswordInput holds the fields required to change a password.
type ChangePasswordInput struct {
	UserID      string
	OldPassword string
	NewPassword string
}

// ChangePassword validates the old password and sets a new one.
func (s *Service) ChangePassword(ctx context.Context, in ChangePasswordInput) error {
	if len(in.NewPassword) < 8 {
		return errors.New("new password must be at least 8 characters")
	}

	// Fetch current hash
	var currentHash string
	err := s.db.QueryRow(ctx,
		`SELECT password_hash FROM users WHERE id = $1 AND is_deleted = FALSE`,
		in.UserID,
	).Scan(&currentHash)
	if err != nil {
		return ErrUserNotFound
	}

	// Verify old password
	if !s.verifyPassword(in.OldPassword, currentHash) {
		return ErrInvalidCredentials
	}

	// Hash new password
	newHash, err := s.hashPassword(in.NewPassword)
	if err != nil {
		return fmt.Errorf("hash password: %w", err)
	}

	// Update
	_, err = s.db.Exec(ctx,
		`UPDATE users SET password_hash = $1 WHERE id = $2`,
		newHash, in.UserID,
	)
	return err
}
