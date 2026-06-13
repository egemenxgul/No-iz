package auth

import (
	"sync"
	"time"

	"github.com/rs/zerolog"
)

// QRHub manages payloads for Web clients waiting to be linked via QR code.
type QRHub struct {
	payloads map[string]interface{}
	mu       sync.RWMutex
	log      zerolog.Logger
}

func NewQRHub(log zerolog.Logger) *QRHub {
	return &QRHub{
		payloads: make(map[string]interface{}),
		log:      log.With().Str("component", "qr_hub").Logger(),
	}
}

// StorePayload saves the payload for a specific QR token
func (h *QRHub) StorePayload(token string, payload interface{}) {
	h.mu.Lock()
	h.payloads[token] = payload
	h.mu.Unlock()

	// Auto-cleanup after 60 seconds
	go func() {
		time.Sleep(60 * time.Second)
		h.mu.Lock()
		delete(h.payloads, token)
		h.mu.Unlock()
	}()
}

// GetPayload checks if a payload exists for a token, returns it, and deletes it.
func (h *QRHub) GetPayload(token string) (interface{}, bool) {
	h.mu.Lock()
	defer h.mu.Unlock()

	payload, ok := h.payloads[token]
	if ok {
		delete(h.payloads, token)
	}
	return payload, ok
}
