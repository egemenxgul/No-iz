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

func (s *Service) MarkStoryAsViewed(ctx context.Context, storyID, viewerID uuid.UUID) error {
	err := s.repo.InsertStoryView(ctx, storyID, viewerID)
	if err != nil {
		s.log.Error().Err(err).Str("story_id", storyID.String()).Str("viewer_id", viewerID.String()).Msg("failed to mark story as viewed")
		return err
	}
	return nil
}

func (s *Service) GetStoryViewers(ctx context.Context, storyID uuid.UUID) ([]*StoryViewer, error) {
	viewers, err := s.repo.GetStoryViewers(ctx, storyID)
	if err != nil {
		s.log.Error().Err(err).Str("story_id", storyID.String()).Msg("failed to fetch story viewers")
		return nil, err
	}
	return viewers, nil
}
