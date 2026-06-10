package report

import (
	"time"

	"github.com/google/uuid"
)

// Report represents a user or community abuse report.
type Report struct {
	ID                 uuid.UUID  `json:"id"`
	ReporterID         uuid.UUID  `json:"reporter_id"`
	ReportedUserID     *uuid.UUID `json:"reported_user_id,omitempty"`
	ReportedCommunityID *uuid.UUID `json:"reported_community_id,omitempty"`
	Reason             string     `json:"reason"`
	Description        string     `json:"description"`
	CreatedAt          time.Time  `json:"created_at"`
	Status             string     `json:"status"` // "pending" | "resolved" | "dismissed"
}
