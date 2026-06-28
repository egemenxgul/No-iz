package economy

import (
	"context"
	"time"

	"github.com/rs/zerolog"
)

// StartCronWorker starts a background goroutine that checks for downgrades every hour.
func StartCronWorker(ctx context.Context, repo *Repository, log zerolog.Logger) {
	ticker := time.NewTicker(1 * time.Hour)
	go func() {
		defer ticker.Stop()
		for {
			select {
			case <-ctx.Done():
				return
			case <-ticker.C:
				processDowngrades(context.Background(), repo, log)
			}
		}
	}()
	
	// Also run once on startup
	go processDowngrades(context.Background(), repo, log)
}

func processDowngrades(ctx context.Context, repo *Repository, log zerolog.Logger) {
	log.Info().Msg("Cron: Checking for scheduled subscription downgrades")
	affected, err := repo.ProcessScheduledDowngrades(ctx)
	if err != nil {
		log.Error().Err(err).Msg("Cron: Failed to process scheduled downgrades")
		return
	}
	if affected > 0 {
		log.Info().Int64("count", affected).Msg("Cron: Successfully applied scheduled downgrades")
	}
}
