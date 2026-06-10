package social

import (
	"time"

	"github.com/google/uuid"
)

// FriendStatus represents the status of a friend request.
type FriendStatus string

const (
	StatusPending  FriendStatus = "pending"
	StatusAccepted FriendStatus = "accepted"
	StatusRejected FriendStatus = "rejected"
)

// FriendRequest represents a friend request between two users.
type FriendRequest struct {
	ID         uuid.UUID    `json:"id"`
	FromUserID uuid.UUID    `json:"from_user_id"`
	ToUserID   uuid.UUID    `json:"to_user_id"`
	Status     FriendStatus `json:"status"`
	CreatedAt  time.Time    `json:"created_at"`
	UpdatedAt  time.Time    `json:"updated_at"`
}

// FriendInfo represents a friend (accepted connection) with profile details.
type FriendInfo struct {
	UserID      uuid.UUID `json:"user_id"`
	Username    string    `json:"username"`
	DisplayName string    `json:"display_name"`
	AvatarURL   string    `json:"avatar_url"`
	Since       time.Time `json:"since"` // When the friendship was accepted
}

// PendingRequest is an incoming friend request with sender profile details.
type PendingRequest struct {
	RequestID   uuid.UUID `json:"request_id"`
	FromUserID  uuid.UUID `json:"from_user_id"`
	Username    string    `json:"username"`
	DisplayName string    `json:"display_name"`
	AvatarURL   string    `json:"avatar_url"`
	CreatedAt   time.Time `json:"created_at"`
}

// FriendshipStatus is what the API returns for a status check.
type FriendshipStatus struct {
	Status     string     `json:"status"` // "none" | "pending_sent" | "pending_received" | "friends"
	RequestID  *uuid.UUID `json:"request_id,omitempty"`
	IsBlocked  bool       `json:"is_blocked"`  // Has either user blocked the other?
	HasBlocked bool       `json:"has_blocked"` // Has the current user blocked the other user?
}
