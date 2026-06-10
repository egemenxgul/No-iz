package report

import (
	"context"

	"github.com/jackc/pgx/v5/pgxpool"
)

type Repository struct {
	db *pgxpool.Pool
}

func NewRepository(db *pgxpool.Pool) *Repository {
	return &Repository{db: db}
}

// Create inserts an abuse report.
func (r *Repository) Create(ctx context.Context, rep *Report) error {
	query := `
		INSERT INTO reports (reporter_id, reported_user_id, reported_community_id, reason, description)
		VALUES ($1, $2, $3, $4, $5)
		RETURNING id, created_at, status
	`
	return r.db.QueryRow(ctx, query,
		rep.ReporterID, rep.ReportedUserID, rep.ReportedCommunityID, rep.Reason, rep.Description,
	).Scan(&rep.ID, &rep.CreatedAt, &rep.Status)
}
