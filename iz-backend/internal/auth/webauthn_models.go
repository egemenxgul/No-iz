package auth

import (
	"github.com/go-webauthn/webauthn/webauthn"
	"github.com/google/uuid"
)

// WebAuthnUser represents a user for WebAuthn.
// It implements the webauthn.User interface.
type WebAuthnUser struct {
	ID          uuid.UUID
	Username    string
	DisplayName string
	Credentials []webauthn.Credential
}

// WebAuthnID returns the user's UUID.
func (u *WebAuthnUser) WebAuthnID() []byte {
	return []byte(u.ID.String())
}

// WebAuthnName returns the user's username.
func (u *WebAuthnUser) WebAuthnName() string {
	return u.Username
}

// WebAuthnDisplayName returns the user's display name.
func (u *WebAuthnUser) WebAuthnDisplayName() string {
	return u.DisplayName
}

// WebAuthnIcon returns a URL to an icon for the user. (Optional)
func (u *WebAuthnUser) WebAuthnIcon() string {
	return ""
}

// WebAuthnCredentials returns the credentials owned by the user.
func (u *WebAuthnUser) WebAuthnCredentials() []webauthn.Credential {
	return u.Credentials
}
