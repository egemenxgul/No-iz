package auth

import (
	"context"
	"errors"
	"fmt"
	"strings"
)

// ChangeEmailInput holds the fields required to change an email address.
type ChangeEmailInput struct {
	UserID   string
	Password string
	NewEmail string
}

// ChangeEmail validates the password and sets a new email address.
func (s *Service) ChangeEmail(ctx context.Context, in ChangeEmailInput) error {
	in.NewEmail = strings.TrimSpace(strings.ToLower(in.NewEmail))
	if !strings.Contains(in.NewEmail, "@") {
		return errors.New("invalid email format")
	}

	// Fetch current password hash
	var currentHash string
	err := s.db.QueryRow(ctx,
		`SELECT password_hash FROM users WHERE id = $1 AND is_deleted = FALSE`,
		in.UserID,
	).Scan(&currentHash)
	if err != nil {
		return ErrUserNotFound
	}

	// Verify password
	if !s.verifyPassword(in.Password, currentHash) {
		return ErrInvalidCredentials
	}

	// Check if new email is already taken
	if exists, _ := s.emailExists(ctx, in.NewEmail); exists {
		return ErrEmailTaken
	}

	// Encrypt and hash the new email
	emailEnc, err := s.encryptData(in.NewEmail)
	if err != nil {
		return fmt.Errorf("encrypt email: %w", err)
	}
	emailHash := s.hashEmail(in.NewEmail)

	// Update the database
	_, err = s.db.Exec(ctx,
		`UPDATE users SET email = $1, email_hash = $2 WHERE id = $3`,
		emailEnc, emailHash, in.UserID,
	)
	return err
}
