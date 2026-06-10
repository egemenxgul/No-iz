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
