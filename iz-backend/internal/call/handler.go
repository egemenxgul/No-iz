package call

import (
	"encoding/json"
	"net/http"
	"strconv"
	"time"

	"github.com/google/uuid"
	"github.com/rs/zerolog"
)

// callAuthKey mirrors auth package's context key to avoid import cycle.
type callAuthKey string

const userIDCtxKey callAuthKey = "user_id"

// Handler provides the REST API for calls (history, STUN/TURN config).
// WebRTC signaling is handled directly in the WS hub via CallSvc interface.
type Handler struct {
	svc *Service
	log zerolog.Logger
}

// NewHandler creates a new call Handler.
func NewHandler(svc *Service, log zerolog.Logger) *Handler {
	return &Handler{svc: svc, log: log}
}

// CallHistory handles GET /api/calls — returns the user's call log.
func (h *Handler) CallHistory(w http.ResponseWriter, r *http.Request) {
	userIDStr, _ := r.Context().Value(userIDCtxKey).(string)
	userID, err := uuid.Parse(userIDStr)
	if err != nil {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	limit, _ := strconv.Atoi(r.URL.Query().Get("limit"))
	calls, err := h.svc.CallHistory(r.Context(), userID, limit)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "failed to fetch call history")
		return
	}
	writeJSON(w, http.StatusOK, map[string]interface{}{"calls": calls})
}

// TURNConfig handles GET /api/calls/turn — returns STUN/TURN server configuration.
// Clients must call this before initiating a WebRTC connection.
func (h *Handler) TURNConfig(w http.ResponseWriter, r *http.Request) {
	// Time-limited TURN credentials (rotate every 24h for security)
	// In production replace with a proper TURN credential service (e.g., Twilio, coturn)
	config := map[string]interface{}{
		"ice_servers": []map[string]interface{}{
			// Public STUN servers (Google)
			{"urls": []string{"stun:stun.l.google.com:19302", "stun:stun1.l.google.com:19302"}},
			// Public STUN servers (Cloudflare)
			{"urls": []string{"stun:stun.cloudflare.com:3478"}},
			// Add your coturn TURN server below when available:
			// {
			//   "urls":       []string{"turn:turn.no-iz.app:3478", "turns:turn.no-iz.app:5349"},
			//   "username":   "<generated-credential>",
			//   "credential": "<generated-hmac>",
			// },
		},
		"ice_transport_policy": "all",
		"valid_until":          time.Now().Add(24 * time.Hour).UTC(),
	}
	writeJSON(w, http.StatusOK, config)
}

// ─── helpers ─────────────────────────────────────────────────────────────────

func writeJSON(w http.ResponseWriter, status int, v interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(v)
}

func writeError(w http.ResponseWriter, status int, msg string) {
	writeJSON(w, status, map[string]string{"error": msg})
}
