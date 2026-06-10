package notification

import (
	"context"
	"encoding/json"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

type Repository struct {
	db *pgxpool.Pool
}

func NewRepository(db *pgxpool.Pool) *Repository {
	return &Repository{db: db}
}

func (r *Repository) Save(ctx context.Context, n *Notification) error {
	var dataBytes []byte
	var err error
	if n.Data != nil {
		dataBytes, err = json.Marshal(n.Data)
		if err != nil {
			return err
		}
	}

	return r.db.QueryRow(ctx, `
		INSERT INTO notifications (user_id, title, body, data, read_at)
		VALUES ($1, $2, $3, $4, $5)
		RETURNING id, created_at
	`, n.UserID, n.Title, n.Body, dataBytes, n.ReadAt).Scan(&n.ID, &n.CreatedAt)
}

func (r *Repository) ListForUser(ctx context.Context, userID uuid.UUID, limit, offset int) ([]*Notification, error) {
	if limit <= 0 {
		limit = 30
	}
	if offset < 0 {
		offset = 0
	}

	rows, err := r.db.Query(ctx, `
		SELECT id, user_id, title, body, data, read_at, created_at
		FROM notifications
		WHERE user_id = $1
		ORDER BY created_at DESC
		LIMIT $2 OFFSET $3
	`, userID, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []*Notification
	for rows.Next() {
		n := &Notification{}
		var dataBytes []byte
		if err := rows.Scan(&n.ID, &n.UserID, &n.Title, &n.Body, &dataBytes, &n.ReadAt, &n.CreatedAt); err != nil {
			return nil, err
		}

		if len(dataBytes) > 0 {
			if err := json.Unmarshal(dataBytes, &n.Data); err != nil {
				n.Data = make(map[string]string)
			}
		}
		list = append(list, n)
	}

	return list, rows.Err()
}

func (r *Repository) MarkRead(ctx context.Context, userID, notificationID uuid.UUID) error {
	_, err := r.db.Exec(ctx, `
		UPDATE notifications
		SET read_at = NOW()
		WHERE id = $1 AND user_id = $2 AND read_at IS NULL
	`, notificationID, userID)
	return err
}

func (r *Repository) MarkAllRead(ctx context.Context, userID uuid.UUID) error {
	_, err := r.db.Exec(ctx, `
		UPDATE notifications
		SET read_at = NOW()
		WHERE user_id = $1 AND read_at IS NULL
	`, userID)
	return err
}

func (r *Repository) Delete(ctx context.Context, userID, notificationID uuid.UUID) error {
	_, err := r.db.Exec(ctx, `
		DELETE FROM notifications
		WHERE id = $1 AND user_id = $2
	`, notificationID, userID)
	return err
}
