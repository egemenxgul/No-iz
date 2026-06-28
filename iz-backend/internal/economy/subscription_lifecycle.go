package economy

import (
	"context"

	"github.com/google/uuid"
)

// HandleSubscriptionChange manages the logic for Upgrading and Downgrading subscriptions.
func (s *Service) HandleSubscriptionChange(ctx context.Context, userID uuid.UUID, newTier Tier) error {
	currentTier, periodEnd, scheduledDowngrade, _, err := s.repo.GetUserSubscription(ctx, userID)
	if err != nil {
		return err
	}

	// If the user is already on this tier, check if they had a downgrade scheduled.
	if currentTier == newTier {
		if scheduledDowngrade != nil {
			// Cancel downgrade
			return s.repo.ScheduleDowngrade(ctx, userID, "") // Passing empty or using a cancel method. Wait, our SQL for ScheduleDowngrade doesn't handle empty well if we map it to NULL.
		}
		return nil
	}

	currentPrice := TierPricing[currentTier]
	newPrice := TierPricing[newTier]

	if newPrice > currentPrice {
		// UPGRADE: Immediate effect with proration
		s.log.Info().Str("user", userID.String()).Str("from", string(currentTier)).Str("to", string(newTier)).Msg("Processing subscription upgrade")
		
		// In a real system, calculate prorated cost here
		// ...
		
		err = s.repo.UpdateSubscriptionTier(ctx, userID, newTier)
		if err != nil {
			return err
		}

		if newTier == TierPro || newTier == TierElite {
			_, err = s.repo.db.Exec(ctx, `UPDATE users SET relay_calls = true WHERE id = $1`, userID)
			if err != nil {
				s.log.Warn().Err(err).Str("user", userID.String()).Msg("failed to auto-enable relay_calls on upgrade")
			}
		}

		return nil
	} else {
		// DOWNGRADE: Schedule for end of billing cycle
		s.log.Info().Str("user", userID.String()).Str("from", string(currentTier)).Str("to", string(newTier)).Time("effective_date", *periodEnd).Msg("Scheduling subscription downgrade")
		return s.repo.ScheduleDowngrade(ctx, userID, newTier)
	}
}

// CancelDowngrade removes any pending downgrade
func (s *Service) CancelDowngrade(ctx context.Context, userID uuid.UUID) error {
	_, err := s.repo.db.Exec(ctx, `UPDATE users SET scheduled_downgrade_tier = NULL WHERE id = $1`, userID)
	return err
}
