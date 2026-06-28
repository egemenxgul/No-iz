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

func (s *Service) SaveVaultMessages(ctx context.Context, userID uuid.UUID, messages []VaultMessage) error {
	err := s.repo.SaveVaultMessages(ctx, userID, messages)
	if err != nil {
		s.log.Error().Err(err).Str("user_id", userID.String()).Msg("failed to save vault messages")
		return err
	}
	s.log.Info().Str("user_id", userID.String()).Int("count", len(messages)).Msg("vault messages successfully saved")
	return nil
}

func (s *Service) GetVaultMessages(ctx context.Context, userID, convID uuid.UUID, limit, offset int) ([]VaultMessage, error) {
	msgs, err := s.repo.GetVaultMessages(ctx, userID, convID, limit, offset)
	if err != nil {
		s.log.Error().Err(err).Str("user_id", userID.String()).Str("conv_id", convID.String()).Msg("failed to get vault messages")
		return nil, err
	}
	return msgs, nil
}
