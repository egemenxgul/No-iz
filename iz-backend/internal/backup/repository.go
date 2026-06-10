package backup

import (
	"context"

	"github.com/google/uuid"
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
