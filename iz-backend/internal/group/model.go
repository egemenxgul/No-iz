package group

import (
	"time"

	"github.com/google/uuid"
)

// Role represents a member's role within a group.
type Role string

const (
	RoleOwner  Role = "owner"
	RoleAdmin  Role = "admin"
	RoleMember Role = "member"
)

// Group represents an iz group (max 5 000 members).
type Group struct {
	ID          uuid.UUID `json:"id"`
	Name        string    `json:"name"`
	Description string    `json:"description"`
	AvatarURL   string    `json:"avatar_url"`
	InviteLink  string    `json:"invite_link,omitempty"`
	IsPrivate   bool      `json:"is_private"`
	MaxMembers  int       `json:"max_members"`
	CreatedBy   uuid.UUID `json:"created_by"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`

	// Populated on demand
	MemberCount int `json:"member_count,omitempty"`
}

// Member represents one user's membership in a group.
type Member struct {
	GroupID  uuid.UUID `json:"group_id"`
	UserID   uuid.UUID `json:"user_id"`
	Role     Role      `json:"role"`
	JoinedAt time.Time `json:"joined_at"`

	// Populated on demand
	Username    string `json:"username,omitempty"`
	DisplayName string `json:"display_name,omitempty"`
	AvatarURL   string `json:"avatar_url,omitempty"`
}

// GroupMessage is a Sender-Key-encrypted message stored in a group.
type GroupMessage struct {
	ID             uuid.UUID  `json:"id"`
	GroupID        uuid.UUID  `json:"group_id"`
	SenderID       uuid.UUID  `json:"sender_id"`
	Ciphertext     string     `json:"ciphertext"`
	MsgType        string     `json:"msg_type"`
	Iteration      int        `json:"iteration"`
	DistributionID string     `json:"distribution_id"`
	ExpiresAt      *time.Time `json:"expires_at,omitempty"`
	IsPinned       bool       `json:"is_pinned"`
	CreatedAt      time.Time  `json:"created_at"`
}

// ─── WebSocket events ─────────────────────────────────────────────────────────

// GroupMessagePayload is the WS payload for outgoing group messages.
type GroupMessagePayload struct {
	GroupID        string `json:"group_id"`
	Ciphertext     string `json:"ciphertext"`
	MsgType        string `json:"msg_type"`
	Iteration      int    `json:"iteration"`
	DistributionID string `json:"distribution_id"`
	ExpiresIn      int    `json:"expires_in"` // seconds; 0 = no expiry
}

// NewGroupMessagePayload is pushed to all online group members.
type NewGroupMessagePayload struct {
	MessageID      string     `json:"message_id"`
	GroupID        string     `json:"group_id"`
	SenderID       string     `json:"sender_id"`
	Ciphertext     string     `json:"ciphertext"`
	MsgType        string     `json:"msg_type"`
	Iteration      int        `json:"iteration"`
	DistributionID string     `json:"distribution_id"`
	ExpiresAt      *time.Time `json:"expires_at,omitempty"`
	IsPinned       bool       `json:"is_pinned"`
	CreatedAt      time.Time  `json:"created_at"`
}
