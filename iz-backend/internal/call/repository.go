package call

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

// Repository handles all DB operations for calls.
type Repository struct {
	db *pgxpool.Pool
}

// NewRepository creates a new call repository.
func NewRepository(db *pgxpool.Pool) *Repository {
	return &Repository{db: db}
}

// CreateCall persists a new call record.
func (r *Repository) CreateCall(ctx context.Context, c *Call) error {
	return r.db.QueryRow(ctx, `
		INSERT INTO calls (call_type, status, caller_id, callee_id, group_id)
		VALUES ($1,$2,$3,$4,$5)
		RETURNING id, ringing_at, created_at
	`, string(c.CallType), string(c.Status), c.CallerID, c.CalleeID, c.GroupID,
	).Scan(&c.ID, &c.RingingAt, &c.CreatedAt)
}

// CreateCallWithID persists a call record with a specified ID.
func (r *Repository) CreateCallWithID(ctx context.Context, c *Call) error {
	_, err := r.db.Exec(ctx, `
		INSERT INTO calls (id, call_type, status, caller_id, callee_id, group_id)
		VALUES ($1, $2, $3, $4, $5, $6)
		ON CONFLICT (id) DO NOTHING
	`, c.ID, string(c.CallType), string(c.Status), c.CallerID, c.CalleeID, c.GroupID)
	return err
}

// GetCall fetches a call by ID.
func (r *Repository) GetCall(ctx context.Context, id uuid.UUID) (*Call, error) {
	c := &Call{}
	err := r.db.QueryRow(ctx, `
		SELECT id, call_type, status, caller_id, callee_id, group_id,
		       ringing_at, accepted_at, ended_at, duration_secs, created_at
		FROM calls WHERE id=$1
	`, id).Scan(
		&c.ID, &c.CallType, &c.Status, &c.CallerID, &c.CalleeID, &c.GroupID,
		&c.RingingAt, &c.AcceptedAt, &c.EndedAt, &c.DurationSecs, &c.CreatedAt,
	)
	return c, err
}

// SetStatus updates a call's status (and timing fields).
func (r *Repository) Accept(ctx context.Context, callID uuid.UUID) error {
	_, err := r.db.Exec(ctx,
		`UPDATE calls SET status='active', accepted_at=NOW() WHERE id=$1`, callID)
	return err
}

func (r *Repository) Reject(ctx context.Context, callID uuid.UUID) error {
	_, err := r.db.Exec(ctx,
		`UPDATE calls SET status='rejected', ended_at=NOW() WHERE id=$1`, callID)
	return err
}

func (r *Repository) End(ctx context.Context, callID uuid.UUID) error {
	_, err := r.db.Exec(ctx,
		`UPDATE calls SET status='ended', ended_at=NOW() WHERE id=$1`, callID)
	return err
}

func (r *Repository) Miss(ctx context.Context, callID uuid.UUID) error {
	_, err := r.db.Exec(ctx,
		`UPDATE calls SET status='missed', ended_at=NOW() WHERE id=$1`, callID)
	return err
}

func (r *Repository) SetBusy(ctx context.Context, callID uuid.UUID) error {
	_, err := r.db.Exec(ctx,
		`UPDATE calls SET status='busy', ended_at=NOW() WHERE id=$1`, callID)
	return err
}

// HasActiveCall returns true if the user is currently in an active/ringing call.
func (r *Repository) HasActiveCall(ctx context.Context, userID uuid.UUID) (bool, error) {
	var count int
	err := r.db.QueryRow(ctx, `
		SELECT COUNT(*) FROM calls
		WHERE (caller_id=$1 OR callee_id=$1)
		  AND status IN ('ringing','active')
	`, userID).Scan(&count)
	return count > 0, err
}

// CallHistory returns paginated call history for a user.
func (r *Repository) CallHistory(ctx context.Context, userID uuid.UUID, limit int, before time.Time) ([]*Call, error) {
	var rows interface {
		Next() bool
		Scan(...interface{}) error
		Err() error
		Close()
	}
	var err error

	if before.IsZero() {
		rows, err = r.db.Query(ctx, `
			SELECT id, call_type, status, caller_id, callee_id, group_id,
			       ringing_at, accepted_at, ended_at, duration_secs, created_at
			FROM calls
			WHERE caller_id=$1 OR callee_id=$1
			ORDER BY created_at DESC LIMIT $2
		`, userID, limit)
	} else {
		rows, err = r.db.Query(ctx, `
			SELECT id, call_type, status, caller_id, callee_id, group_id,
			       ringing_at, accepted_at, ended_at, duration_secs, created_at
			FROM calls
			WHERE (caller_id=$1 OR callee_id=$1) AND created_at < $2
			ORDER BY created_at DESC LIMIT $3
		`, userID, before, limit)
	}
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var calls []*Call
	for rows.Next() {
		c := &Call{}
		if err := rows.Scan(&c.ID, &c.CallType, &c.Status, &c.CallerID, &c.CalleeID, &c.GroupID,
			&c.RingingAt, &c.AcceptedAt, &c.EndedAt, &c.DurationSecs, &c.CreatedAt); err != nil {
			return nil, err
		}
		calls = append(calls, c)
	}
	return calls, rows.Err()
}

// ─── Group call participants ─────────────────────────────────────────────────

func (r *Repository) AddParticipant(ctx context.Context, callID, userID uuid.UUID) error {
	_, err := r.db.Exec(ctx, `
		INSERT INTO call_participants (call_id, user_id)
		VALUES ($1,$2) ON CONFLICT DO NOTHING
	`, callID, userID)
	return err
}

func (r *Repository) RemoveParticipant(ctx context.Context, callID, userID uuid.UUID) error {
	_, err := r.db.Exec(ctx,
		`UPDATE call_participants SET left_at=NOW() WHERE call_id=$1 AND user_id=$2`, callID, userID)
	return err
}

func (r *Repository) ActiveParticipants(ctx context.Context, callID uuid.UUID) ([]uuid.UUID, error) {
	rows, err := r.db.Query(ctx,
		`SELECT user_id FROM call_participants WHERE call_id=$1 AND left_at IS NULL`, callID)
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
