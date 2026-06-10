package community

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

// Repository handles all DB operations for communities.
type Repository struct {
	db *pgxpool.Pool
}

// NewRepository creates a new community repository.
func NewRepository(db *pgxpool.Pool) *Repository {
	return &Repository{db: db}
}

// ─── Community CRUD ───────────────────────────────────────────────────────────

func (r *Repository) Create(ctx context.Context, c *Community) error {
	return r.db.QueryRow(ctx, `
		INSERT INTO communities (name, slug, description, avatar_url, banner_url, invite_link, is_public, max_members, max_groups, created_by)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)
		RETURNING id, created_at, updated_at
	`, c.Name, c.Slug, c.Description, c.AvatarURL, c.BannerURL, c.InviteLink,
		c.IsPublic, c.MaxMembers, c.MaxGroups, c.CreatedBy,
	).Scan(&c.ID, &c.CreatedAt, &c.UpdatedAt)
}

func (r *Repository) GetByID(ctx context.Context, id uuid.UUID) (*Community, error) {
	return r.scanCommunity(r.db.QueryRow(ctx, `
		SELECT c.id, c.name, c.slug, c.description, c.avatar_url, c.banner_url,
		       c.invite_link, c.is_public, c.max_members, c.max_groups, c.created_by,
		       c.created_at, c.updated_at,
		       COUNT(DISTINCT m.user_id) AS member_count,
		       COUNT(DISTINCT cg.group_id) AS group_count
		FROM communities c
		LEFT JOIN community_members m  ON m.community_id = c.id
		LEFT JOIN community_groups  cg ON cg.community_id = c.id
		WHERE c.id = $1
		GROUP BY c.id
	`, id))
}

func (r *Repository) GetBySlug(ctx context.Context, slug string) (*Community, error) {
	return r.scanCommunity(r.db.QueryRow(ctx, `
		SELECT c.id, c.name, c.slug, c.description, c.avatar_url, c.banner_url,
		       c.invite_link, c.is_public, c.max_members, c.max_groups, c.created_by,
		       c.created_at, c.updated_at,
		       COUNT(DISTINCT m.user_id) AS member_count,
		       COUNT(DISTINCT cg.group_id) AS group_count
		FROM communities c
		LEFT JOIN community_members m  ON m.community_id = c.id
		LEFT JOIN community_groups  cg ON cg.community_id = c.id
		WHERE c.slug = $1
		GROUP BY c.id
	`, slug))
}

func (r *Repository) GetByInvite(ctx context.Context, token string) (*Community, error) {
	c := &Community{}
	err := r.db.QueryRow(ctx, `
		SELECT id, name, slug, description, avatar_url, banner_url, invite_link,
		       is_public, max_members, max_groups, created_by, created_at, updated_at
		FROM communities WHERE invite_link = $1
	`, token).Scan(
		&c.ID, &c.Name, &c.Slug, &c.Description, &c.AvatarURL, &c.BannerURL, &c.InviteLink,
		&c.IsPublic, &c.MaxMembers, &c.MaxGroups, &c.CreatedBy, &c.CreatedAt, &c.UpdatedAt,
	)
	return c, err
}

// ListPublic returns public communities ordered by member count (discovery feed).
func (r *Repository) ListPublic(ctx context.Context, limit, offset int) ([]*Community, error) {
	rows, err := r.db.Query(ctx, `
		SELECT c.id, c.name, c.slug, c.description, c.avatar_url, c.banner_url,
		       c.invite_link, c.is_public, c.max_members, c.max_groups, c.created_by,
		       c.created_at, c.updated_at,
		       COUNT(m.user_id) AS member_count, 0 AS group_count
		FROM communities c
		LEFT JOIN community_members m ON m.community_id = c.id
		WHERE c.is_public = TRUE
		GROUP BY c.id
		ORDER BY member_count DESC, c.created_at DESC
		LIMIT $1 OFFSET $2
	`, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	return scanCommunities(rows)
}

// ListForUser returns all communities the user belongs to.
func (r *Repository) ListForUser(ctx context.Context, userID uuid.UUID) ([]*Community, error) {
	rows, err := r.db.Query(ctx, `
		SELECT c.id, c.name, c.slug, c.description, c.avatar_url, c.banner_url,
		       c.invite_link, c.is_public, c.max_members, c.max_groups, c.created_by,
		       c.created_at, c.updated_at, 0 AS member_count, 0 AS group_count
		FROM communities c
		JOIN community_members m ON m.community_id = c.id
		WHERE m.user_id = $1
		ORDER BY c.updated_at DESC
	`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	return scanCommunities(rows)
}

func (r *Repository) SlugExists(ctx context.Context, slug string) (bool, error) {
	var count int
	err := r.db.QueryRow(ctx, `SELECT COUNT(*) FROM communities WHERE slug=$1`, slug).Scan(&count)
	return count > 0, err
}

func (r *Repository) MemberCount(ctx context.Context, id uuid.UUID) (int, error) {
	var n int
	err := r.db.QueryRow(ctx, `SELECT COUNT(*) FROM community_members WHERE community_id=$1`, id).Scan(&n)
	return n, err
}

// ─── Members ──────────────────────────────────────────────────────────────────

func (r *Repository) AddMember(ctx context.Context, communityID, userID uuid.UUID, role CommunityRole) error {
	_, err := r.db.Exec(ctx, `
		INSERT INTO community_members (community_id, user_id, role)
		VALUES ($1,$2,$3)
		ON CONFLICT (community_id, user_id) DO NOTHING
	`, communityID, userID, string(role))
	return err
}

func (r *Repository) RemoveMember(ctx context.Context, communityID, userID uuid.UUID) error {
	_, err := r.db.Exec(ctx,
		`DELETE FROM community_members WHERE community_id=$1 AND user_id=$2`, communityID, userID)
	return err
}

func (r *Repository) GetMember(ctx context.Context, communityID, userID uuid.UUID) (*CommunityMember, error) {
	m := &CommunityMember{}
	err := r.db.QueryRow(ctx, `
		SELECT community_id, user_id, role, joined_at
		FROM community_members WHERE community_id=$1 AND user_id=$2
	`, communityID, userID).Scan(&m.CommunityID, &m.UserID, &m.Role, &m.JoinedAt)
	if err != nil {
		return nil, err
	}
	return m, nil
}

func (r *Repository) IsMember(ctx context.Context, communityID, userID uuid.UUID) (bool, error) {
	var n int
	err := r.db.QueryRow(ctx, `
		SELECT COUNT(*) FROM community_members WHERE community_id=$1 AND user_id=$2
	`, communityID, userID).Scan(&n)
	return n > 0, err
}

func (r *Repository) UpdateMemberRole(ctx context.Context, communityID, userID uuid.UUID, role CommunityRole) error {
	_, err := r.db.Exec(ctx,
		`UPDATE community_members SET role=$3 WHERE community_id=$1 AND user_id=$2`,
		communityID, userID, string(role))
	return err
}

// ─── Community Groups ─────────────────────────────────────────────────────────

func (r *Repository) GroupCount(ctx context.Context, communityID uuid.UUID) (int, error) {
	var n int
	err := r.db.QueryRow(ctx, `SELECT COUNT(*) FROM community_groups WHERE community_id=$1`, communityID).Scan(&n)
	return n, err
}

func (r *Repository) LinkGroup(ctx context.Context, communityID, groupID uuid.UUID, position int) error {
	_, err := r.db.Exec(ctx, `
		INSERT INTO community_groups (community_id, group_id, position)
		VALUES ($1,$2,$3)
		ON CONFLICT (community_id, group_id) DO UPDATE SET position=$3
	`, communityID, groupID, position)
	return err
}

func (r *Repository) UnlinkGroup(ctx context.Context, communityID, groupID uuid.UUID) error {
	_, err := r.db.Exec(ctx,
		`DELETE FROM community_groups WHERE community_id=$1 AND group_id=$2`, communityID, groupID)
	return err
}

func (r *Repository) ListLinkedGroups(ctx context.Context, communityID uuid.UUID) ([]*CommunityGroup, error) {
	rows, err := r.db.Query(ctx, `
		SELECT cg.community_id, cg.group_id, cg.position, cg.linked_at, g.name, g.invite_link
		FROM community_groups cg
		JOIN groups g ON g.id = cg.group_id
		WHERE cg.community_id = $1
		ORDER BY cg.position ASC
	`, communityID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []*CommunityGroup
	for rows.Next() {
		cg := &CommunityGroup{}
		if err := rows.Scan(&cg.CommunityID, &cg.GroupID, &cg.Position, &cg.LinkedAt, &cg.GroupName, &cg.InviteLink); err != nil {
			return nil, err
		}
		list = append(list, cg)
	}
	return list, rows.Err()
}

// ─── Posts ────────────────────────────────────────────────────────────────────

func (r *Repository) CreatePost(ctx context.Context, p *Post) error {
	return r.db.QueryRow(ctx, `
		INSERT INTO community_posts (community_id, author_id, title, body, media_urls, is_pinned, expires_at)
		VALUES ($1,$2,$3,$4,$5,$6,$7)
		RETURNING id, created_at, updated_at
	`, p.CommunityID, p.AuthorID, p.Title, p.Body, p.MediaURLs, p.IsPinned, p.ExpiresAt,
	).Scan(&p.ID, &p.CreatedAt, &p.UpdatedAt)
}

func (r *Repository) GetPost(ctx context.Context, postID uuid.UUID) (*Post, error) {
	p := &Post{}
	err := r.db.QueryRow(ctx, `
		SELECT p.id, p.community_id, p.author_id, p.title, p.body, p.media_urls,
		       p.like_count, p.reply_count, p.is_pinned, p.expires_at, p.created_at, p.updated_at,
		       u.username, u.display_name, u.avatar_url
		FROM community_posts p
		JOIN users u ON u.id = p.author_id
		WHERE p.id = $1
	`, postID).Scan(
		&p.ID, &p.CommunityID, &p.AuthorID, &p.Title, &p.Body, &p.MediaURLs,
		&p.LikeCount, &p.ReplyCount, &p.IsPinned, &p.ExpiresAt, &p.CreatedAt, &p.UpdatedAt,
		&p.AuthorUsername, &p.AuthorDisplayName, &p.AuthorAvatarURL,
	)
	return p, err
}

func (r *Repository) ListPosts(ctx context.Context, communityID uuid.UUID, callerID uuid.UUID, limit int, before time.Time) ([]*Post, error) {
	var args []interface{}
	var q string

	base := `
		SELECT p.id, p.community_id, p.author_id, p.title, p.body, p.media_urls,
		       p.like_count, p.reply_count, p.is_pinned, p.expires_at, p.created_at, p.updated_at,
		       u.username, u.display_name, u.avatar_url,
		       EXISTS(SELECT 1 FROM community_post_likes l WHERE l.post_id=p.id AND l.user_id=$2) AS liked_by_me
		FROM community_posts p
		JOIN users u ON u.id = p.author_id
		WHERE p.community_id = $1
		  AND (p.expires_at IS NULL OR p.expires_at > NOW())
	`

	if before.IsZero() {
		q = base + `ORDER BY p.is_pinned DESC, p.created_at DESC LIMIT $3`
		args = []interface{}{communityID, callerID, limit}
	} else {
		q = base + `AND p.created_at < $3 ORDER BY p.is_pinned DESC, p.created_at DESC LIMIT $4`
		args = []interface{}{communityID, callerID, before, limit}
	}

	rows, err := r.db.Query(ctx, q, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var posts []*Post
	for rows.Next() {
		p := &Post{}
		if err := rows.Scan(
			&p.ID, &p.CommunityID, &p.AuthorID, &p.Title, &p.Body, &p.MediaURLs,
			&p.LikeCount, &p.ReplyCount, &p.IsPinned, &p.ExpiresAt, &p.CreatedAt, &p.UpdatedAt,
			&p.AuthorUsername, &p.AuthorDisplayName, &p.AuthorAvatarURL, &p.LikedByMe,
		); err != nil {
			return nil, err
		}
		posts = append(posts, p)
	}
	return posts, rows.Err()
}

func (r *Repository) DeletePost(ctx context.Context, postID uuid.UUID) error {
	_, err := r.db.Exec(ctx, `DELETE FROM community_posts WHERE id=$1`, postID)
	return err
}

func (r *Repository) PinPost(ctx context.Context, postID uuid.UUID, pin bool) error {
	_, err := r.db.Exec(ctx, `UPDATE community_posts SET is_pinned=$2 WHERE id=$1`, postID, pin)
	return err
}

// ─── Likes ────────────────────────────────────────────────────────────────────

func (r *Repository) LikePost(ctx context.Context, postID, userID uuid.UUID) error {
	_, err := r.db.Exec(ctx, `
		INSERT INTO community_post_likes (post_id, user_id)
		VALUES ($1,$2) ON CONFLICT DO NOTHING
	`, postID, userID)
	if err != nil {
		return err
	}
	_, err = r.db.Exec(ctx,
		`UPDATE community_posts SET like_count = like_count+1 WHERE id=$1`, postID)
	return err
}

func (r *Repository) UnlikePost(ctx context.Context, postID, userID uuid.UUID) error {
	ct, err := r.db.Exec(ctx,
		`DELETE FROM community_post_likes WHERE post_id=$1 AND user_id=$2`, postID, userID)
	if err != nil {
		return err
	}
	if ct.RowsAffected() > 0 {
		_, err = r.db.Exec(ctx,
			`UPDATE community_posts SET like_count = GREATEST(like_count-1,0) WHERE id=$1`, postID)
	}
	return err
}

// ─── helpers ─────────────────────────────────────────────────────────────────

type scannable interface {
	Scan(dest ...interface{}) error
}

func (r *Repository) scanCommunity(row scannable) (*Community, error) {
	c := &Community{}
	err := row.Scan(
		&c.ID, &c.Name, &c.Slug, &c.Description, &c.AvatarURL, &c.BannerURL, &c.InviteLink,
		&c.IsPublic, &c.MaxMembers, &c.MaxGroups, &c.CreatedBy, &c.CreatedAt, &c.UpdatedAt,
		&c.MemberCount, &c.GroupCount,
	)
	return c, err
}

func scanCommunities(rows interface{ Next() bool; Scan(...interface{}) error; Err() error }) ([]*Community, error) {
	var list []*Community
	for rows.Next() {
		c := &Community{}
		if err := rows.Scan(
			&c.ID, &c.Name, &c.Slug, &c.Description, &c.AvatarURL, &c.BannerURL, &c.InviteLink,
			&c.IsPublic, &c.MaxMembers, &c.MaxGroups, &c.CreatedBy, &c.CreatedAt, &c.UpdatedAt,
			&c.MemberCount, &c.GroupCount,
		); err != nil {
			return nil, err
		}
		list = append(list, c)
	}
	return list, rows.Err()
}
