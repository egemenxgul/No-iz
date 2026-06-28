package auth

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/go-webauthn/webauthn/protocol"
	"github.com/go-webauthn/webauthn/webauthn"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
)

// PasskeyRegistrationData temporarily stores user data between begin and finish.
type PasskeyRegistrationData struct {
	User        WebAuthnUser `json:"user"`
	SessionData webauthn.SessionData `json:"session_data"`
	Email       string `json:"email"`
	InviteCode  string `json:"invite_code"`
}

// ─────────────────────────────────────────────────────────────────────────────
// REGISTRATION
// ─────────────────────────────────────────────────────────────────────────────

func (s *Service) BeginPasskeyRegistration(ctx context.Context, username, email, displayName, inviteCode string) (*protocol.CredentialCreation, string, error) {
	username = strings.ToLower(strings.TrimSpace(username))
	
	// Basic validation
	if len(username) < 3 || len(username) > 32 {
		return nil, "", fmt.Errorf("err_username_length")
	}
	if !strings.Contains(email, "@") {
		return nil, "", fmt.Errorf("err_invalid_email")
	}
	if inviteCode == "" {
		return nil, "", fmt.Errorf("err_invite_code_required")
	}

	// 1. Check if username or email already exists
	var count int
	err := s.db.QueryRow(ctx, "SELECT COUNT(*) FROM users WHERE username = $1 OR email = $2", username, email).Scan(&count)
	if err != nil {
		return nil, "", fmt.Errorf("check existing user: %w", err)
	}
	if count > 0 {
		return nil, "", fmt.Errorf("err_username_taken") // or email taken
	}

	// 2. Validate invite code
	var codeID uuid.UUID
	var maxUses, usedCount int
	err = s.db.QueryRow(ctx, `
		SELECT id, max_uses, used_count
		FROM invites
		WHERE code = $1 AND is_active = TRUE AND (expires_at IS NULL OR expires_at > NOW())
	`, inviteCode).Scan(&codeID, &maxUses, &usedCount)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, "", fmt.Errorf("err_invalid_invite_code")
		}
		return nil, "", err
	}
	if maxUses > 0 && usedCount >= maxUses {
		return nil, "", fmt.Errorf("err_invite_code_full")
	}

	// 3. Create a temporary WebAuthn user
	userID := uuid.New()
	user := WebAuthnUser{
		ID:          userID,
		Username:    username,
		DisplayName: displayName,
		Credentials: []webauthn.Credential{},
	}

	// 4. Begin Registration
	creationData, sessionData, err := s.wa.BeginRegistration(&user)
	if err != nil {
		return nil, "", fmt.Errorf("begin registration: %w", err)
	}

	// 5. Store session data in Redis for 5 minutes
	sessionID := uuid.New().String()
	regData := PasskeyRegistrationData{
		User:        user,
		SessionData: *sessionData,
		Email:       email,
		InviteCode:  inviteCode,
	}
	
	b, _ := json.Marshal(regData)
	if err := s.rdb.Set(ctx, "wa:reg:"+sessionID, b, 5*time.Minute).Err(); err != nil {
		return nil, "", fmt.Errorf("redis set: %w", err)
	}

	return creationData, sessionID, nil
}

// CreatePasskeyUser creates the user and saves their webauthn credential
func (s *Service) CreatePasskeyUser(ctx context.Context, regData PasskeyRegistrationData, credential *webauthn.Credential) (*AppleAuthResult, error) {
	// Start transaction
	tx, err := s.db.Begin(ctx)
	if err != nil {
		return nil, fmt.Errorf("begin tx: %w", err)
	}
	defer tx.Rollback(ctx)

	// 1. Mark invite code as used
	_, err = tx.Exec(ctx, "UPDATE invites SET used_count = used_count + 1 WHERE code = $1", regData.InviteCode)
	if err != nil {
		return nil, fmt.Errorf("update invite: %w", err)
	}

	// 2. Insert User (empty password_hash)
	_, err = tx.Exec(ctx, `
		INSERT INTO users (id, username, email, display_name, password_hash, created_at, updated_at)
		VALUES ($1, $2, $3, $4, '', NOW(), NOW())
	`, regData.User.ID, regData.User.Username, regData.Email, regData.User.DisplayName)
	if err != nil {
		return nil, fmt.Errorf("insert user: %w", err)
	}

	// 3. Insert WebAuthn Credential
	_, err = tx.Exec(ctx, `
		INSERT INTO webauthn_credentials (id, user_id, credential_id, public_key, attestation_type, sign_count, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, NOW(), NOW())
	`, uuid.New(), regData.User.ID, credential.ID, credential.PublicKey, credential.AttestationType, credential.Authenticator.SignCount)
	if err != nil {
		return nil, fmt.Errorf("insert credential: %w", err)
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, fmt.Errorf("commit tx: %w", err)
	}

	// 4. Issue tokens
	accessToken, refreshToken, err := s.issueTokens(ctx, regData.User.ID.String(), "", false)
	if err != nil {
		return nil, fmt.Errorf("issue tokens: %w", err)
	}

	return &AppleAuthResult{
		AccessToken:  accessToken,
		RefreshToken: refreshToken,
		UserID:       regData.User.ID.String(),
		Username:     regData.User.Username,
		DisplayName:  regData.User.DisplayName,
		AvatarURL:    "",
		IsNewUser:    true,
	}, nil
}
// ─────────────────────────────────────────────────────────────────────────────
// LOGIN
// ─────────────────────────────────────────────────────────────────────────────

func (s *Service) BeginPasskeyLogin(ctx context.Context, username string) (*protocol.CredentialAssertion, string, error) {
	username = strings.ToLower(strings.TrimSpace(username))

	var user WebAuthnUser
	err := s.db.QueryRow(ctx, "SELECT id, username, display_name FROM users WHERE username = $1 OR email = $1", username).
		Scan(&user.ID, &user.Username, &user.DisplayName)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, "", fmt.Errorf("user not found")
		}
		return nil, "", err
	}

	// Fetch credentials
	rows, err := s.db.Query(ctx, "SELECT credential_id, public_key, attestation_type, authenticator_aaguid, sign_count FROM webauthn_credentials WHERE user_id = $1", user.ID)
	if err != nil {
		return nil, "", err
	}
	defer rows.Close()

	for rows.Next() {
		var cred webauthn.Credential
		err := rows.Scan(&cred.ID, &cred.PublicKey, &cred.AttestationType, &cred.Authenticator.AAGUID, &cred.Authenticator.SignCount)
		if err != nil {
			continue
		}
		user.Credentials = append(user.Credentials, cred)
	}

	if len(user.Credentials) == 0 {
		return nil, "", fmt.Errorf("no passkeys found for user")
	}

	assertion, sessionData, err := s.wa.BeginLogin(&user)
	if err != nil {
		return nil, "", err
	}

	sessionID := uuid.New().String()
	regData := PasskeyRegistrationData{
		User:        user,
		SessionData: *sessionData,
	}

	b, _ := json.Marshal(regData)
	if err := s.rdb.Set(ctx, "wa:log:"+sessionID, b, 5*time.Minute).Err(); err != nil {
		return nil, "", err
	}

	return assertion, sessionID, nil
}

// AuthenticatePasskeyUser verifies the credential and issues tokens
func (s *Service) AuthenticatePasskeyUser(ctx context.Context, regData PasskeyRegistrationData, credential *webauthn.Credential) (*AppleAuthResult, error) {
	// Update sign_count
	_, err := s.db.Exec(ctx, "UPDATE webauthn_credentials SET sign_count = $1, updated_at = NOW() WHERE credential_id = $2", credential.Authenticator.SignCount, credential.ID)
	if err != nil {
		return nil, fmt.Errorf("update sign_count: %w", err)
	}

	// Issue tokens
	accessToken, refreshToken, err := s.issueTokens(ctx, regData.User.ID.String(), "", false)
	if err != nil {
		return nil, fmt.Errorf("issue tokens: %w", err)
	}

	return &AppleAuthResult{
		AccessToken:  accessToken,
		RefreshToken: refreshToken,
		UserID:       regData.User.ID.String(),
		Username:     regData.User.Username,
		DisplayName:  regData.User.DisplayName,
		AvatarURL:    "",
		IsNewUser:    false,
	}, nil
}
