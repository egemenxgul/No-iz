package story

import (
	"context"
	"time"

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
		log:  log.With().Str("svc", "story").Logger(),
	}
}

func (s *Service) CreateStory(ctx context.Context, story *Story) error {
	if story.ExpiresAt.IsZero() {
		story.ExpiresAt = time.Now().Add(24 * time.Hour)
	}

	err := s.repo.Create(ctx, story)
	if err != nil {
		s.log.Error().Err(err).Str("user_id", story.UserID.String()).Msg("failed to create story")
		return err
	}

	s.log.Info().Str("story_id", story.ID.String()).Str("user_id", story.UserID.String()).Msg("story created successfully")
	return nil
}

func (s *Service) DeleteStory(ctx context.Context, storyID, userID uuid.UUID) error {
	err := s.repo.Delete(ctx, storyID, userID)
	if err != nil {
		s.log.Error().Err(err).Str("story_id", storyID.String()).Str("user_id", userID.String()).Msg("failed to delete story")
		return err
	}

	s.log.Info().Str("story_id", storyID.String()).Str("user_id", userID.String()).Msg("story deleted successfully")
	return nil
}

func (s *Service) GetFeed(ctx context.Context, userID uuid.UUID) ([]*FriendStoryFeed, error) {
	feed, err := s.repo.ListActiveFromFriends(ctx, userID)
	if err != nil {
		s.log.Error().Err(err).Str("user_id", userID.String()).Msg("failed to retrieve friends story feed")
		return nil, err
	}

	return feed, nil
}
