package messaging

import (
	"time"

	"github.com/google/uuid"
)

// MsgType enumerates the types of messages in a conversation.
type MsgType string

const (
	MsgTypeText  MsgType = "text"
	MsgTypeImage MsgType = "image"
	MsgTypeVideo MsgType = "video"
	MsgTypeAudio MsgType = "audio"
	MsgTypeFile  MsgType = "file"
	MsgTypeDeleted MsgType = "deleted"
)

// Message represents a single encrypted message stored server-side.
// The server is intentionally blind to the plaintext content.
type Message struct {
	ID          uuid.UUID  `json:"id"`
	SenderID    uuid.UUID  `json:"sender_id"`
	RecipientID uuid.UUID  `json:"recipient_id"`
	Ciphertext  string     `json:"ciphertext"`  // base64 AES-256-GCM blob
	MsgType     MsgType    `json:"msg_type"`
	RatchetKey  string     `json:"ratchet_key"` // sender's current DH ratchet pub key
	PrevCounter int        `json:"prev_counter"`
	Counter     int        `json:"counter"`
	DeliveredAt *time.Time `json:"delivered_at,omitempty"`
	ReadAt      *time.Time `json:"read_at,omitempty"`
	ExpiresAt   *time.Time `json:"expires_at,omitempty"`
	EditedAt    *time.Time `json:"edited_at,omitempty"`
	Reactions   map[string]string `json:"reactions,omitempty"` // UserID -> Reaction Emoji
	IsPinned    bool       `json:"is_pinned"`
	CreatedAt   time.Time  `json:"created_at"`
}

// ─── WebSocket wire protocol ────────────────────────────────────────────────

// WSEventType labels every WebSocket message.
type WSEventType string

const (
	WSEventSendMsg      WSEventType = "send_message"
	WSEventSendGroupMsg WSEventType = "send_group_message"
	WSEventNewMsg       WSEventType = "new_message"
	WSEventDelivered    WSEventType = "message_delivered"
	WSEventRead         WSEventType = "message_read"
	WSEventPresence     WSEventType = "presence"
	WSEventUserTyping   WSEventType = "user_typing"
	WSEventConvSettingsUpdate WSEventType = "conversation_settings_updated"
	WSEventMessageDeleted WSEventType = "message_deleted"
	WSEventMessageEdited  WSEventType = "message_edited"
	WSEventMessageReacted WSEventType = "message_reacted"
	WSEventMessagePinned  WSEventType = "message_pinned"
	WSEventMessageUnpinned WSEventType = "message_unpinned"
	WSEventError        WSEventType = "error"
	WSEventPing         WSEventType = "ping"
	WSEventPong         WSEventType = "pong"
	WSEventDeviceSyncOffer     WSEventType = "device_sync_offer"
	WSEventDeviceSyncAnswer    WSEventType = "device_sync_answer"
	WSEventDeviceSyncCandidate WSEventType = "device_sync_candidate"
	WSEventP2POffer            WSEventType = "p2p_message_offer"
	WSEventP2PAnswer           WSEventType = "p2p_message_answer"
	WSEventP2PCandidate        WSEventType = "p2p_message_ice"
)

// WSEnvelope is the top-level wrapper for all WebSocket messages.
type WSEnvelope struct {
	Type    WSEventType `json:"type"`
	Payload interface{} `json:"payload"`
}

// SendMessagePayload is the payload the client sends for outgoing messages.
type SendMessagePayload struct {
	RecipientID string  `json:"recipient_id"`
	Ciphertext  string  `json:"ciphertext"`
	MsgType     MsgType `json:"msg_type"`
	RatchetKey  string  `json:"ratchet_key"`
	PrevCounter int     `json:"prev_counter"`
	Counter     int     `json:"counter"`
	ExpiresIn   int     `json:"expires_in"` // seconds; 0 = no expiry
}

// NewMessagePayload is pushed to the recipient over WebSocket.
type NewMessagePayload struct {
	MessageID   string     `json:"message_id"`
	SenderID    string     `json:"sender_id"`
	Ciphertext  string     `json:"ciphertext"`
	MsgType     MsgType    `json:"msg_type"`
	RatchetKey  string     `json:"ratchet_key"`
	PrevCounter int        `json:"prev_counter"`
	Counter     int        `json:"counter"`
	ExpiresAt   *time.Time `json:"expires_at,omitempty"`
	IsPinned    bool       `json:"is_pinned"`
	CreatedAt   time.Time  `json:"created_at"`
}

// PresencePayload is broadcast when a user connects or disconnects.
type PresencePayload struct {
	UserID     string     `json:"user_id"`
	Online     bool       `json:"online"`
	LastSeenAt *time.Time `json:"last_seen_at,omitempty"`
}
