package backup

import (
	"time"

	"github.com/google/uuid"
)

type Backup struct {
	UserID        uuid.UUID `json:"user_id"`
	EncryptedBlob string    `json:"encrypted_blob"`
	Salt          string    `json:"salt"`
	CreatedAt     time.Time `json:"created_at"`
}
