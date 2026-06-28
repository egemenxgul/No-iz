package group

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// Repository handles all database operations for groups.
type Repository struct {
	db *pgxpool.Pool
}

// NewRepository creates a new group repository.
func NewRepository(db *pgxpool.Pool) *Repository {
	return &Repository{db: db}
}

// ─── Group CRUD ───────────────────────────────────────────────────────────────

func (r *Repository) CreateGroup(ctx context.Context, g *Group) error {
	return r.db.QueryRow(ctx, `
		INSERT INTO groups (name, description, avatar_url, invite_link, is_private, max_members, created_by)
		VALUES ($1,$2,$3,$4,$5,$6,$7)
		RETURNING id, created_at, updated_at
	`, g.Name, g.Description, g.AvatarURL, g.InviteLink, g.IsPrivate, g.MaxMembers, g.CreatedBy,
	).Scan(&g.ID, &g.CreatedAt, &g.UpdatedAt)
}

func (r *Repository) GetGroup(ctx context.Context, groupID uuid.UUID) (*Group, error) {
	g := &Group{}
	err := r.db.QueryRow(ctx, `
		SELECT g.id, g.name, g.description, g.avatar_url, g.invite_link,
		       g.is_private, g.max_members, g.created_by, g.created_at, g.updated_at,
		       COUNT(m.user_id) AS member_count
		FROM groups g
		LEFT JOIN group_members m ON m.group_id = g.id
		WHERE g.id = $1
		GROUP BY g.id
	`, groupID).Scan(
		&g.ID, &g.Name, &g.Description, &g.AvatarURL, &g.InviteLink,
		&g.IsPrivate, &g.MaxMembers, &g.CreatedBy, &g.CreatedAt, &g.UpdatedAt,
		&g.MemberCount,
	)
	if err != nil {
		return nil, err
	}
	return g, nil
}

func (r *Repository) GetGroupByInvite(ctx context.Context, token string) (*Group, error) {
	g := &Group{}
	err := r.db.QueryRow(ctx, `
		SELECT id, name, description, avatar_url, invite_link,
		       is_private, max_members, created_by, created_at, updated_at
		FROM groups WHERE invite_link = $1
	`, token).Scan(
		&g.ID, &g.Name, &g.Description, &g.AvatarURL, &g.InviteLink,
		&g.IsPrivate, &g.MaxMembers, &g.CreatedBy, &g.CreatedAt, &g.UpdatedAt,
	)
	if err != nil {
		return nil, err
	}
	return g, nil
}

func (r *Repository) ListUserGroups(ctx context.Context, userID uuid.UUID) ([]*Group, error) {
	rows, err := r.db.Query(ctx, `
		SELECT g.id, g.name, g.description, g.avatar_url, g.invite_link,
		       g.is_private, g.max_members, g.created_by, g.created_at, g.updated_at
		FROM groups g
		JOIN group_members m ON m.group_id = g.id
		WHERE m.user_id = $1
		ORDER BY g.updated_at DESC
	`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	return scanGroups(rows)
}

// ─── Members ──────────────────────────────────────────────────────────────────

func (r *Repository) AddMember(ctx context.Context, groupID, userID uuid.UUID, role Role) error {
	_, err := r.db.Exec(ctx, `
		INSERT INTO group_members (group_id, user_id, role)
		VALUES ($1,$2,$3)
		ON CONFLICT (group_id, user_id) DO NOTHING
	`, groupID, userID, string(role))
	return err
}

func (r *Repository) RemoveMember(ctx context.Context, groupID, userID uuid.UUID) error {
	_, err := r.db.Exec(ctx,
		`DELETE FROM group_members WHERE group_id=$1 AND user_id=$2`, groupID, userID)
	return err
}

func (r *Repository) UpdateMemberRole(ctx context.Context, groupID, userID uuid.UUID, role Role) error {
	_, err := r.db.Exec(ctx,
		`UPDATE group_members SET role=$3 WHERE group_id=$1 AND user_id=$2`,
		groupID, userID, string(role))
	return err
}

func (r *Repository) GetMember(ctx context.Context, groupID, userID uuid.UUID) (*Member, error) {
	m := &Member{}
	err := r.db.QueryRow(ctx, `
		SELECT group_id, user_id, role, joined_at
		FROM group_members WHERE group_id=$1 AND user_id=$2
	`, groupID, userID).Scan(&m.GroupID, &m.UserID, &m.Role, &m.JoinedAt)
	if err != nil {
		return nil, err
	}
	return m, nil
}

func (r *Repository) ListMembers(ctx context.Context, groupID uuid.UUID) ([]*Member, error) {
	rows, err := r.db.Query(ctx, `
		SELECT m.group_id, m.user_id, m.role, m.joined_at,
		       u.username, u.display_name, u.avatar_url
		FROM group_members m
		JOIN users u ON u.id = m.user_id
		WHERE m.group_id = $1
		ORDER BY m.joined_at ASC
	`, groupID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var members []*Member
	for rows.Next() {
		m := &Member{}
		if err := rows.Scan(&m.GroupID, &m.UserID, &m.Role, &m.JoinedAt,
			&m.Username, &m.DisplayName, &m.AvatarURL); err != nil {
			return nil, err
		}
		members = append(members, m)
	}
	return members, rows.Err()
}

// MemberIDs returns just the user IDs of all group members (for fanout delivery).
func (r *Repository) MemberIDs(ctx context.Context, groupID uuid.UUID) ([]uuid.UUID, error) {
	rows, err := r.db.Query(ctx,
		`SELECT user_id FROM group_members WHERE group_id=$1`, groupID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var ids []uuid.UUID
	for rows.Next() {
		var id uuid.UUID
		if err := rows.Scan(&id); err != nil {
			return nil, err
		}
		ids = append(ids, id)
	}
	return ids, rows.Err()
}

func (r *Repository) MemberCount(ctx context.Context, groupID uuid.UUID) (int, error) {
	var count int
	err := r.db.QueryRow(ctx,
		`SELECT COUNT(*) FROM group_members WHERE group_id=$1`, groupID).Scan(&count)
	return count, err
}

// IsMember returns true if userID belongs to the group.
func (r *Repository) IsMember(ctx context.Context, groupID, userID uuid.UUID) (bool, error) {
	var count int
	err := r.db.QueryRow(ctx,
		`SELECT COUNT(*) FROM group_members WHERE group_id=$1 AND user_id=$2`, groupID, userID,
	).Scan(&count)
	return count > 0, err
}

// ─── Messages ─────────────────────────────────────────────────────────────────

func (r *Repository) SaveGroupMessage(ctx context.Context, m *GroupMessage) error {
	return r.db.QueryRow(ctx, `
		INSERT INTO group_messages
		  (group_id, sender_id, ciphertext, msg_type, iteration, distribution_id, expires_at)
		VALUES ($1,$2,$3,$4,$5,$6,$7)
		RETURNING id, created_at
	`, m.GroupID, m.SenderID, m.Ciphertext, m.MsgType, m.Iteration, m.DistributionID, m.ExpiresAt,
	).Scan(&m.ID, &m.CreatedAt)
}

func (r *Repository) GroupHistory(ctx context.Context, groupID uuid.UUID, limit int, before time.Time) ([]*GroupMessage, error) {
	var (
		rows pgx.Rows
		err  error
	)
	if before.IsZero() {
		rows, err = r.db.Query(ctx, `
			SELECT id, group_id, sender_id, ciphertext, msg_type, iteration, distribution_id, expires_at, created_at, is_pinned
			FROM group_messages
			WHERE group_id=$1 AND (expires_at IS NULL OR expires_at > NOW())
			ORDER BY created_at DESC LIMIT $2
		`, groupID, limit)
	} else {
		rows, err = r.db.Query(ctx, `
			SELECT id, group_id, sender_id, ciphertext, msg_type, iteration, distribution_id, expires_at, created_at, is_pinned
			FROM group_messages
			WHERE group_id=$1 AND created_at < $2 AND (expires_at IS NULL OR expires_at > NOW())
			ORDER BY created_at DESC LIMIT $3
		`, groupID, before, limit)
	}
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var msgs []*GroupMessage
	for rows.Next() {
		m := &GroupMessage{}
		if err := rows.Scan(&m.ID, &m.GroupID, &m.SenderID, &m.Ciphertext, &m.MsgType,
			&m.Iteration, &m.DistributionID, &m.ExpiresAt, &m.CreatedAt, &m.IsPinned); err != nil {
			return nil, err
		}
		msgs = append(msgs, m)
	}
	return msgs, rows.Err()
}

// PinGroupMessage toggles the is_pinned status to true for group messages.
func (r *Repository) PinGroupMessage(ctx context.Context, msgID uuid.UUID) error {
	_, err := r.db.Exec(ctx, `UPDATE group_messages SET is_pinned = TRUE WHERE id = $1`, msgID)
	return err
}

// UnpinGroupMessage toggles the is_pinned status to false for group messages.
func (r *Repository) UnpinGroupMessage(ctx context.Context, msgID uuid.UUID) error {
	_, err := r.db.Exec(ctx, `UPDATE group_messages SET is_pinned = FALSE WHERE id = $1`, msgID)
	return err
}

// ─── Sender Keys ──────────────────────────────────────────────────────────────

type SenderKey struct {
	GroupID      uuid.UUID `json:"group_id"`
	SenderID     uuid.UUID `json:"sender_id"`
	Distribution string    `json:"distribution"` // JSON array of encrypted records
	UpdatedAt    time.Time `json:"updated_at"`
}

// SaveSenderKeyDistribution saves a JSON array of encrypted sender key records
func (r *Repository) SaveSenderKeyDistribution(ctx context.Context, groupID, senderID uuid.UUID, distribution string) error {
	_, err := r.db.Exec(ctx, `
		INSERT INTO sender_keys (group_id, sender_id, distribution, updated_at)
		VALUES ($1, $2, $3, NOW())
		ON CONFLICT (group_id, sender_id)
		DO UPDATE SET distribution = EXCLUDED.distribution, updated_at = NOW()
	`, groupID, senderID, distribution)
	return err
}

// GetSenderKeys returns all sender keys for a specific group
func (r *Repository) GetSenderKeys(ctx context.Context, groupID uuid.UUID) ([]*SenderKey, error) {
	rows, err := r.db.Query(ctx, `
		SELECT group_id, sender_id, distribution, updated_at
		FROM sender_keys
		WHERE group_id = $1
	`, groupID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var keys []*SenderKey
	for rows.Next() {
		k := &SenderKey{}
		if err := rows.Scan(&k.GroupID, &k.SenderID, &k.Distribution, &k.UpdatedAt); err != nil {
			return nil, err
		}
		keys = append(keys, k)
	}
	return keys, rows.Err()
}

// ─── helpers ─────────────────────────────────────────────────────────────────

func scanGroups(rows pgx.Rows) ([]*Group, error) {
	var groups []*Group
	for rows.Next() {
		g := &Group{}
		if err := rows.Scan(&g.ID, &g.Name, &g.Description, &g.AvatarURL, &g.InviteLink,
			&g.IsPrivate, &g.MaxMembers, &g.CreatedBy, &g.CreatedAt, &g.UpdatedAt); err != nil {
			return nil, err
		}
		groups = append(groups, g)
	}
	return groups, rows.Err()
}
