package messaging

import (
	"context"
	"encoding/json"
	"net/http"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/gorilla/websocket"
	"github.com/rs/zerolog"
)

const (
	writeWait      = 10 * time.Second
	pongWait       = 60 * time.Second
	pingPeriod     = 50 * time.Second
	maxMessageSize = 64 * 1024 // 64 KB
)

// allowedWSOrigins lists origins permitted to establish a WebSocket connection.
// Mobile clients send no Origin header so we also permit empty-origin requests
// (native app → not a browser CSRF risk).
var allowedWSOrigins = map[string]bool{
	"https://no-iz.app":        true,
	"https://www.no-iz.app":    true,
	"https://admin.no-iz.app":  true,
}

var upgrader = websocket.Upgrader{
	ReadBufferSize:  4096,
	WriteBufferSize: 4096,
	CheckOrigin: func(r *http.Request) bool {
		origin := r.Header.Get("Origin")
		// Native mobile clients and curl-style tools send no Origin — allow them.
		if origin == "" {
			return true
		}
		// Allow known web origins
		if allowedWSOrigins[origin] {
			return true
		}
		// Allow localhost for local development
		return strings.HasPrefix(origin, "http://localhost:") ||
			strings.HasPrefix(origin, "http://127.0.0.1:")
	},
}

// CallSvc is the interface for routing WebRTC signaling events via the WS hub.
type CallSvc interface {
	OfferRaw(ctx context.Context, callerID uuid.UUID, raw []byte) error
	AnswerRaw(ctx context.Context, calleeID uuid.UUID, raw []byte) error
	RejectRaw(ctx context.Context, calleeID uuid.UUID, raw []byte) error
	EndRaw(ctx context.Context, userID uuid.UUID, raw []byte) error
	RelayICERaw(ctx context.Context, fromID uuid.UUID, raw []byte) error
	GroupOfferRaw(ctx context.Context, fromID uuid.UUID, raw []byte) error
	GroupJoinRaw(ctx context.Context, userID uuid.UUID, raw []byte) error
	GroupLeaveRaw(ctx context.Context, userID uuid.UUID, raw []byte) error
	PromoteRaw(ctx context.Context, userID uuid.UUID, raw []byte) error
}

// GroupSvc is the interface the messaging handler uses to send group messages.
type GroupSvc interface {
	SendGroupMessageRaw(ctx context.Context, senderID uuid.UUID, raw []byte) (string, error)
}

// Handler provides the HTTP and WebSocket handlers for messaging.
type Handler struct {
	hub      *Hub
	repo     *Repository
	svc      *Service
	log      zerolog.Logger
	groupSvc GroupSvc // optional; set via SetGroupSvc after construction
	callSvc  CallSvc  // optional; set via SetCallSvc after construction
}

// NewHandler creates a new messaging Handler.
func NewHandler(hub *Hub, repo *Repository, svc *Service, log zerolog.Logger) *Handler {
	return &Handler{hub: hub, repo: repo, svc: svc, log: log}
}

// SetGroupSvc injects the group service after construction (breaks the import cycle).
func (h *Handler) SetGroupSvc(g GroupSvc) { h.groupSvc = g }

// SetCallSvc injects the call service after construction.
func (h *Handler) SetCallSvc(c CallSvc) { h.callSvc = c }

// ServeWS upgrades the HTTP connection to WebSocket and starts the client loop.
// The caller must have already authenticated and placed the userID in the context.
func (h *Handler) ServeWS(w http.ResponseWriter, r *http.Request) {
	// user_id is set by auth.Middleware using the "user_id" context key
	userIDStr, _ := r.Context().Value(authContextKey("user_id")).(string)
	if userIDStr == "" {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}
	userID, err := uuid.Parse(userIDStr)
	if err != nil {
		http.Error(w, "invalid user id", http.StatusUnauthorized)
		return
	}

	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		h.log.Error().Err(err).Msg("ws upgrade failed")
		return
	}

	c := &Client{
		UserID: userID,
		Send:   make(chan []byte, 256),
	}
	h.hub.Register(c)

	go h.writePump(c, conn)
	h.readPump(c, conn)
}

// readPump reads messages from the WebSocket and dispatches them.
func (h *Handler) readPump(c *Client, conn *websocket.Conn) {
	defer func() {
		h.hub.Unregister(c)
		conn.Close()
	}()

	conn.SetReadLimit(maxMessageSize)
	conn.SetReadDeadline(time.Now().Add(pongWait))
	conn.SetPongHandler(func(string) error {
		conn.SetReadDeadline(time.Now().Add(pongWait))
		return nil
	})

	for {
		_, raw, err := conn.ReadMessage()
		if err != nil {
			break
		}

		var env WSEnvelope
		if err := json.Unmarshal(raw, &env); err != nil {
			h.sendError(c, "invalid envelope")
			continue
		}

		switch env.Type {
		case WSEventSendMsg:
			h.handleSendMessage(c, env.Payload)
		case WSEventSendGroupMsg:
			h.handleSendGroupMessage(c, env.Payload)
		case WSEventRead:
			h.handleMarkRead(c, env.Payload)
		case WSEventUserTyping:
			h.handleUserTyping(c, env.Payload)
		case WSEventConvSettingsUpdate:
			h.handleConversationSettingsUpdated(c, env.Payload)
		case WSEventMessageEdited:
			h.handleEditMessage(c, env.Payload)
		case WSEventMessageReacted:
			h.handleReaction(c, env.Payload)
		case WSEventPing:
			h.sendTo(c, WSEnvelope{Type: WSEventPong})

		// ── WebRTC Signaling ────────────────────────────────────────
		case "call_offer":
			h.handleCall(c, "offer", raw)
		case "call_answer":
			h.handleCall(c, "answer", raw)
		case "call_reject":
			h.handleCall(c, "reject", raw)
		case "call_end":
			h.handleCall(c, "end", raw)
		case "ice_candidate":
			h.handleCall(c, "ice", raw)
		case "group_call_offer":
			h.handleCall(c, "group_offer", raw)
		case "group_call_join":
			h.handleCall(c, "group_join", raw)
		case "group_call_leave":
			h.handleCall(c, "group_leave", raw)
		case "call_promote":
			h.handleCall(c, "promote", raw)

		// ── WebRTC Device Sync ────────────────────────────────────
		case WSEventDeviceSyncOffer, WSEventDeviceSyncAnswer, WSEventDeviceSyncCandidate:
			h.handleDeviceSync(c, env.Type, raw)

		// ── P2P Messaging (Cloud Lock Bypass) ─────────────────────
		case WSEventP2POffer, WSEventP2PAnswer, WSEventP2PCandidate:
			h.handleP2PSignaling(c, env.Type, raw)

		// ── Group Crypto ───────────────────────────────────────────
		case "group_key_distribution":
			h.handleGroupKeyDistribution(c, env.Payload)
		}
	}
}

// writePump forwards queued messages to the WebSocket.
func (h *Handler) writePump(c *Client, conn *websocket.Conn) {
	ticker := time.NewTicker(pingPeriod)
	defer func() {
		ticker.Stop()
		conn.Close()
	}()

	for {
		select {
		case msg, ok := <-c.Send:
			conn.SetWriteDeadline(time.Now().Add(writeWait))
			if !ok {
				conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}
			w, err := conn.NextWriter(websocket.TextMessage)
			if err != nil {
				return
			}
			w.Write(msg)
			// Flush any additional queued messages in the same write
			n := len(c.Send)
			for i := 0; i < n; i++ {
				w.Write([]byte{'\n'})
				w.Write(<-c.Send)
			}
			w.Close()

		case <-ticker.C:
			conn.SetWriteDeadline(time.Now().Add(writeWait))
			if err := conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}

// ─── event handlers ──────────────────────────────────────────────────────────

func (h *Handler) handleSendMessage(c *Client, raw interface{}) {
	data, _ := json.Marshal(raw)
	var p SendMessagePayload
	if err := json.Unmarshal(data, &p); err != nil {
		h.sendError(c, "invalid send_message payload")
		return
	}

	// Guard: reject oversized ciphertext to prevent DB bloat (CWE-400).
	// 48 KB leaves room for the WS envelope overhead under the 64 KB frame limit.
	const maxCiphertextLen = 48 * 1024
	if len(p.Ciphertext) > maxCiphertextLen {
		h.sendError(c, "ciphertext exceeds maximum allowed size")
		return
	}

	recipientID, err := uuid.Parse(p.RecipientID)
	if err != nil {
		h.sendError(c, "invalid recipient_id")
		return
	}

	msg, err := h.svc.SendMessage(context.Background(), c.UserID, recipientID, &p)
	if err != nil {
		h.log.Error().Err(err).Msg("send message failed")
		h.sendError(c, "failed to send message")
		return
	}

	// Ack sender
	h.sendTo(c, WSEnvelope{
		Type: WSEventDelivered,
		Payload: map[string]string{
			"message_id": msg.ID.String(),
			"status":     "saved",
		},
	})
}

func (h *Handler) handleMarkRead(c *Client, raw interface{}) {
	data, _ := json.Marshal(raw)
	var p struct {
		MessageID string `json:"message_id"`
	}
	if err := json.Unmarshal(data, &p); err != nil {
		return
	}
	msgID, err := uuid.Parse(p.MessageID)
	if err != nil {
		return
	}

	// Persist read_at in DB
	if err := h.repo.MarkRead(context.Background(), msgID); err != nil {
		return
	}

	// Look up the message to find who sent it, so we can notify them.
	msg, err := h.repo.GetByID(context.Background(), msgID)
	if err != nil {
		return // message not found, silently ignore
	}

	// Push a read-receipt event to the original sender (if online) unless either party hides read receipts.
	_, _, _, meHideRead, _ := h.repo.GetPrivacySettings(context.Background(), c.UserID)
	_, _, _, otherHideRead, _ := h.repo.GetPrivacySettings(context.Background(), msg.SenderID)

	if !meHideRead && !otherHideRead {
		envelope, _ := json.Marshal(WSEnvelope{
			Type: WSEventRead,
			Payload: map[string]string{
				"message_id": msgID.String(),
				"reader_id":  c.UserID.String(),
			},
		})
		h.hub.Deliver(msg.SenderID, envelope)
	}
}

func (h *Handler) handleEditMessage(c *Client, raw interface{}) {
	data, _ := json.Marshal(raw)
	var p struct {
		MessageID     string `json:"message_id"`
		NewCiphertext string `json:"new_ciphertext"`
	}
	if err := json.Unmarshal(data, &p); err != nil {
		return
	}

	msgID, err := uuid.Parse(p.MessageID)
	if err != nil {
		return
	}

	// Fetch message
	msg, err := h.repo.GetByID(context.Background(), msgID)
	if err != nil || msg.SenderID != c.UserID {
		return // Not found or not owner
	}

	// Check time limit (15 mins)
	if time.Since(msg.CreatedAt) > 15*time.Minute {
		h.sendError(c, "Message can only be edited within 15 minutes of sending")
		return
	}

	if err := h.repo.EditMessage(context.Background(), msgID, c.UserID, p.NewCiphertext); err != nil {
		return
	}

	// Broadcast
	envelope, _ := json.Marshal(WSEnvelope{
		Type: WSEventMessageEdited,
		Payload: map[string]string{
			"message_id": msgID.String(),
			"new_ciphertext": p.NewCiphertext,
		},
	})
	h.hub.Deliver(msg.RecipientID, envelope)
	h.sendTo(c, WSEnvelope{
		Type: WSEventMessageEdited,
		Payload: map[string]string{
			"message_id": msgID.String(),
			"new_ciphertext": p.NewCiphertext,
		},
	})
}

func (h *Handler) handleReaction(c *Client, raw interface{}) {
	data, _ := json.Marshal(raw)
	var p struct {
		MessageID string `json:"message_id"`
		Reaction  string `json:"reaction"` // Empty string removes the reaction
	}
	if err := json.Unmarshal(data, &p); err != nil {
		return
	}

	msgID, err := uuid.Parse(p.MessageID)
	if err != nil {
		return
	}

	// Fetch message
	msg, err := h.repo.GetByID(context.Background(), msgID)
	if err != nil {
		return
	}

	// Only sender or recipient can react
	if msg.SenderID != c.UserID && msg.RecipientID != c.UserID {
		return
	}

	if err := h.repo.SetReaction(context.Background(), msgID, c.UserID, p.Reaction); err != nil {
		return
	}

	// Broadcast
	otherID := msg.RecipientID
	if msg.RecipientID == c.UserID {
		otherID = msg.SenderID
	}

	envelope, _ := json.Marshal(WSEnvelope{
		Type: WSEventMessageReacted,
		Payload: map[string]string{
			"message_id": msgID.String(),
			"user_id":    c.UserID.String(),
			"reaction":   p.Reaction,
		},
	})
	h.hub.Deliver(otherID, envelope)
	h.sendTo(c, WSEnvelope{
		Type: WSEventMessageReacted,
		Payload: map[string]string{
			"message_id": msgID.String(),
			"user_id":    c.UserID.String(),
			"reaction":   p.Reaction,
		},
	})
}

// handleCall dispatches a WebRTC signaling event to the call service.
func (h *Handler) handleCall(c *Client, action string, raw []byte) {
	if h.callSvc == nil {
		h.sendError(c, "call service not available")
		return
	}
	ctx := context.Background()
	var err error
	switch action {
	case "offer":
		err = h.callSvc.OfferRaw(ctx, c.UserID, raw)
	case "answer":
		err = h.callSvc.AnswerRaw(ctx, c.UserID, raw)
	case "reject":
		err = h.callSvc.RejectRaw(ctx, c.UserID, raw)
	case "end":
		err = h.callSvc.EndRaw(ctx, c.UserID, raw)
	case "ice":
		err = h.callSvc.RelayICERaw(ctx, c.UserID, raw)
	case "group_offer":
		err = h.callSvc.GroupOfferRaw(ctx, c.UserID, raw)
	case "group_join":
		err = h.callSvc.GroupJoinRaw(ctx, c.UserID, raw)
	case "group_leave":
		err = h.callSvc.GroupLeaveRaw(ctx, c.UserID, raw)
	case "promote":
		err = h.callSvc.PromoteRaw(ctx, c.UserID, raw)
	}
	if err != nil {
		h.log.Warn().Err(err).Str("action", action).Msg("call signaling error")
		h.sendError(c, err.Error())
	}
}

// handleSendGroupMessage routes group messages via the GroupSvc (injected at wire time).
func (h *Handler) handleSendGroupMessage(c *Client, raw interface{}) {
	if h.groupSvc == nil {
		h.sendError(c, "group messaging not available")
		return
	}
	data, _ := json.Marshal(raw)
	msgID, err := h.groupSvc.SendGroupMessageRaw(context.Background(), c.UserID, data)
	if err != nil {
		h.log.Error().Err(err).Msg("send group message failed")
		h.sendError(c, "failed to send group message")
		return
	}
	h.sendTo(c, WSEnvelope{
		Type:    "group_message_delivered",
		Payload: map[string]string{"message_id": msgID, "status": "saved"},
	})
}

func (h *Handler) handleGroupKeyDistribution(c *Client, raw interface{}) {
	data, _ := json.Marshal(raw)
	var p struct {
		TargetID string `json:"target_id"`
	}
	if err := json.Unmarshal(data, &p); err != nil {
		return
	}
	targetID, err := uuid.Parse(p.TargetID)
	if err != nil {
		return
	}
	
	// Relay to target
	type envelope struct {
		Type    string          `json:"type"`
		Payload json.RawMessage `json:"payload"`
	}
	relay, _ := json.Marshal(envelope{Type: "group_key_distribution", Payload: data})
	h.hub.Deliver(targetID, relay)
}

func (h *Handler) handleUserTyping(c *Client, raw interface{}) {
	data, _ := json.Marshal(raw)
	var p struct {
		RecipientID string `json:"recipient_id"`
		IsTyping    bool   `json:"is_typing"`
	}
	if err := json.Unmarshal(data, &p); err != nil {
		return
	}
	recipientID, err := uuid.Parse(p.RecipientID)
	if err != nil {
		return
	}

	// Mutuality: skip typing indicators if either party hides them
	_, _, meHideTyping, _, _ := h.repo.GetPrivacySettings(context.Background(), c.UserID)
	_, _, otherHideTyping, _, _ := h.repo.GetPrivacySettings(context.Background(), recipientID)

	if meHideTyping || otherHideTyping {
		return
	}

	// Relay the event directly to the recipient
	envelope, _ := json.Marshal(WSEnvelope{
		Type: WSEventUserTyping,
		Payload: map[string]interface{}{
			"sender_id": c.UserID.String(),
			"is_typing": p.IsTyping,
		},
	})
	h.hub.Deliver(recipientID, envelope)
}

func (h *Handler) handleConversationSettingsUpdated(c *Client, raw interface{}) {
	data, _ := json.Marshal(raw)
	var p struct {
		RecipientID          string `json:"recipient_id"`
		DisappearingDuration int    `json:"disappearing_duration"`
	}
	if err := json.Unmarshal(data, &p); err != nil {
		return
	}
	recipientID, err := uuid.Parse(p.RecipientID)
	if err != nil {
		return
	}

	// Relay the event directly to the recipient
	envelope, _ := json.Marshal(WSEnvelope{
		Type: WSEventConvSettingsUpdate,
		Payload: map[string]interface{}{
			"conversation_id":       c.UserID.String(),
			"disappearing_duration": p.DisappearingDuration,
		},
	})
	h.hub.Deliver(recipientID, envelope)
}

// ─── helpers ─────────────────────────────────────────────────────────────────

func (h *Handler) sendTo(c *Client, env WSEnvelope) {
	data, _ := json.Marshal(env)
	select {
	case c.Send <- data:
	default:
	}
}

func (h *Handler) sendError(c *Client, msg string) {
	h.sendTo(c, WSEnvelope{
		Type:    WSEventError,
		Payload: map[string]string{"error": msg},
	})
}

// buildNewMessageJSON builds the JSON bytes for a new_message event pushed to recipients.
func buildNewMessageJSON(m *Message) []byte {
	env := WSEnvelope{
		Type: WSEventNewMsg,
		Payload: NewMessagePayload{
			MessageID:   m.ID.String(),
			SenderID:    m.SenderID.String(),
			Ciphertext:  m.Ciphertext,
			MsgType:     m.MsgType,
			RatchetKey:  m.RatchetKey,
			PrevCounter: m.PrevCounter,
			Counter:     m.Counter,
			ExpiresAt:   m.ExpiresAt,
			CreatedAt:   m.CreatedAt,
		},
	}
	data, _ := json.Marshal(env)
	return data
}

// GetConversation handles GET /api/messages/:userID — cursor-paginated history.
func (h *Handler) GetConversation(w http.ResponseWriter, r *http.Request) {
	meStr, _ := r.Context().Value(authContextKey("user_id")).(string)
	me, err := uuid.Parse(meStr)
	if err != nil {
		http.Error(w, `{"error":"unauthorized"}`, http.StatusUnauthorized)
		return
	}

	otherStr := r.URL.Query().Get("with")
	other, err := uuid.Parse(otherStr)
	if err != nil {
		http.Error(w, `{"error":"invalid with param"}`, http.StatusBadRequest)
		return
	}

	var before time.Time
	if b := r.URL.Query().Get("before"); b != "" {
		before, _ = time.Parse(time.RFC3339Nano, b)
	}

	msgs, err := h.repo.Conversation(r.Context(), me, other, 50, before)
	if err != nil {
		http.Error(w, `{"error":"db error"}`, http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{"messages": msgs})
}

// PinMessage handles POST /api/messages/{id}/pin
func (h *Handler) PinMessage(w http.ResponseWriter, r *http.Request) {
	meStr, _ := r.Context().Value(authContextKey("user_id")).(string)
	me, err := uuid.Parse(meStr)
	if err != nil {
		http.Error(w, `{"error":"unauthorized"}`, http.StatusUnauthorized)
		return
	}

	msgIDStr := chi.URLParam(r, "id")
	msgID, err := uuid.Parse(msgIDStr)
	if err != nil {
		http.Error(w, `{"error":"invalid message id"}`, http.StatusBadRequest)
		return
	}

	// Verify ownership or participation
	msg, err := h.repo.GetByID(r.Context(), msgID)
	if err != nil {
		http.Error(w, `{"error":"message not found"}`, http.StatusNotFound)
		return
	}
	if msg.SenderID != me && msg.RecipientID != me {
		http.Error(w, `{"error":"forbidden"}`, http.StatusForbidden)
		return
	}

	if err := h.repo.PinMessage(r.Context(), msgID); err != nil {
		http.Error(w, `{"error":"failed to pin"}`, http.StatusInternalServerError)
		return
	}

	// Determine the other participant
	otherID := msg.RecipientID
	if me == msg.RecipientID {
		otherID = msg.SenderID
	}

	// Send WS event to the other participant
	payload := map[string]interface{}{
		"message_id": msgID.String(),
		"is_pinned":  true,
	}
	env := WSEnvelope{Type: WSEventMessagePinned, Payload: payload}
	data, _ := json.Marshal(env)
	h.hub.Deliver(otherID, data)

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]bool{"success": true})
}

// UnpinMessage handles DELETE /api/messages/{id}/pin
func (h *Handler) UnpinMessage(w http.ResponseWriter, r *http.Request) {
	meStr, _ := r.Context().Value(authContextKey("user_id")).(string)
	me, err := uuid.Parse(meStr)
	if err != nil {
		http.Error(w, `{"error":"unauthorized"}`, http.StatusUnauthorized)
		return
	}

	msgIDStr := chi.URLParam(r, "id")
	msgID, err := uuid.Parse(msgIDStr)
	if err != nil {
		http.Error(w, `{"error":"invalid message id"}`, http.StatusBadRequest)
		return
	}

	// Verify ownership or participation
	msg, err := h.repo.GetByID(r.Context(), msgID)
	if err != nil {
		http.Error(w, `{"error":"message not found"}`, http.StatusNotFound)
		return
	}
	if msg.SenderID != me && msg.RecipientID != me {
		http.Error(w, `{"error":"forbidden"}`, http.StatusForbidden)
		return
	}

	if err := h.repo.UnpinMessage(r.Context(), msgID); err != nil {
		http.Error(w, `{"error":"failed to unpin"}`, http.StatusInternalServerError)
		return
	}

	// Determine the other participant
	otherID := msg.RecipientID
	if me == msg.RecipientID {
		otherID = msg.SenderID
	}

	// Send WS event to the other participant
	payload := map[string]interface{}{
		"message_id": msgID.String(),
		"is_pinned":  false,
	}
	env := WSEnvelope{Type: WSEventMessageUnpinned, Payload: payload}
	data, _ := json.Marshal(env)
	h.hub.Deliver(otherID, data)

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]bool{"success": true})
}

// GetConversations handles GET /api/conversations — returns the list of active conversations.
func (h *Handler) GetConversations(w http.ResponseWriter, r *http.Request) {
	meStr, _ := r.Context().Value(authContextKey("user_id")).(string)
	me, err := uuid.Parse(meStr)
	if err != nil {
		http.Error(w, `{"error":"unauthorized"}`, http.StatusUnauthorized)
		return
	}

	conversations, err := h.repo.ListConversations(r.Context(), me)
	if err != nil {
		h.log.Error().Err(err).Msg("failed to list conversations")
		http.Error(w, `{"error":"db error"}`, http.StatusInternalServerError)
		return
	}

	// Fetch current user's privacy settings
	_, meHideOnline, _, _, _ := h.repo.GetPrivacySettings(r.Context(), me)

	for _, conv := range conversations {
		if otherID, ok := conv["other_user_id"].(uuid.UUID); ok {
			_, otherHideOnline, _, _, _ := h.repo.GetPrivacySettings(r.Context(), otherID)
			
			if meHideOnline || otherHideOnline {
				conv["is_online"] = false
			} else {
				conv["is_online"] = h.hub.IsOnline(otherID)
			}
		}
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{"conversations": conversations})
}

// DeleteMessage handles DELETE /api/messages/{id} — revoking a message for everyone.
func (h *Handler) DeleteMessage(w http.ResponseWriter, r *http.Request) {
	meStr, _ := r.Context().Value(authContextKey("user_id")).(string)
	me, err := uuid.Parse(meStr)
	if err != nil {
		http.Error(w, `{"error":"unauthorized"}`, http.StatusUnauthorized)
		return
	}

	msgIDStr := chi.URLParam(r, "id")
	msgID, err := uuid.Parse(msgIDStr)
	if err != nil {
		http.Error(w, `{"error":"invalid message id"}`, http.StatusBadRequest)
		return
	}

	msg, err := h.repo.GetByID(r.Context(), msgID)
	if err != nil {
		http.Error(w, `{"error":"message not found"}`, http.StatusNotFound)
		return
	}

	if msg.SenderID != me {
		http.Error(w, `{"error":"forbidden: not your message to delete"}`, http.StatusForbidden)
		return
	}

	// 2. Perform the database deletion/revocation
	if err := h.repo.RevokeMessage(r.Context(), msgID, me); err != nil {
		h.log.Error().Err(err).Str("message_id", msgID.String()).Msg("failed to revoke message")
		http.Error(w, `{"error":"database error"}`, http.StatusInternalServerError)
		return
	}

	// 3. Dispatch the WS revocation event to the recipient (if online)
	envelope, _ := json.Marshal(WSEnvelope{
		Type: WSEventMessageDeleted,
		Payload: map[string]string{
			"message_id":      msgID.String(),
			"conversation_id": me.String(), // for the recipient, conversation ID is the sender
		},
	})
	h.hub.Deliver(msg.RecipientID, envelope)

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]string{"status": "deleted"})
}

// ────────────────────────────────────────────────────────────────
// Chat Settings (Mute/Unmute)
// ────────────────────────────────────────────────────────────────

type muteChatRequest struct {
	TargetID string `json:"target_id"`
	Duration string `json:"duration"` // "8_hours", "1_week", "forever"
}

func (h *Handler) MuteChat(w http.ResponseWriter, r *http.Request) {
	meStr, _ := r.Context().Value(authContextKey("user_id")).(string)
	if meStr == "" {
		http.Error(w, `{"error":"unauthorized"}`, http.StatusUnauthorized)
		return
	}

	var req muteChatRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, `{"error":"invalid request body"}`, http.StatusBadRequest)
		return
	}

	var until *time.Time
	now := time.Now()
	switch req.Duration {
	case "8_hours":
		t := now.Add(8 * time.Hour)
		until = &t
	case "1_week":
		t := now.Add(7 * 24 * time.Hour)
		until = &t
	case "forever":
		until = nil
	default:
		http.Error(w, `{"error":"invalid duration"}`, http.StatusBadRequest)
		return
	}

	if err := h.repo.MuteChat(r.Context(), meStr, req.TargetID, until); err != nil {
		h.log.Error().Err(err).Msg("failed to mute chat")
		http.Error(w, `{"error":"internal error"}`, http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	w.Write([]byte(`{"success":true}`))
}

func (h *Handler) UnmuteChat(w http.ResponseWriter, r *http.Request) {
	meStr, _ := r.Context().Value(authContextKey("user_id")).(string)
	if meStr == "" {
		http.Error(w, `{"error":"unauthorized"}`, http.StatusUnauthorized)
		return
	}

	targetID := chi.URLParam(r, "targetID")
	if targetID == "" {
		http.Error(w, `{"error":"missing target id"}`, http.StatusBadRequest)
		return
	}

	if err := h.repo.UnmuteChat(r.Context(), meStr, targetID); err != nil {
		h.log.Error().Err(err).Msg("failed to unmute chat")
		http.Error(w, `{"error":"internal error"}`, http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	w.Write([]byte(`{"success":true}`))
}

// authContextKey mirrors the private context key type used in the auth package.
// We redeclare it here to avoid an import cycle (auth ↔ messaging).
type authContextKey string

// handleDeviceSync routes WebRTC signaling events for Device Sync (Web to Mobile).
// Since the sender and recipient are the SAME user, we just broadcast the payload to all clients of the user.
// The clients themselves must differentiate between themselves (e.g., Mobile ignores offers it didn't ask for, or checks device type).
func (h *Handler) handleDeviceSync(c *Client, eventType WSEventType, raw []byte) {
	// Deliver the raw payload back to all clients belonging to this user
	// (h.hub.Deliver will send it to c.UserID)
	// We need to parse raw to WSEnvelope and maybe inject the sender device ID if we had one.
	// For simplicity, we just broadcast it, and Web/Mobile handles ignore-self logic based on a randomly generated device ID in the payload.
	
	h.hub.Deliver(c.UserID, raw)
}

// handleP2PSignaling routes WebRTC signaling events for P2P messaging bypass.
func (h *Handler) handleP2PSignaling(c *Client, eventType WSEventType, raw []byte) {
	var env WSEnvelope
	if err := json.Unmarshal(raw, &env); err != nil {
		return
	}
	
	payloadMap, ok := env.Payload.(map[string]interface{})
	if !ok {
		return
	}
	
	targetIDStr, ok := payloadMap["target_id"].(string)
	if !ok {
		return
	}
	
	targetID, err := uuid.Parse(targetIDStr)
	if err != nil {
		return
	}
	
	// Deliver the raw payload directly to the target user (Cloud Lock Bypass)
	h.hub.Deliver(targetID, raw)
}

