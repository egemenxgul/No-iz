package economy

import (
	"context"

	"github.com/google/uuid"
	"github.com/rs/zerolog"
)

type Service struct {
	repo *Repository
	log  zerolog.Logger
}

func NewService(repo *Repository, log zerolog.Logger) *Service {
	return &Service{
		repo: repo,
		log:  log.With().Str("svc", "economy").Logger(),
	}
}

func (s *Service) GetUserLimits(ctx context.Context, userID uuid.UUID) (Features, Tier, int64, error) {
	tier, _, _, storageUsed, err := s.repo.GetUserSubscription(ctx, userID)
	if err != nil {
		return GetFeatures(TierFree), TierFree, 0, err
	}
	return GetFeatures(tier), tier, storageUsed, nil
}

func (s *Service) GetUserSubscriptionDetails(ctx context.Context, userID uuid.UUID) (SubscriptionInfo, error) {
	tier, periodEnd, downgrade, storageUsed, err := s.repo.GetUserSubscription(ctx, userID)
	if err != nil {
		return SubscriptionInfo{Tier: TierFree}, err
	}
	
	periodStr := ""
	if periodEnd != nil {
		periodStr = periodEnd.Format("2006-01-02T15:04:05Z07:00")
	}

	return SubscriptionInfo{
		Tier:               tier,
		PeriodEnd:          periodStr,
		ScheduledDowngrade: downgrade,
		StorageUsedBytes:   storageUsed,
	}, nil
}

func (s *Service) Subscribe(ctx context.Context, userID uuid.UUID, newTier Tier) error {
	// Upgrade/Downgrade logic is routed to HandleSubscriptionChange
	return s.HandleSubscriptionChange(ctx, userID, newTier)
}

func (s *Service) ConsumeStorage(ctx context.Context, userID uuid.UUID, bytes int64) error {
	return s.repo.AddStorageUsage(ctx, userID, bytes)
}

func (s *Service) ReleaseStorage(ctx context.Context, userID uuid.UUID, bytes int64) error {
	return s.repo.SubtractStorageUsage(ctx, userID, bytes)
}
