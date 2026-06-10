package backup

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
		log:  log.With().Str("svc", "backup").Logger(),
	}
}

func (s *Service) SaveBackup(ctx context.Context, b *Backup) error {
	err := s.repo.Save(ctx, b)
	if err != nil {
		s.log.Error().Err(err).Str("user_id", b.UserID.String()).Msg("failed to save backup")
		return err
	}

	s.log.Info().Str("user_id", b.UserID.String()).Msg("backup successfully saved")
	return nil
}

func (s *Service) GetBackup(ctx context.Context, userID uuid.UUID) (*Backup, error) {
	b, err := s.repo.GetByUserID(ctx, userID)
	if err != nil {
		s.log.Error().Err(err).Str("user_id", userID.String()).Msg("failed to retrieve backup")
		return nil, err
	}

	return b, nil
}
