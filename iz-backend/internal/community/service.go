package community

import (
	"context"
	"crypto/rand"
	"encoding/base32"
	"errors"
	"fmt"
	"regexp"
	"strings"
	"time"
	"unicode"

	"github.com/google/uuid"
	"github.com/rs/zerolog"
)

var (
	ErrCommunityFull    = errors.New("community has reached its member limit")
	ErrNotMember        = errors.New("user is not a member of this community")
	ErrPermissionDenied = errors.New("insufficient community permissions")
	ErrCommunityNotFound = errors.New("community not found")
	ErrSlugTaken        = errors.New("community slug is already taken")
	ErrTooManyGroups    = errors.New("community has reached the maximum number of linked groups (15)")
	ErrPostNotFound     = errors.New("post not found")
)

var slugRe = regexp.MustCompile(`^[a-z0-9][a-z0-9_-]{1,62}[a-z0-9]$`)

// Service provides community business logic.
type Service struct {
	repo *Repository
	log  zerolog.Logger
}

// NewService creates a new community Service.
func NewService(repo *Repository, log zerolog.Logger) *Service {
	return &Service{
		repo: repo,
		log:  log.With().Str("svc", "community").Logger(),
	}
}

// ─── Community lifecycle ──────────────────────────────────────────────────────

// Create creates a new community. Anyone can call this.
func (s *Service) Create(ctx context.Context, creatorID uuid.UUID, name, slug, description string, isPublic bool) (*Community, error) {
	if len(name) < 2 || len(name) > 128 {
		return nil, fmt.Errorf("name must be 2-128 characters")
	}

	// Auto-generate slug if empty
	if slug == "" {
		slug = slugify(name)
	}
	slug = strings.ToLower(slug)

	if !slugRe.MatchString(slug) {
		return nil, fmt.Errorf("slug must be 3-64 lowercase letters, numbers, hyphens or underscores")
	}

	exists, err := s.repo.SlugExists(ctx, slug)
	if err != nil {
		return nil, err
	}
	if exists {
		return nil, ErrSlugTaken
	}

	token, err := generateToken(12)
	if err != nil {
		return nil, err
	}

	c := &Community{
		Name:        name,
		Slug:        slug,
		Description: description,
		IsPublic:    isPublic,
		InviteLink:  token,
		MaxMembers:  500_000,
		MaxGroups:   MaxGroups,
		CreatedBy:   creatorID,
	}

	if err := s.repo.Create(ctx, c); err != nil {
		return nil, fmt.Errorf("create community: %w", err)
	}

	// Creator becomes owner
	if err := s.repo.AddMember(ctx, c.ID, creatorID, RoleOwner); err != nil {
		return nil, fmt.Errorf("add owner: %w", err)
	}

	s.log.Info().Str("id", c.ID.String()).Str("slug", slug).Msg("community created")
	return c, nil
}

func (s *Service) GetBySlug(ctx context.Context, slug string) (*Community, error) {
	c, err := s.repo.GetBySlug(ctx, slug)
	if err != nil {
		return nil, ErrCommunityNotFound
	}
	return c, nil
}

func (s *Service) GetByID(ctx context.Context, id uuid.UUID) (*Community, error) {
	c, err := s.repo.GetByID(ctx, id)
	if err != nil {
		return nil, ErrCommunityNotFound
	}
	return c, nil
}

// Discover returns paginated public communities.
func (s *Service) Discover(ctx context.Context, limit, offset int) ([]*Community, error) {
	if limit <= 0 || limit > 100 {
		limit = 30
	}
	return s.repo.ListPublic(ctx, limit, offset)
}

// MyCommitments returns all communities the user belongs to.
func (s *Service) MyCommunities(ctx context.Context, userID uuid.UUID) ([]*Community, error) {
	return s.repo.ListForUser(ctx, userID)
}

// ─── Membership ───────────────────────────────────────────────────────────────

// Join adds a user to a community (public join or via invite token).
func (s *Service) Join(ctx context.Context, userID uuid.UUID, communityID uuid.UUID) (*Community, error) {
	c, err := s.repo.GetByID(ctx, communityID)
	if err != nil {
		return nil, ErrCommunityNotFound
	}
	if !c.IsPublic {
		return nil, ErrPermissionDenied
	}
	return s.joinInternal(ctx, userID, c)
}

// JoinByInvite joins via an invite token (works for both public and private communities).
func (s *Service) JoinByInvite(ctx context.Context, userID uuid.UUID, token string) (*Community, error) {
	c, err := s.repo.GetByInvite(ctx, token)
	if err != nil {
		return nil, ErrCommunityNotFound
	}
	return s.joinInternal(ctx, userID, c)
}

func (s *Service) joinInternal(ctx context.Context, userID uuid.UUID, c *Community) (*Community, error) {
	count, err := s.repo.MemberCount(ctx, c.ID)
	if err != nil {
		return nil, err
	}
	if count >= c.MaxMembers {
		return nil, ErrCommunityFull
	}
	if err := s.repo.AddMember(ctx, c.ID, userID, RoleMember); err != nil {
		return nil, err
	}
	return c, nil
}

// Leave removes a user from a community.
func (s *Service) Leave(ctx context.Context, userID, communityID uuid.UUID) error {
	m, err := s.repo.GetMember(ctx, communityID, userID)
	if err != nil {
		return ErrNotMember
	}
	if m.Role == RoleOwner {
		return fmt.Errorf("owner must transfer ownership before leaving")
	}
	return s.repo.RemoveMember(ctx, communityID, userID)
}

// KickMember removes a member (requires admin/owner).
func (s *Service) KickMember(ctx context.Context, actorID, targetID, communityID uuid.UUID) error {
	actor, err := s.repo.GetMember(ctx, communityID, actorID)
	if err != nil {
		return ErrNotMember
	}
	target, err := s.repo.GetMember(ctx, communityID, targetID)
	if err != nil {
		return ErrNotMember
	}
	if !canManage(actor.Role, target.Role) {
		return ErrPermissionDenied
	}
	return s.repo.RemoveMember(ctx, communityID, targetID)
}

// UpdateRole changes a member's role (owner only).
func (s *Service) UpdateRole(ctx context.Context, actorID, targetID, communityID uuid.UUID, newRole CommunityRole) error {
	actor, err := s.repo.GetMember(ctx, communityID, actorID)
	if err != nil {
		return ErrNotMember
	}
	if actor.Role != RoleOwner {
		return ErrPermissionDenied
	}
	return s.repo.UpdateMemberRole(ctx, communityID, targetID, newRole)
}

// ─── Group links ──────────────────────────────────────────────────────────────

// LinkGroup attaches a group to a community (admin+).
func (s *Service) LinkGroup(ctx context.Context, actorID, communityID, groupID uuid.UUID, position int) error {
	actor, err := s.repo.GetMember(ctx, communityID, actorID)
	if err != nil {
		return ErrNotMember
	}
	if !canModerate(actor.Role) {
		return ErrPermissionDenied
	}

	count, err := s.repo.GroupCount(ctx, communityID)
	if err != nil {
		return err
	}
	if count >= MaxGroups {
		return ErrTooManyGroups
	}
	return s.repo.LinkGroup(ctx, communityID, groupID, position)
}

// UnlinkGroup detaches a group from a community (admin+).
func (s *Service) UnlinkGroup(ctx context.Context, actorID, communityID, groupID uuid.UUID) error {
	actor, err := s.repo.GetMember(ctx, communityID, actorID)
	if err != nil {
		return ErrNotMember
	}
	if !canModerate(actor.Role) {
		return ErrPermissionDenied
	}
	return s.repo.UnlinkGroup(ctx, communityID, groupID)
}

// ListGroups returns the groups linked to a community.
func (s *Service) ListGroups(ctx context.Context, communityID uuid.UUID) ([]*CommunityGroup, error) {
	return s.repo.ListLinkedGroups(ctx, communityID)
}

// ─── Posts ────────────────────────────────────────────────────────────────────

// CreatePost publishes a post to the community feed.
func (s *Service) CreatePost(ctx context.Context, authorID, communityID uuid.UUID, title, body string, mediaURLs []string, expiresIn int) (*Post, error) {
	ok, err := s.repo.IsMember(ctx, communityID, authorID)
	if err != nil {
		return nil, err
	}
	if !ok {
		return nil, ErrNotMember
	}

	if len(title) < 1 || len(title) > 256 {
		return nil, fmt.Errorf("title must be 1-256 characters")
	}

	var expiresAt *time.Time
	if expiresIn > 0 {
		t := time.Now().Add(time.Duration(expiresIn) * time.Second)
		expiresAt = &t
	}

	if mediaURLs == nil {
		mediaURLs = []string{}
	}

	p := &Post{
		CommunityID: communityID,
		AuthorID:    authorID,
		Title:       title,
		Body:        body,
		MediaURLs:   mediaURLs,
		ExpiresAt:   expiresAt,
	}
	if err := s.repo.CreatePost(ctx, p); err != nil {
		return nil, fmt.Errorf("create post: %w", err)
	}
	return p, nil
}

// ListPosts returns cursor-paginated posts for a community.
func (s *Service) ListPosts(ctx context.Context, callerID, communityID uuid.UUID, limit int, before time.Time) ([]*Post, error) {
	if limit <= 0 || limit > 100 {
		limit = 30
	}
	return s.repo.ListPosts(ctx, communityID, callerID, limit, before)
}

// DeletePost deletes a post (author, moderator, admin, or owner).
func (s *Service) DeletePost(ctx context.Context, actorID uuid.UUID, postID uuid.UUID) error {
	post, err := s.repo.GetPost(ctx, postID)
	if err != nil {
		return ErrPostNotFound
	}

	if post.AuthorID != actorID {
		// Check if actor is at least moderator in the community
		m, err := s.repo.GetMember(ctx, post.CommunityID, actorID)
		if err != nil || !canModerate(m.Role) {
			return ErrPermissionDenied
		}
	}
	return s.repo.DeletePost(ctx, postID)
}

// PinPost pins or unpins a post (admin+).
func (s *Service) PinPost(ctx context.Context, actorID, communityID, postID uuid.UUID, pin bool) error {
	actor, err := s.repo.GetMember(ctx, communityID, actorID)
	if err != nil {
		return ErrNotMember
	}
	if !canModerate(actor.Role) {
		return ErrPermissionDenied
	}
	return s.repo.PinPost(ctx, postID, pin)
}

// LikePost toggles a like on a post.
func (s *Service) LikePost(ctx context.Context, userID, postID uuid.UUID) error {
	return s.repo.LikePost(ctx, postID, userID)
}

// UnlikePost removes a like from a post.
func (s *Service) UnlikePost(ctx context.Context, userID, postID uuid.UUID) error {
	return s.repo.UnlikePost(ctx, postID, userID)
}

// ─── helpers ─────────────────────────────────────────────────────────────────

func canModerate(r CommunityRole) bool {
	return r == RoleOwner || r == RoleAdmin || r == RoleModerator
}

func canManage(actor, target CommunityRole) bool {
	if actor == RoleOwner {
		return true
	}
	if actor == RoleAdmin && target == RoleMember {
		return true
	}
	return false
}

func generateToken(length int) (string, error) {
	b := make([]byte, length)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	return base32.StdEncoding.WithPadding(base32.NoPadding).EncodeToString(b)[:length], nil
}

// slugify converts a name to a URL-friendly slug.
func slugify(name string) string {
	var sb strings.Builder
	for _, r := range strings.ToLower(name) {
		if unicode.IsLetter(r) || unicode.IsDigit(r) {
			sb.WriteRune(r)
		} else if sb.Len() > 0 {
			sb.WriteByte('-')
		}
	}
	s := strings.TrimRight(sb.String(), "-")
	if len(s) > 62 {
		s = s[:62]
	}
	if len(s) < 3 {
		b, _ := generateToken(6)
		s = s + "-" + strings.ToLower(b)
	}
	return s
}
