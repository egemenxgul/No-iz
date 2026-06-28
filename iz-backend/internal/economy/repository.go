package economy

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

type Repository struct {
	db *pgxpool.Pool
}

func NewRepository(db *pgxpool.Pool) *Repository {
	return &Repository{db: db}
}

func (r *Repository) GetUserSubscription(ctx context.Context, userID uuid.UUID) (Tier, *time.Time, *Tier, int64, error) {
	var tierStr string
	var periodEnd *time.Time
	var downgradeStr *string
	var storageUsed int64
	err := r.db.QueryRow(ctx, `SELECT subscription_tier, subscription_period_end, scheduled_downgrade_tier, storage_used_bytes FROM users WHERE id=$1`, userID).Scan(&tierStr, &periodEnd, &downgradeStr, &storageUsed)
	if err != nil {
		return TierFree, nil, nil, 0, err
	}
	
	var downgradeTier *Tier
	if downgradeStr != nil {
		t := Tier(*downgradeStr)
		downgradeTier = &t
	}
	
	return Tier(tierStr), periodEnd, downgradeTier, storageUsed, nil
}

func (r *Repository) GetUserTierAndStorage(ctx context.Context, userID uuid.UUID) (Tier, int64, error) {
	tier, _, _, storageUsed, err := r.GetUserSubscription(ctx, userID)
	return tier, storageUsed, err
}

func (r *Repository) AddStorageUsage(ctx context.Context, userID uuid.UUID, bytes int64) error {
	_, err := r.db.Exec(ctx, `UPDATE users SET storage_used_bytes = storage_used_bytes + $1 WHERE id = $2`, bytes, userID)
	return err
}

func (r *Repository) SubtractStorageUsage(ctx context.Context, userID uuid.UUID, bytes int64) error {
	_, err := r.db.Exec(ctx, `UPDATE users SET storage_used_bytes = GREATEST(0, storage_used_bytes - $1) WHERE id = $2`, bytes, userID)
	return err
}

func (r *Repository) UpdateSubscriptionTier(ctx context.Context, userID uuid.UUID, tier Tier) error {
	_, err := r.db.Exec(ctx, `UPDATE users SET subscription_tier = $1, subscription_period_end = NOW() + INTERVAL '30 days', scheduled_downgrade_tier = NULL WHERE id = $2`, string(tier), userID)
	return err
}

func (r *Repository) ScheduleDowngrade(ctx context.Context, userID uuid.UUID, tier Tier) error {
	_, err := r.db.Exec(ctx, `UPDATE users SET scheduled_downgrade_tier = $1 WHERE id = $2`, string(tier), userID)
	return err
}

func (r *Repository) ProcessScheduledDowngrades(ctx context.Context) (int64, error) {
	res, err := r.db.Exec(ctx, `
		UPDATE users 
		SET subscription_tier = scheduled_downgrade_tier, 
		    scheduled_downgrade_tier = NULL,
		    subscription_period_end = NOW() + INTERVAL '30 days'
		WHERE scheduled_downgrade_tier IS NOT NULL 
		  AND subscription_period_end <= NOW()
	`)
	if err != nil {
		return 0, err
	}
	return res.RowsAffected(), nil
}
