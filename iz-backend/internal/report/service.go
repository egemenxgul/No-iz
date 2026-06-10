package report

import (
	"context"

	"github.com/rs/zerolog"
)

type Service struct {
	repo *Repository
	log  zerolog.Logger
}

func NewService(repo *Repository, log zerolog.Logger) *Service {
	return &Service{
		repo: repo,
		log:  log.With().Str("svc", "report").Logger(),
	}
}

func (s *Service) SubmitReport(ctx context.Context, rep *Report) error {
	err := s.repo.Create(ctx, rep)
	if err != nil {
		s.log.Error().Err(err).Str("reporter_id", rep.ReporterID.String()).Msg("failed to create abuse report")
		return err
	}

	s.log.Info().Str("report_id", rep.ID.String()).Str("reporter_id", rep.ReporterID.String()).Msg("abuse report submitted")
	return nil
}
