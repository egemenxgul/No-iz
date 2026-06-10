package community

import (
	"time"

	"github.com/google/uuid"
)

// CommunityRole is the role a user holds within a community.
type CommunityRole string

const (
	RoleOwner     CommunityRole = "owner"
	RoleAdmin     CommunityRole = "admin"
	RoleModerator CommunityRole = "moderator"
	RoleMember    CommunityRole = "member"
)

// MaxGroups is the hard limit on sub-groups per community.
const MaxGroups = 15

// Community represents an iz Community (up to 500k members).
type Community struct {
	ID          uuid.UUID `json:"id"`
	Name        string    `json:"name"`
	Slug        string    `json:"slug"`
	Description string    `json:"description"`
	AvatarURL   string    `json:"avatar_url"`
	BannerURL   string    `json:"banner_url"`
	InviteLink  string    `json:"invite_link,omitempty"`
	IsPublic    bool      `json:"is_public"`
	MaxMembers  int       `json:"max_members"`
	MaxGroups   int       `json:"max_groups"`
	CreatedBy   uuid.UUID `json:"created_by"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`

	// Populated on demand
	MemberCount int `json:"member_count,omitempty"`
	GroupCount  int `json:"group_count,omitempty"`
}

// CommunityMember is a user's membership record in a community.
type CommunityMember struct {
	CommunityID uuid.UUID     `json:"community_id"`
	UserID      uuid.UUID     `json:"user_id"`
	Role        CommunityRole `json:"role"`
	JoinedAt    time.Time     `json:"joined_at"`

	// Populated on demand
	Username    string `json:"username,omitempty"`
	DisplayName string `json:"display_name,omitempty"`
	AvatarURL   string `json:"avatar_url,omitempty"`
}

// CommunityGroup links a group to a community.
type CommunityGroup struct {
	CommunityID uuid.UUID `json:"community_id"`
	GroupID     uuid.UUID `json:"group_id"`
	Position    int       `json:"position"`
	LinkedAt    time.Time `json:"linked_at"`

	// Populated on demand
	GroupName string `json:"group_name,omitempty"`
}

// Post is a public post in a community's feed.
type Post struct {
	ID          uuid.UUID  `json:"id"`
	CommunityID uuid.UUID  `json:"community_id"`
	AuthorID    uuid.UUID  `json:"author_id"`
	Title       string     `json:"title"`
	Body        string     `json:"body"`
	MediaURLs   []string   `json:"media_urls"`
	LikeCount   int        `json:"like_count"`
	ReplyCount  int        `json:"reply_count"`
	IsPinned    bool       `json:"is_pinned"`
	ExpiresAt   *time.Time `json:"expires_at,omitempty"`
	CreatedAt   time.Time  `json:"created_at"`
	UpdatedAt   time.Time  `json:"updated_at"`

	// Populated on demand
	AuthorUsername    string `json:"author_username,omitempty"`
	AuthorDisplayName string `json:"author_display_name,omitempty"`
	AuthorAvatarURL   string `json:"author_avatar_url,omitempty"`
	LikedByMe         bool   `json:"liked_by_me,omitempty"`
}
