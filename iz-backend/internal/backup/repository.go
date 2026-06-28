package backup

import (
	"context"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type Repository struct {
	db *pgxpool.Pool
}

func NewRepository(db *pgxpool.Pool) *Repository {
	return &Repository{db: db}
}

// Save upserts a backup record for a user.
func (r *Repository) Save(ctx context.Context, b *Backup) error {
	query := `
		INSERT INTO backups (user_id, encrypted_blob, salt, created_at)
		VALUES ($1, $2, $3, NOW())
		ON CONFLICT (user_id) DO UPDATE
		SET encrypted_blob = EXCLUDED.encrypted_blob,
		    salt = EXCLUDED.salt,
		    created_at = NOW()
		RETURNING created_at
	`
	return r.db.QueryRow(ctx, query, b.UserID, b.EncryptedBlob, b.Salt).Scan(&b.CreatedAt)
}

// GetByUserID fetches the active backup for a user.
func (r *Repository) GetByUserID(ctx context.Context, userID uuid.UUID) (*Backup, error) {
	b := &Backup{UserID: userID}
	query := `
		SELECT encrypted_blob, salt, created_at
		FROM backups
		WHERE user_id = $1
	`
	err := r.db.QueryRow(ctx, query, userID).Scan(&b.EncryptedBlob, &b.Salt, &b.CreatedAt)
	if err != nil {
		return nil, err
	}
	return b, nil
}

// SaveVaultMessages inserts multiple encrypted messages into the user's cloud vault.
func (r *Repository) SaveVaultMessages(ctx context.Context, userID uuid.UUID, messages []VaultMessage) error {
	// Using pgx CopyFrom for efficient bulk insert
	var rows [][]interface{}
	for _, m := range messages {
		// Generate new UUID for vault message if not provided
		if m.ID == uuid.Nil {
			m.ID = uuid.New()
		}
		rows = append(rows, []interface{}{
			m.ID, userID, m.ConversationID, m.Ciphertext, m.MsgType, m.OriginalCreatedAt,
		})
	}

	_, err := r.db.CopyFrom(
		ctx,
		[]string{"vault_messages"},
		[]string{"id", "user_id", "conversation_id", "ciphertext", "msg_type", "original_created_at"},
		pgx.CopyFromRows(rows),
	)
	return err
}

// GetVaultMessages fetches paginated vault messages for a specific conversation.
func (r *Repository) GetVaultMessages(ctx context.Context, userID, convID uuid.UUID, limit int, offset int) ([]VaultMessage, error) {
	query := `
		SELECT id, user_id, conversation_id, ciphertext, msg_type, original_created_at, created_at
		FROM vault_messages
		WHERE user_id = $1 AND conversation_id = $2
		ORDER BY original_created_at DESC
		LIMIT $3 OFFSET $4
	`
	rows, err := r.db.Query(ctx, query, userID, convID, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var msgs []VaultMessage
	for rows.Next() {
		var m VaultMessage
		if err := rows.Scan(&m.ID, &m.UserID, &m.ConversationID, &m.Ciphertext, &m.MsgType, &m.OriginalCreatedAt, &m.CreatedAt); err != nil {
			return nil, err
		}
		msgs = append(msgs, m)
	}
	return msgs, nil
}
