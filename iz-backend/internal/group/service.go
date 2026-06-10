package group

import (
	"context"
	"crypto/rand"
	"encoding/base32"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/rs/zerolog"
)

var (
	ErrGroupFull        = errors.New("group has reached its member limit")
	ErrNotMember        = errors.New("user is not a member of this group")
	ErrPermissionDenied = errors.New("insufficient group permissions")
	ErrGroupNotFound    = errors.New("group not found")
)

// Broadcaster is the interface the Hub must satisfy for group message fanout.
// This avoids an import cycle between group ↔ messaging.
type Broadcaster interface {
	Deliver(recipientID uuid.UUID, data []byte) bool
}

// Service provides group business logic.
type Service struct {
	repo        *Repository
	broadcaster Broadcaster
	log         zerolog.Logger
}

// NewService creates a new group Service.
func NewService(repo *Repository, broadcaster Broadcaster, log zerolog.Logger) *Service {
	return &Service{
		repo:        repo,
		broadcaster: broadcaster,
		log:         log.With().Str("svc", "group").Logger(),
	}
}

// ─── Group lifecycle ──────────────────────────────────────────────────────────

// CreateGroup creates a group with the caller as owner.
func (s *Service) CreateGroup(ctx context.Context, creatorID uuid.UUID, name, description string, isPrivate bool) (*Group, error) {
	if len(name) < 2 || len(name) > 128 {
		return nil, fmt.Errorf("group name must be 2-128 characters")
	}

	inviteToken, err := generateToken(10)
	if err != nil {
		return nil, fmt.Errorf("generate invite token: %w", err)
	}

	g := &Group{
		Name:        name,
		Description: description,
		InviteLink:  inviteToken,
		IsPrivate:   isPrivate,
		MaxMembers:  5000,
		CreatedBy:   creatorID,
	}

	if err := s.repo.CreateGroup(ctx, g); err != nil {
		return nil, fmt.Errorf("create group: %w", err)
	}

	// Creator becomes owner
	if err := s.repo.AddMember(ctx, g.ID, creatorID, RoleOwner); err != nil {
		return nil, fmt.Errorf("add owner: %w", err)
	}

	s.log.Info().Str("group_id", g.ID.String()).Str("creator", creatorID.String()).Msg("group created")
	return g, nil
}

// GetGroup returns a group the user is a member of.
func (s *Service) GetGroup(ctx context.Context, userID, groupID uuid.UUID) (*Group, error) {
	ok, err := s.repo.IsMember(ctx, groupID, userID)
	if err != nil {
		return nil, err
	}
	if !ok {
		return nil, ErrNotMember
	}
	return s.repo.GetGroup(ctx, groupID)
}

// ListUserGroups returns all groups the user belongs to.
func (s *Service) ListUserGroups(ctx context.Context, userID uuid.UUID) ([]*Group, error) {
	return s.repo.ListUserGroups(ctx, userID)
}

// JoinByInvite lets a user join a group via its invite token.
func (s *Service) JoinByInvite(ctx context.Context, userID uuid.UUID, token string) (*Group, error) {
	g, err := s.repo.GetGroupByInvite(ctx, token)
	if err != nil {
		return nil, ErrGroupNotFound
	}

	count, err := s.repo.MemberCount(ctx, g.ID)
	if err != nil {
		return nil, err
	}
	if count >= g.MaxMembers {
		return nil, ErrGroupFull
	}

	if err := s.repo.AddMember(ctx, g.ID, userID, RoleMember); err != nil {
		return nil, fmt.Errorf("join group: %w", err)
	}

	s.log.Info().Str("group_id", g.ID.String()).Str("user_id", userID.String()).Msg("user joined group")
	return g, nil
}

// LeaveGroup removes a user from a group. Owners must transfer ownership first.
func (s *Service) LeaveGroup(ctx context.Context, userID, groupID uuid.UUID) error {
	m, err := s.repo.GetMember(ctx, groupID, userID)
	if err != nil {
		return ErrNotMember
	}
	if m.Role == RoleOwner {
		return fmt.Errorf("owner must transfer ownership before leaving")
	}
	return s.repo.RemoveMember(ctx, groupID, userID)
}

// KickMember lets an admin/owner remove another member.
func (s *Service) KickMember(ctx context.Context, actorID, targetID, groupID uuid.UUID) error {
	actor, err := s.repo.GetMember(ctx, groupID, actorID)
	if err != nil {
		return ErrNotMember
	}
	target, err := s.repo.GetMember(ctx, groupID, targetID)
	if err != nil {
		return ErrNotMember
	}

	// Owners can kick anyone; admins can only kick regular members
	if actor.Role == RoleMember ||
		(actor.Role == RoleAdmin && target.Role != RoleMember) {
		return ErrPermissionDenied
	}

	return s.repo.RemoveMember(ctx, groupID, targetID)
}

// PromoteMember changes a member's role.
func (s *Service) PromoteMember(ctx context.Context, actorID, targetID, groupID uuid.UUID, newRole Role) error {
	actor, err := s.repo.GetMember(ctx, groupID, actorID)
	if err != nil {
		return ErrNotMember
	}
	if actor.Role != RoleOwner {
		return ErrPermissionDenied
	}
	return s.repo.UpdateMemberRole(ctx, groupID, targetID, newRole)
}

// ListMembers returns all members of a group.
func (s *Service) ListMembers(ctx context.Context, userID, groupID uuid.UUID) ([]*Member, error) {
	ok, err := s.repo.IsMember(ctx, groupID, userID)
	if err != nil {
		return nil, err
	}
	if !ok {
		return nil, ErrNotMember
	}
	return s.repo.ListMembers(ctx, groupID)
}

// ─── Group Messaging ──────────────────────────────────────────────────────────

// SendGroupMessage persists and fans out an encrypted group message.
func (s *Service) SendGroupMessage(ctx context.Context, senderID uuid.UUID, p *GroupMessagePayload) (*GroupMessage, error) {
	groupID, err := uuid.Parse(p.GroupID)
	if err != nil {
		return nil, fmt.Errorf("invalid group_id")
	}

	// Verify sender is a member
	ok, err := s.repo.IsMember(ctx, groupID, senderID)
	if err != nil {
		return nil, err
	}
	if !ok {
		return nil, ErrNotMember
	}

	var expiresAt *time.Time
	if p.ExpiresIn > 0 {
		t := time.Now().Add(time.Duration(p.ExpiresIn) * time.Second)
		expiresAt = &t
	}

	msgType := p.MsgType
	if msgType == "" {
		msgType = "text"
	}

	msg := &GroupMessage{
		GroupID:        groupID,
		SenderID:       senderID,
		Ciphertext:     p.Ciphertext,
		MsgType:        msgType,
		Iteration:      p.Iteration,
		DistributionID: p.DistributionID,
		ExpiresAt:      expiresAt,
	}

	if err := s.repo.SaveGroupMessage(ctx, msg); err != nil {
		return nil, fmt.Errorf("save group message: %w", err)
	}

	// Fan out to all online members
	memberIDs, err := s.repo.MemberIDs(ctx, groupID)
	if err != nil {
		s.log.Error().Err(err).Str("group_id", groupID.String()).Msg("failed to fetch member IDs for fanout")
		return msg, nil
	}

	payload := buildGroupMessageJSON(msg)
	for _, memberID := range memberIDs {
		if memberID == senderID {
			continue // don't echo to sender
		}
		s.broadcaster.Deliver(memberID, payload)
	}

	s.log.Info().
		Str("msg_id", msg.ID.String()).
		Str("group_id", groupID.String()).
		Str("sender", senderID.String()).
		Int("fanout", len(memberIDs)-1).
		Msg("group message sent")

	return msg, nil
}

// GroupHistory returns paginated message history for a group.
func (s *Service) GroupHistory(ctx context.Context, userID, groupID uuid.UUID, limit int, before time.Time) ([]*GroupMessage, error) {
	ok, err := s.repo.IsMember(ctx, groupID, userID)
	if err != nil {
		return nil, err
	}
	if !ok {
		return nil, ErrNotMember
	}
	return s.repo.GroupHistory(ctx, groupID, limit, before)
}

// ─── helpers ─────────────────────────────────────────────────────────────────

func generateToken(length int) (string, error) {
	b := make([]byte, length)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	return base32.StdEncoding.WithPadding(base32.NoPadding).EncodeToString(b)[:length], nil
}

// SendGroupMessageRaw implements the messaging.GroupSvc interface.
// It deserialises the raw JSON payload from the WebSocket and delegates to SendGroupMessage.
func (s *Service) SendGroupMessageRaw(ctx context.Context, senderID uuid.UUID, raw []byte) (string, error) {
	var p GroupMessagePayload
	if err := json.Unmarshal(raw, &p); err != nil {
		return "", fmt.Errorf("invalid group message payload: %w", err)
	}
	msg, err := s.SendGroupMessage(ctx, senderID, &p)
	if err != nil {
		return "", err
	}
	return msg.ID.String(), nil
}
