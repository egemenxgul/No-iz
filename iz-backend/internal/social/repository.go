package social

import (
	"context"
	"database/sql"
	"errors"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// Repository handles database operations for social friendships.
type Repository struct {
	db *pgxpool.Pool
}

// NewRepository creates a new Repository.
func NewRepository(db *pgxpool.Pool) *Repository {
	return &Repository{db: db}
}

// GetFriendshipStatus returns the status of friendship between two users.
// It returns "none", "pending_sent", "pending_received", "accepted", "rejected".
func (r *Repository) GetFriendshipStatus(ctx context.Context, myID, otherID uuid.UUID) (string, *uuid.UUID, error) {
	u1, u2 := myID, otherID
	if u1.String() > u2.String() {
		u1, u2 = u2, u1
	}

	query := `
		SELECT status, initiator_id, id
		FROM friendships
		WHERE user_id1 = $1 AND user_id2 = $2
	`
	var status string
	var initiatorID, requestID uuid.UUID

	err := r.db.QueryRow(ctx, query, u1, u2).Scan(&status, &initiatorID, &requestID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return "none", nil, nil
		}
		return "", nil, err
	}

	if status == "pending" {
		if initiatorID == myID {
			return "pending_sent", &requestID, nil
		}
		return "pending_received", &requestID, nil
	}

	return status, &requestID, nil
}

// EnsureFriendshipRecord guarantees that a friendship record exists.
// If it does not exist, it inserts one with 'pending' status.
// If it exists but is 'rejected', it resets it to 'pending' if the initiator is sending a new message.
func (r *Repository) EnsureFriendshipRecord(ctx context.Context, initiator, recipient uuid.UUID) error {
	u1, u2 := initiator, recipient
	if u1.String() > u2.String() {
		u1, u2 = u2, u1
	}

	// Try to insert
	query := `
		INSERT INTO friendships (user_id1, user_id2, initiator_id, status)
		VALUES ($1, $2, $3, 'pending')
		ON CONFLICT (user_id1, user_id2) DO UPDATE
		SET status = CASE 
			WHEN friendships.status = 'rejected' THEN 'pending'::varchar
			ELSE friendships.status
		END,
		initiator_id = CASE
			WHEN friendships.status = 'rejected' THEN EXCLUDED.initiator_id
			ELSE friendships.initiator_id
		END,
		updated_at = NOW()
		WHERE friendships.status = 'rejected' OR friendships.status = 'pending'
	`
	_, err := r.db.Exec(ctx, query, u1, u2, initiator)
	return err
}

// AcceptFriendship accepts a friendship request between two users.
func (r *Repository) AcceptFriendship(ctx context.Context, myID, otherID uuid.UUID) error {
	u1, u2 := myID, otherID
	if u1.String() > u2.String() {
		u1, u2 = u2, u1
	}

	query := `
		UPDATE friendships
		SET status = 'accepted', updated_at = NOW()
		WHERE user_id1 = $1 AND user_id2 = $2 AND status = 'pending'
	`
	ct, err := r.db.Exec(ctx, query, u1, u2)
	if err != nil {
		return err
	}
	if ct.RowsAffected() == 0 {
		return sql.ErrNoRows
	}
	return nil
}

// RejectFriendship rejects/declines a friendship request between two users.
func (r *Repository) RejectFriendship(ctx context.Context, myID, otherID uuid.UUID) error {
	u1, u2 := myID, otherID
	if u1.String() > u2.String() {
		u1, u2 = u2, u1
	}

	query := `
		UPDATE friendships
		SET status = 'rejected', updated_at = NOW()
		WHERE user_id1 = $1 AND user_id2 = $2 AND status = 'pending'
	`
	ct, err := r.db.Exec(ctx, query, u1, u2)
	if err != nil {
		return err
	}
	if ct.RowsAffected() == 0 {
		return sql.ErrNoRows
	}
	return nil
}

// BlockUser blocker blocks the target blocked user.
func (r *Repository) BlockUser(ctx context.Context, blocker, blocked uuid.UUID) error {
	query := `
		INSERT INTO blocks (blocker_id, blocked_id)
		VALUES ($1, $2)
		ON CONFLICT (blocker_id, blocked_id) DO NOTHING
	`
	_, err := r.db.Exec(ctx, query, blocker, blocked)
	return err
}

// UnblockUser blocker unblocks the target blocked user.
func (r *Repository) UnblockUser(ctx context.Context, blocker, blocked uuid.UUID) error {
	query := `
		DELETE FROM blocks
		WHERE blocker_id = $1 AND blocked_id = $2
	`
	_, err := r.db.Exec(ctx, query, blocker, blocked)
	return err
}

// HasBlocked checks if blocker has blocked blocked user.
func (r *Repository) HasBlocked(ctx context.Context, blocker, blocked uuid.UUID) (bool, error) {
	query := `
		SELECT EXISTS (
			SELECT 1 FROM blocks
			WHERE blocker_id = $1 AND blocked_id = $2
		)
	`
	var exists bool
	err := r.db.QueryRow(ctx, query, blocker, blocked).Scan(&exists)
	return exists, err
}

// IsBlocked checks if a bidirectional block exists between userA and userB.
func (r *Repository) IsBlocked(ctx context.Context, userA, userB uuid.UUID) (bool, error) {
	query := `
		SELECT EXISTS (
			SELECT 1 FROM blocks
			WHERE (blocker_id = $1 AND blocked_id = $2)
			   OR (blocker_id = $2 AND blocked_id = $1)
		)
	`
	var exists bool
	err := r.db.QueryRow(ctx, query, userA, userB).Scan(&exists)
	return exists, err
}
