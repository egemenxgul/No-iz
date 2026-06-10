package invite

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

// InviteCode represents an invite code in the database
type InviteCode struct {
	ID          uuid.UUID  `json:"id"`
	Code        string     `json:"code"`
	CreatedByID *uuid.UUID `json:"created_by_id"`
	MaxUses     int        `json:"max_uses"`
	UseCount    int        `json:"use_count"`
	IsActive    bool       `json:"is_active"`
	ExpiresAt   *time.Time `json:"expires_at"`
	CreatedAt   time.Time  `json:"created_at"`
}

// UserInviteQuota represents a user's monthly invite generation quota
type UserInviteQuota struct {
	UserID         uuid.UUID `json:"user_id"`
	Month          time.Time `json:"month"`
	CodesGenerated int       `json:"codes_generated"`
}

// Repository handles database operations for invites
type Repository struct {
	db *pgxpool.Pool
}

// NewRepository creates a new invite repository
func NewRepository(db *pgxpool.Pool) *Repository {
	return &Repository{db: db}
}

// CreateCode inserts a new invite code
func (r *Repository) CreateCode(ctx context.Context, code *InviteCode) error {
	query := `
		INSERT INTO invite_codes (code, created_by_id, max_uses, use_count, is_active, expires_at)
		VALUES ($1, $2, $3, $4, $5, $6)
		RETURNING id, created_at
	`
	err := r.db.QueryRow(ctx, query,
		code.Code, code.CreatedByID, code.MaxUses, code.UseCount, code.IsActive, code.ExpiresAt,
	).Scan(&code.ID, &code.CreatedAt)
	
	return err
}

// GetCodeByCode retrieves an invite code by its string code
func (r *Repository) GetCodeByCode(ctx context.Context, codeStr string) (*InviteCode, error) {
	query := `
		SELECT id, code, created_by_id, max_uses, use_count, is_active, expires_at, created_at
		FROM invite_codes
		WHERE code = $1
	`
	code := &InviteCode{}
	err := r.db.QueryRow(ctx, query, codeStr).Scan(
		&code.ID, &code.Code, &code.CreatedByID, &code.MaxUses, &code.UseCount,
		&code.IsActive, &code.ExpiresAt, &code.CreatedAt,
	)
	if err != nil {
		return nil, err
	}
	return code, nil
}

// IncrementUseCount increments the use_count of a code
func (r *Repository) IncrementUseCount(ctx context.Context, codeID uuid.UUID) error {
	query := `
		UPDATE invite_codes
		SET use_count = use_count + 1,
		    is_active = CASE WHEN max_uses > 0 AND use_count + 1 >= max_uses THEN FALSE ELSE is_active END
		WHERE id = $1
	`
	_, err := r.db.Exec(ctx, query, codeID)
	return err
}

// RecordUse records that a user used a specific code
func (r *Repository) RecordUse(ctx context.Context, codeID, usedByID uuid.UUID) error {
	query := `
		INSERT INTO invite_uses (code_id, used_by_id)
		VALUES ($1, $2)
	`
	_, err := r.db.Exec(ctx, query, codeID, usedByID)
	return err
}

// GetUserQuota gets or initializes the user's quota for the given month
func (r *Repository) GetUserQuota(ctx context.Context, userID uuid.UUID, month time.Time) (*UserInviteQuota, error) {
	// Truncate month to the 1st day of the month
	firstOfMonth := time.Date(month.Year(), month.Month(), 1, 0, 0, 0, 0, month.Location())
	
	query := `
		INSERT INTO user_invite_quotas (user_id, month, codes_generated)
		VALUES ($1, $2, 0)
		ON CONFLICT (user_id, month) DO UPDATE SET user_id = EXCLUDED.user_id
		RETURNING user_id, month, codes_generated
	`
	quota := &UserInviteQuota{}
	err := r.db.QueryRow(ctx, query, userID, firstOfMonth).Scan(
		&quota.UserID, &quota.Month, &quota.CodesGenerated,
	)
	if err != nil {
		return nil, err
	}
	return quota, nil
}

// IncrementUserQuota increments the codes_generated for a user in a specific month
func (r *Repository) IncrementUserQuota(ctx context.Context, userID uuid.UUID, month time.Time) error {
	firstOfMonth := time.Date(month.Year(), month.Month(), 1, 0, 0, 0, 0, month.Location())
	query := `
		UPDATE user_invite_quotas
		SET codes_generated = codes_generated + 1
		WHERE user_id = $1 AND month = $2
	`
	_, err := r.db.Exec(ctx, query, userID, firstOfMonth)
	return err
}

// ListAdminCodes lists all codes created by admin (created_by_id IS NULL)
func (r *Repository) ListAdminCodes(ctx context.Context) ([]*InviteCode, error) {
	query := `
		SELECT id, code, created_by_id, max_uses, use_count, is_active, expires_at, created_at
		FROM invite_codes
		WHERE created_by_id IS NULL
		ORDER BY created_at DESC
	`
	rows, err := r.db.Query(ctx, query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var codes []*InviteCode
	for rows.Next() {
		code := &InviteCode{}
		err := rows.Scan(
			&code.ID, &code.Code, &code.CreatedByID, &code.MaxUses, &code.UseCount,
			&code.IsActive, &code.ExpiresAt, &code.CreatedAt,
		)
		if err != nil {
			return nil, err
		}
		codes = append(codes, code)
	}
	return codes, nil
}
