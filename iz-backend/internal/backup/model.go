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

type VaultMessage struct {
	ID                uuid.UUID `json:"id"`
	UserID            uuid.UUID `json:"user_id"`
	ConversationID    uuid.UUID `json:"conversation_id"`
	Ciphertext        string    `json:"ciphertext"`
	MsgType           string    `json:"msg_type"`
	OriginalCreatedAt time.Time `json:"original_created_at"`
	CreatedAt         time.Time `json:"created_at"`
}
