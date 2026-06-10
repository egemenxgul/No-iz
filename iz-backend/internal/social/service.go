package social

import (
	"context"

	"github.com/google/uuid"
	"github.com/rs/zerolog"
)

// Service provides the business logic for friendships and social features.
type Service struct {
	repo *Repository
	log  zerolog.Logger
}

// NewService creates a new Service instance.
func NewService(repo *Repository, log zerolog.Logger) *Service {
	return &Service{
		repo: repo,
		log:  log.With().Str("svc", "social").Logger(),
	}
}

// GetStatus checks the friendship status between two users.
func (s *Service) GetStatus(ctx context.Context, myID, otherID uuid.UUID) (*FriendshipStatus, error) {
	status, reqID, err := s.repo.GetFriendshipStatus(ctx, myID, otherID)
	if err != nil {
		s.log.Error().Err(err).Str("my_id", myID.String()).Str("other_id", otherID.String()).Msg("failed to get friendship status")
		return nil, err
	}

	isBlocked, err := s.repo.IsBlocked(ctx, myID, otherID)
	if err != nil {
		s.log.Error().Err(err).Msg("failed to check IsBlocked")
	}

	hasBlocked, err := s.repo.HasBlocked(ctx, myID, otherID)
	if err != nil {
		s.log.Error().Err(err).Msg("failed to check HasBlocked")
	}

	return &FriendshipStatus{
		Status:     status,
		RequestID:  reqID,
		IsBlocked:  isBlocked,
		HasBlocked: hasBlocked,
	}, nil
}

// AcceptRequest marks the friendship request as accepted.
func (s *Service) AcceptRequest(ctx context.Context, myID, otherID uuid.UUID) error {
	err := s.repo.AcceptFriendship(ctx, myID, otherID)
	if err != nil {
		s.log.Error().Err(err).Str("my_id", myID.String()).Str("other_id", otherID.String()).Msg("failed to accept friendship request")
		return err
	}
	s.log.Info().Str("my_id", myID.String()).Str("other_id", otherID.String()).Msg("friendship request accepted")
	return nil
}

// RejectRequest marks the friendship request as rejected.
func (s *Service) RejectRequest(ctx context.Context, myID, otherID uuid.UUID) error {
	err := s.repo.RejectFriendship(ctx, myID, otherID)
	if err != nil {
		s.log.Error().Err(err).Str("my_id", myID.String()).Str("other_id", otherID.String()).Msg("failed to reject friendship request")
		return err
	}
	s.log.Info().Str("my_id", myID.String()).Str("other_id", otherID.String()).Msg("friendship request rejected")
	return nil
}

// BlockUser blocks a user.
func (s *Service) BlockUser(ctx context.Context, myID, otherID uuid.UUID) error {
	err := s.repo.BlockUser(ctx, myID, otherID)
	if err != nil {
		s.log.Error().Err(err).Str("my_id", myID.String()).Str("other_id", otherID.String()).Msg("failed to block user")
		return err
	}
	s.log.Info().Str("my_id", myID.String()).Str("other_id", otherID.String()).Msg("user blocked")
	return nil
}

// UnblockUser unblocks a user.
func (s *Service) UnblockUser(ctx context.Context, myID, otherID uuid.UUID) error {
	err := s.repo.UnblockUser(ctx, myID, otherID)
	if err != nil {
		s.log.Error().Err(err).Str("my_id", myID.String()).Str("other_id", otherID.String()).Msg("failed to unblock user")
		return err
	}
	s.log.Info().Str("my_id", myID.String()).Str("other_id", otherID.String()).Msg("user unblocked")
	return nil
}
