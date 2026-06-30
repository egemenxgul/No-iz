package messaging

import (
	"context"
	"encoding/json"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// Repository handles all database operations for messages.
type Repository struct {
	db *pgxpool.Pool
}

// NewRepository creates a new messaging repository.
func NewRepository(db *pgxpool.Pool) *Repository {
	return &Repository{db: db}
}

// Save persists a new message and returns the generated ID and created_at.
func (r *Repository) Save(ctx context.Context, m *Message) error {
	query := `
		INSERT INTO messages (
			sender_id, recipient_id, ciphertext, msg_type,
			ratchet_key, prev_counter, counter, expires_at
		) VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
		RETURNING id, created_at
	`
	return r.db.QueryRow(ctx, query,
		m.SenderID, m.RecipientID, m.Ciphertext, string(m.MsgType),
		m.RatchetKey, m.PrevCounter, m.Counter, m.ExpiresAt,
	).Scan(&m.ID, &m.CreatedAt)
}

// MarkDelivered sets delivered_at for a message.
func (r *Repository) MarkDelivered(ctx context.Context, msgID uuid.UUID) error {
	_, err := r.db.Exec(ctx,
		`UPDATE messages SET delivered_at = NOW() WHERE id = $1 AND delivered_at IS NULL`,
		msgID,
	)
	return err
}

// MarkRead sets read_at for a message.
func (r *Repository) MarkRead(ctx context.Context, msgID uuid.UUID) error {
	_, err := r.db.Exec(ctx,
		`UPDATE messages SET read_at = NOW() WHERE id = $1 AND read_at IS NULL`,
		msgID,
	)
	return err
}

// GetByID fetches a single message by its ID.
func (r *Repository) GetByID(ctx context.Context, msgID uuid.UUID) (*Message, error) {
	m := &Message{}
	var reactionsRaw []byte
	err := r.db.QueryRow(ctx, `
		SELECT id, sender_id, recipient_id, ciphertext, msg_type,
		       ratchet_key, prev_counter, counter,
		       delivered_at, read_at, expires_at, edited_at, created_at,
		       (SELECT COALESCE(json_object_agg(user_id, reaction), '{}') FROM message_reactions WHERE message_id = messages.id) as reactions,
		       is_pinned
		FROM messages
		WHERE id = $1
	`, msgID).Scan(
		&m.ID, &m.SenderID, &m.RecipientID, &m.Ciphertext, &m.MsgType,
		&m.RatchetKey, &m.PrevCounter, &m.Counter,
		&m.DeliveredAt, &m.ReadAt, &m.ExpiresAt, &m.EditedAt, &m.CreatedAt,
		&reactionsRaw, &m.IsPinned,
	)
	if err != nil {
		return nil, err
	}
	if len(reactionsRaw) > 0 {
		importJson := map[string]string{}
		_ = json.Unmarshal(reactionsRaw, &importJson)
		m.Reactions = importJson
	}
	return m, nil
}

// PinMessage toggles the is_pinned status to true.
func (r *Repository) PinMessage(ctx context.Context, msgID uuid.UUID) error {
	_, err := r.db.Exec(ctx, `UPDATE messages SET is_pinned = TRUE WHERE id = $1`, msgID)
	return err
}

// UnpinMessage toggles the is_pinned status to false.
func (r *Repository) UnpinMessage(ctx context.Context, msgID uuid.UUID) error {
	_, err := r.db.Exec(ctx, `UPDATE messages SET is_pinned = FALSE WHERE id = $1`, msgID)
	return err
}

// Conversation returns messages between two users, cursor-paginated.
// If before is zero, returns the latest page.
func (r *Repository) Conversation(
	ctx context.Context,
	userA, userB uuid.UUID,
	limit int,
	before time.Time,
) ([]*Message, error) {
	var query string
	var args []interface{}

	if before.IsZero() {
		query = `
			SELECT id, sender_id, recipient_id, ciphertext, msg_type,
			       ratchet_key, prev_counter, counter,
			       delivered_at, read_at, expires_at, edited_at, created_at,
			       (SELECT COALESCE(json_object_agg(user_id, reaction), '{}') FROM message_reactions WHERE message_id = messages.id) as reactions,
			       is_pinned
			FROM messages
			WHERE (sender_id = $1 AND recipient_id = $2)
			   OR (sender_id = $2 AND recipient_id = $1)
			ORDER BY created_at DESC
			LIMIT $3
		`
		args = []interface{}{userA, userB, limit}
	} else {
		query = `
			SELECT id, sender_id, recipient_id, ciphertext, msg_type,
			       ratchet_key, prev_counter, counter,
			       delivered_at, read_at, expires_at, edited_at, created_at,
			       (SELECT COALESCE(json_object_agg(user_id, reaction), '{}') FROM message_reactions WHERE message_id = messages.id) as reactions,
			       is_pinned
			FROM messages
			WHERE ((sender_id = $1 AND recipient_id = $2)
			   OR (sender_id = $2 AND recipient_id = $1))
			  AND created_at < $3
			ORDER BY created_at DESC
			LIMIT $4
		`
		args = []interface{}{userA, userB, before, limit}
	}

	rows, err := r.db.Query(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var msgs []*Message
	for rows.Next() {
		m := &Message{}
		var reactionsRaw []byte
		if err := rows.Scan(
			&m.ID, &m.SenderID, &m.RecipientID, &m.Ciphertext, &m.MsgType,
			&m.RatchetKey, &m.PrevCounter, &m.Counter,
			&m.DeliveredAt, &m.ReadAt, &m.ExpiresAt, &m.EditedAt, &m.CreatedAt,
			&reactionsRaw, &m.IsPinned,
		); err != nil {
			continue
		}
		if len(reactionsRaw) > 0 {
			importJson := map[string]string{}
			_ = json.Unmarshal(reactionsRaw, &importJson)
			m.Reactions = importJson
		}
		msgs = append(msgs, m)
	}
	return msgs, rows.Err()
}

// UndeliveredFor returns all undelivered messages for a user.
func (r *Repository) UndeliveredFor(ctx context.Context, userID uuid.UUID) ([]*Message, error) {
	rows, err := r.db.Query(ctx, `
		SELECT id, sender_id, recipient_id, ciphertext, msg_type,
		       ratchet_key, prev_counter, counter,
		       delivered_at, read_at, expires_at, edited_at, created_at,
		       (SELECT COALESCE(json_object_agg(user_id, reaction), '{}') FROM message_reactions WHERE message_id = messages.id) as reactions
		FROM messages
		WHERE recipient_id = $1
		  AND delivered_at IS NULL
		  AND (expires_at IS NULL OR expires_at > NOW())
		ORDER BY created_at ASC
	`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var msgs []*Message
	for rows.Next() {
		m := &Message{}
		var reactionsRaw []byte
		err := rows.Scan(
			&m.ID, &m.SenderID, &m.RecipientID, &m.Ciphertext, &m.MsgType,
			&m.RatchetKey, &m.PrevCounter, &m.Counter,
			&m.DeliveredAt, &m.ReadAt, &m.ExpiresAt, &m.EditedAt, &m.CreatedAt,
			&reactionsRaw,
		)
		if err != nil {
			return nil, err
		}
		if len(reactionsRaw) > 0 {
			importJson := map[string]string{}
			_ = json.Unmarshal(reactionsRaw, &importJson)
			m.Reactions = importJson
		}
		msgs = append(msgs, m)
	}
	return msgs, rows.Err()
}

// ListConversations returns a list of unique users the given user has exchanged messages with,
// along with the latest message from that conversation and friendship status.
func (r *Repository) ListConversations(ctx context.Context, userID uuid.UUID) ([]map[string]interface{}, error) {
	query := `
		WITH LatestMessages AS (
			SELECT
				CASE WHEN sender_id = $1 THEN recipient_id ELSE sender_id END as other_user_id,
				ciphertext, msg_type, created_at,
				ROW_NUMBER() OVER(PARTITION BY CASE WHEN sender_id = $1 THEN recipient_id ELSE sender_id END ORDER BY created_at DESC) as rn
			FROM messages
			WHERE sender_id = $1 OR recipient_id = $1
		)
		SELECT 
			lm.other_user_id,
			lm.ciphertext,
			lm.msg_type,
			lm.created_at,
			u.username as other_username,
			u.display_name as other_display_name,
			u.avatar_url as other_avatar_url,
			COALESCE(f.status, 'none') as friendship_status,
			f.initiator_id,
			CASE 
				WHEN u.hide_last_seen = TRUE OR (SELECT hide_last_seen FROM users WHERE id = $1) = TRUE THEN NULL
				ELSE u.last_seen_at
			END as last_seen_at
		FROM LatestMessages lm
		JOIN users u ON u.id = lm.other_user_id
		LEFT JOIN friendships f ON 
			(f.user_id1 = LEAST($1, lm.other_user_id) AND f.user_id2 = GREATEST($1, lm.other_user_id))
		WHERE rn = 1
		ORDER BY lm.created_at DESC
	`
	rows, err := r.db.Query(ctx, query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var conversations []map[string]interface{}
	for rows.Next() {
		var otherID uuid.UUID
		var ciphertext, msgType, username, displayName, avatarURL, friendshipStatus string
		var initiatorID *uuid.UUID
		var lastSeenAt *time.Time
		var createdAt time.Time
		err := rows.Scan(&otherID, &ciphertext, &msgType, &createdAt, &username, &displayName, &avatarURL, &friendshipStatus, &initiatorID, &lastSeenAt)
		if err != nil {
			return nil, err
		}
		conversations = append(conversations, map[string]interface{}{
			"other_user_id":       otherID,
			"other_username":      username,
			"other_display_name":  displayName,
			"other_avatar_url":    avatarURL,
			"last_message":        ciphertext,
			"last_message_type":   msgType,
			"last_message_time":   createdAt,
			"friendship_status":   friendshipStatus,
			"initiator_id":        initiatorID,
			"last_seen_at":        lastSeenAt,
		})
	}
	return conversations, nil
}

// ────────────────────────────────────────────────────────────────
// Chat Settings (Mute/Unmute)
// ────────────────────────────────────────────────────────────────

// MuteChat mutes a conversation (targetID can be a user or a group) until the given time.
// A nil until time implies muted forever.
func (r *Repository) MuteChat(ctx context.Context, userID, targetID string, until *time.Time) error {
	_, err := r.db.Exec(ctx, `
		INSERT INTO user_chat_settings (user_id, target_id, muted_until)
		VALUES ($1, $2, $3)
		ON CONFLICT (user_id, target_id) 
		DO UPDATE SET muted_until = EXCLUDED.muted_until, updated_at = NOW()
	`, userID, targetID, until)
	return err
}

// UnmuteChat removes the mute setting for a conversation.
func (r *Repository) UnmuteChat(ctx context.Context, userID, targetID string) error {
	_, err := r.db.Exec(ctx, `
		UPDATE user_chat_settings SET muted_until = NULL, updated_at = NOW()
		WHERE user_id = $1 AND target_id = $2
	`, userID, targetID)
	return err
}

// GetMutedUntil returns the time until which a chat is muted.
// Returns nil if not muted, or if the mute has expired.
func (r *Repository) GetMutedUntil(ctx context.Context, userID, targetID string) (*time.Time, error) {
	var mutedUntil *time.Time
	err := r.db.QueryRow(ctx, `
		SELECT muted_until FROM user_chat_settings
		WHERE user_id = $1 AND target_id = $2
	`, userID, targetID).Scan(&mutedUntil)
	
	if err == pgx.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	
	if mutedUntil != nil && mutedUntil.Before(time.Now()) {
		return nil, nil
	}
	
	return mutedUntil, nil
}


// GetSenderName fetches the display name of a user by their UUID.
func (r *Repository) GetSenderName(ctx context.Context, id uuid.UUID) (string, error) {
	var displayName string
	err := r.db.QueryRow(ctx, `SELECT display_name FROM users WHERE id = $1`, id).Scan(&displayName)
	if err != nil {
		return "", err
	}
	return displayName, nil
}

// GetConversationPartners returns a list of unique user UUIDs the given user has active messages with.
func (r *Repository) GetConversationPartners(ctx context.Context, userID uuid.UUID) ([]uuid.UUID, error) {
	query := `
		SELECT DISTINCT 
			CASE WHEN sender_id = $1 THEN recipient_id ELSE sender_id END as other_user_id
		FROM messages
		WHERE sender_id = $1 OR recipient_id = $1
	`
	rows, err := r.db.Query(ctx, query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var partners []uuid.UUID
	for rows.Next() {
		var otherID uuid.UUID
		if err := rows.Scan(&otherID); err != nil {
			return nil, err
		}
		partners = append(partners, otherID)
	}
	return partners, rows.Err()
}

// UpdateLastSeen updates the last_seen_at timestamp to now for the user.
func (r *Repository) UpdateLastSeen(ctx context.Context, userID uuid.UUID) error {
	_, err := r.db.Exec(ctx, `UPDATE users SET last_seen_at = NOW() WHERE id = $1`, userID)
	return err
}

// GetPrivacySettings retrieves privacy settings for a user.
func (r *Repository) GetPrivacySettings(ctx context.Context, userID uuid.UUID) (hideLastSeen, hideOnline, hideTyping, hideReadReceipts bool, err error) {
	err = r.db.QueryRow(ctx, `
		SELECT hide_last_seen, hide_online, hide_typing, hide_read_receipts FROM users WHERE id = $1
	`, userID).Scan(&hideLastSeen, &hideOnline, &hideTyping, &hideReadReceipts)
	return
}

// RevokeMessage sets the msg_type of the message to 'deleted' and clears the ciphertext.
func (r *Repository) RevokeMessage(ctx context.Context, msgID, senderID uuid.UUID) error {
	query := `
		UPDATE messages
		SET msg_type = 'deleted',
		    ciphertext = '',
		    ratchet_key = NULL
		WHERE id = $1 AND sender_id = $2
	`
	ct, err := r.db.Exec(ctx, query, msgID, senderID)
	if err != nil {
		return err
	}
	if ct.RowsAffected() == 0 {
		return pgx.ErrNoRows
	}
	return nil
}

// EditMessage updates the ciphertext of a message and sets edited_at to NOW().
func (r *Repository) EditMessage(ctx context.Context, msgID, senderID uuid.UUID, newCiphertext string) error {
	query := `
		UPDATE messages
		SET ciphertext = $1,
		    edited_at = NOW()
		WHERE id = $2 AND sender_id = $3
	`
	ct, err := r.db.Exec(ctx, query, newCiphertext, msgID, senderID)
	if err != nil {
		return err
	}
	if ct.RowsAffected() == 0 {
		return pgx.ErrNoRows
	}
	return nil
}

// SetReaction adds or updates a reaction on a message. If reaction is empty, it removes it.
func (r *Repository) SetReaction(ctx context.Context, msgID, userID uuid.UUID, reaction string) error {
	if reaction == "" {
		_, err := r.db.Exec(ctx, `DELETE FROM message_reactions WHERE message_id = $1 AND user_id = $2`, msgID, userID)
		return err
	}
	query := `
		INSERT INTO message_reactions (message_id, user_id, reaction, created_at)
		VALUES ($1, $2, $3, NOW())
		ON CONFLICT (message_id, user_id) 
		DO UPDATE SET reaction = EXCLUDED.reaction, created_at = NOW()
	`
	_, err := r.db.Exec(ctx, query, msgID, userID, reaction)
	return err
}




// DeleteExpiredMessages permanently deletes messages where expires_at has passed.
func (r *Repository) DeleteExpiredMessages(ctx context.Context) (int64, error) {
query := `DELETE FROM messages WHERE expires_at IS NOT NULL AND expires_at < NOW()`
tag, err := r.db.Exec(ctx, query)
if err != nil {
return 0, err
}

// Also delete expired group messages
groupQuery := `DELETE FROM group_messages WHERE expires_at IS NOT NULL AND expires_at < NOW()`
gTag, err := r.db.Exec(ctx, groupQuery)
if err != nil {
return tag.RowsAffected(), err // Return DM deleted count even if group fails
}

return tag.RowsAffected() + gTag.RowsAffected(), nil
}
