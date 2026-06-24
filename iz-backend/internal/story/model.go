package story

import (
	"time"

	"github.com/google/uuid"
)

// Story represents an active user status update.
type Story struct {
	ID        uuid.UUID `json:"id"`
	UserID    uuid.UUID `json:"user_id"`
	MediaURL  string    `json:"media_url"`
	Caption   string    `json:"caption"`
	MediaType string    `json:"media_type"`
	CreatedAt time.Time `json:"created_at"`
	ExpiresAt time.Time `json:"expires_at"`
}

// FriendStoryFeed groups a friend's active stories together.
type FriendStoryFeed struct {
	UserID      uuid.UUID `json:"user_id"`
	Username    string    `json:"username"`
	DisplayName string    `json:"display_name"`
	AvatarURL   string    `json:"avatar_url"`
	Stories     []*Story  `json:"stories"`
}

// StoryView represents a record of a user viewing a story.
type StoryView struct {
	ID       uuid.UUID `json:"id"`
	StoryID  uuid.UUID `json:"story_id"`
	ViewerID uuid.UUID `json:"viewer_id"`
	ViewedAt time.Time `json:"viewed_at"`
}

// StoryViewer holds data for the UI to display who viewed a story.
type StoryViewer struct {
	ViewerID    uuid.UUID `json:"viewer_id"`
	Username    string    `json:"username"`
	DisplayName string    `json:"display_name"`
	AvatarURL   string    `json:"avatar_url"`
	ViewedAt    time.Time `json:"viewed_at"`
}
