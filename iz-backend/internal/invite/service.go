package invite

import (
	"context"
	"crypto/rand"
	"encoding/base32"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/no-iz/iz-backend/pkg/config"
	"github.com/rs/zerolog"
)

var (
	ErrQuotaExceeded = errors.New("monthly invite quota exceeded")
	ErrCodeInvalid   = errors.New("invalid or expired invite code")
)

// Service provides business logic for the invite system
type Service struct {
	repo *Repository
	cfg  *config.Config
	log  zerolog.Logger
}

// NewService creates a new invite service
func NewService(repo *Repository, cfg *config.Config, log zerolog.Logger) *Service {
	return &Service{
		repo: repo,
		cfg:  cfg,
		log:  log,
	}
}

// GenerateRandomCode generates a random code of specified length
func GenerateRandomCode(length int) string {
	bytes := make([]byte, length)
	rand.Read(bytes)
	// Base32 encoding (uppercase, no padding)
	encoded := base32.StdEncoding.WithPadding(base32.NoPadding).EncodeToString(bytes)
	if len(encoded) > length {
		return encoded[:length]
	}
	return encoded
}

// CreateUserCode creates a new invite code for a normal user, checking their monthly quota
func (s *Service) CreateUserCode(ctx context.Context, userID uuid.UUID) (*InviteCode, error) {
	now := time.Now()
	
	// Check quota
	quota, err := s.repo.GetUserQuota(ctx, userID, now)
	if err != nil {
		return nil, fmt.Errorf("get user quota: %w", err)
	}

	if quota.CodesGenerated >= s.cfg.InviteUserMonthlyLimit {
		return nil, ErrQuotaExceeded
	}

	// Generate code
	codeStr := GenerateRandomCode(s.cfg.InviteCodeLength)

	code := &InviteCode{
		Code:        codeStr,
		CreatedByID: &userID,
		MaxUses:     s.cfg.InviteUserCodeMax,
		UseCount:    0,
		IsActive:    true,
		ExpiresAt:   nil, // Never expires by default
	}

	// Save code
	if err := s.repo.CreateCode(ctx, code); err != nil {
		return nil, fmt.Errorf("create code: %w", err)
	}

	// Increment quota
	if err := s.repo.IncrementUserQuota(ctx, userID, now); err != nil {
		s.log.Error().Err(err).Str("user_id", userID.String()).Msg("failed to increment user quota")
		// Best effort, don't fail the request
	}

	return code, nil
}

// CreateAdminCode creates a custom invite code (e.g. "HELLO") with specific limits
func (s *Service) CreateAdminCode(ctx context.Context, codeStr string, maxUses int, expiresAt *time.Time) (*InviteCode, error) {
	if codeStr == "" {
		codeStr = GenerateRandomCode(s.cfg.InviteCodeLength)
	}

	code := &InviteCode{
		Code:        codeStr,
		CreatedByID: nil, // Admin codes are system codes
		MaxUses:     maxUses,
		UseCount:    0,
		IsActive:    true,
		ExpiresAt:   expiresAt,
	}

	if err := s.repo.CreateCode(ctx, code); err != nil {
		return nil, fmt.Errorf("create admin code: %w", err)
	}

	return code, nil
}

// ValidateAndUseCode validates an invite code and records its usage
func (s *Service) ValidateAndUseCode(ctx context.Context, codeStr string, usedByID uuid.UUID) error {
	code, err := s.repo.GetCodeByCode(ctx, codeStr)
	if err != nil {
		s.log.Warn().Str("code", codeStr).Err(err).Msg("failed to find invite code")
		return ErrCodeInvalid
	}

	if !code.IsActive {
		return ErrCodeInvalid
	}

	if code.ExpiresAt != nil && code.ExpiresAt.Before(time.Now()) {
		return ErrCodeInvalid
	}

	if code.MaxUses > 0 && code.UseCount >= code.MaxUses {
		return ErrCodeInvalid
	}

	// Increment usage
	if err := s.repo.IncrementUseCount(ctx, code.ID); err != nil {
		return fmt.Errorf("increment use count: %w", err)
	}

	// Record usage
	if err := s.repo.RecordUse(ctx, code.ID, usedByID); err != nil {
		s.log.Error().Err(err).Str("code_id", code.ID.String()).Str("used_by", usedByID.String()).Msg("failed to record code usage")
	}

	return nil
}

// GetCodeInfo returns info about a code without using it (for validation UI)
func (s *Service) GetCodeInfo(ctx context.Context, codeStr string) (*InviteCode, error) {
	code, err := s.repo.GetCodeByCode(ctx, codeStr)
	if err != nil {
		return nil, ErrCodeInvalid
	}
	
	if !code.IsActive || (code.ExpiresAt != nil && code.ExpiresAt.Before(time.Now())) || (code.MaxUses > 0 && code.UseCount >= code.MaxUses) {
		return nil, ErrCodeInvalid
	}

	return code, nil
}

// ListAdminCodes returns all admin codes
func (s *Service) ListAdminCodes(ctx context.Context) ([]*InviteCode, error) {
	return s.repo.ListAdminCodes(ctx)
}
