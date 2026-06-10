package group

import (
	"encoding/json"
	"time"

	"github.com/google/uuid"
)

// buildGroupMessageJSON constructs the WS envelope JSON for a group message push.
func buildGroupMessageJSON(m *GroupMessage) []byte {
	type envelope struct {
		Type    string                 `json:"type"`
		Payload NewGroupMessagePayload `json:"payload"`
	}
	env := envelope{
		Type: "new_group_message",
		Payload: NewGroupMessagePayload{
			MessageID:      m.ID.String(),
			GroupID:        m.GroupID.String(),
			SenderID:       m.SenderID.String(),
			Ciphertext:     m.Ciphertext,
			MsgType:        m.MsgType,
			Iteration:      m.Iteration,
			DistributionID: m.DistributionID,
			ExpiresAt:      m.ExpiresAt,
			CreatedAt:      m.CreatedAt,
		},
	}
	data, _ := json.Marshal(env)
	return data
}

// ─── unused but exported for possible future use ─────────────────────────────

// MakeGroupInviteURL constructs a shareable invite URL.
func MakeGroupInviteURL(baseURL, token string) string {
	return baseURL + "/invite/" + token
}

// IsExpired reports whether the message has expired.
func (m *GroupMessage) IsExpired() bool {
	return m.ExpiresAt != nil && m.ExpiresAt.Before(time.Now())
}

// CanAdmin returns true if the role has admin-level privileges.
func CanAdmin(r Role) bool {
	return r == RoleOwner || r == RoleAdmin
}

// NewMember constructs a Member for the given user.
func NewMember(groupID, userID uuid.UUID, role Role) *Member {
	return &Member{
		GroupID:  groupID,
		UserID:   userID,
		Role:     role,
		JoinedAt: time.Now(),
	}
}
