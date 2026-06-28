package auth_test

import (
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/no-iz/iz-backend/internal/auth"
	"github.com/no-iz/iz-backend/pkg/config"
	"github.com/rs/zerolog"
)

func TestAuthService_DeclineTokens(t *testing.T) {
	// Initialize a dummy config with a secret
	cfg := &config.Config{
		JWTAccessSecret: "test-secret-key",
		JWTAccessTTL:    time.Minute * 15,
		JWTRefreshTTL:   time.Hour * 24,
	}

	// Initialize service with nil DB and Redis since we are only testing JWT functions
	svc := auth.NewService(nil, nil, cfg, zerolog.Nop())

	t.Run("Generate and Validate Decline Token", func(t *testing.T) {
		callID := uuid.New()
		
		token, err := svc.GenerateDeclineToken(callID)
		if err != nil {
			t.Fatalf("Failed to generate decline token: %v", err)
		}
		if token == "" {
			t.Fatal("Expected token to not be empty")
		}

		parsedCallID, err := svc.ValidateDeclineToken(token)
		if err != nil {
			t.Fatalf("Failed to validate decline token: %v", err)
		}

		if parsedCallID != callID {
			t.Errorf("Expected callID %v, got %v", callID, parsedCallID)
		}
	})

	t.Run("Validate Invalid Token", func(t *testing.T) {
		_, err := svc.ValidateDeclineToken("invalid.token.string")
		if err == nil {
			t.Error("Expected error for invalid token, got nil")
		}
	})
}
