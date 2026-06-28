package messaging

import (
	"context"
	"encoding/json"
	"sync"
	"time"

	"github.com/google/uuid"
	"github.com/rs/zerolog"
)

// Client represents one authenticated WebSocket connection.
type Client struct {
	UserID uuid.UUID
	Send   chan []byte // outbound message queue
}

// Hub manages all active WebSocket connections and message routing.
type Hub struct {
	mu      sync.RWMutex
	clients map[uuid.UUID]map[*Client]bool // userID → set of clients

	register   chan *Client
	unregister chan *Client
	broadcast  chan *delivery // targeted delivery

	repo *Repository
	log  zerolog.Logger
}

type delivery struct {
	recipientID uuid.UUID
	data        []byte
}

// NewHub creates and starts a Hub.
func NewHub(repo *Repository, log zerolog.Logger) *Hub {
	h := &Hub{
		clients:    make(map[uuid.UUID]map[*Client]bool),
		register:   make(chan *Client, 64),
		unregister: make(chan *Client, 64),
		broadcast:  make(chan *delivery, 512),
		repo:       repo,
		log:        log.With().Str("component", "ws_hub").Logger(),
	}
	go h.run()
	return h
}

// run is the Hub's main event loop — must run in a dedicated goroutine.
func (h *Hub) run() {
	for {
		select {
		case c := <-h.register:
			h.mu.Lock()
			if h.clients[c.UserID] == nil {
				h.clients[c.UserID] = make(map[*Client]bool)
			}
			h.clients[c.UserID][c] = true
			h.mu.Unlock()
			h.log.Info().Str("user_id", c.UserID.String()).Msg("client connected")

			// Deliver any pending (undelivered) messages from DB
			go h.flushPending(c)
			go h.broadcastPresence(c.UserID, true)

		case c := <-h.unregister:
			h.mu.Lock()
			wasRemoved := false
			if clients, ok := h.clients[c.UserID]; ok {
				if _, exists := clients[c]; exists {
					delete(clients, c)
					close(c.Send)
					wasRemoved = true
				}
				if len(clients) == 0 {
					delete(h.clients, c.UserID)
				}
			}
			h.mu.Unlock()
			if wasRemoved {
				h.log.Info().Str("user_id", c.UserID.String()).Msg("client disconnected")
				
				// Only broadcast offline if NO MORE clients exist
				h.mu.RLock()
				hasMoreClients := len(h.clients[c.UserID]) > 0
				h.mu.RUnlock()
				
				if !hasMoreClients {
					go h.broadcastPresence(c.UserID, false)
					go func(uid uuid.UUID) {
						if err := h.repo.UpdateLastSeen(context.Background(), uid); err != nil {
							h.log.Error().Err(err).Str("user_id", uid.String()).Msg("failed to update last seen")
						}
					}(c.UserID)
				}
			}

		case d := <-h.broadcast:
			h.mu.RLock()
			clients, online := h.clients[d.recipientID]
			var targets []*Client
			if online {
				for c := range clients {
					targets = append(targets, c)
				}
			}
			h.mu.RUnlock()
			
			if online {
				for _, c := range targets {
					select {
					case c.Send <- d.data:
					default:
						// Client's buffer full — drop
						h.log.Warn().Str("recipient", d.recipientID.String()).Msg("send buffer full, dropping ws delivery for one client")
					}
				}
			}
		}
	}
}

// Register adds a new client to the hub.
func (h *Hub) Register(c *Client) {
	h.register <- c
}

// Unregister removes a client from the hub.
func (h *Hub) Unregister(c *Client) {
	h.unregister <- c
}

// Deliver queues a message for targeted WebSocket delivery.
// Returns true if the recipient is currently online.
func (h *Hub) Deliver(recipientID uuid.UUID, data []byte) bool {
	h.mu.RLock()
	_, online := h.clients[recipientID]
	h.mu.RUnlock()

	if online {
		h.broadcast <- &delivery{recipientID: recipientID, data: data}
	}
	return online
}

// IsOnline reports whether the user has an active WebSocket connection.
func (h *Hub) IsOnline(userID uuid.UUID) bool {
	h.mu.RLock()
	defer h.mu.RUnlock()
	_, ok := h.clients[userID]
	return ok
}

// flushPending delivers all unread DB messages to a newly-connected client.
func (h *Hub) flushPending(c *Client) {
	msgs, err := h.repo.UndeliveredFor(context.Background(), c.UserID)
	if err != nil {
		h.log.Error().Err(err).Str("user_id", c.UserID.String()).Msg("failed to load pending messages")
		return
	}
	for _, m := range msgs {
		data := buildNewMessageJSON(m)
		select {
		case c.Send <- data:
			_ = h.repo.MarkDelivered(context.Background(), m.ID)
		default:
			break
		}
	}
}

// broadcastPresence broadcasts the presence of userID to all their conversation partners who are online.
func (h *Hub) broadcastPresence(userID uuid.UUID, online bool) {
	ctx := context.Background()

	_, hideOnline, _, _, err := h.repo.GetPrivacySettings(ctx, userID)
	if err == nil && hideOnline {
		return
	}

	partners, err := h.repo.GetConversationPartners(ctx, userID)
	if err != nil {
		h.log.Error().Err(err).Str("user_id", userID.String()).Msg("failed to get conversation partners for presence broadcast")
		return
	}

	var lastSeenAt *time.Time
	if !online {
		now := time.Now()
		lastSeenAt = &now
	}

	payload := PresencePayload{
		UserID:     userID.String(),
		Online:     online,
		LastSeenAt: lastSeenAt,
	}

	envelope := WSEnvelope{
		Type:    WSEventPresence,
		Payload: payload,
	}

	data, err := json.Marshal(envelope)
	if err != nil {
		h.log.Error().Err(err).Msg("failed to marshal presence notification")
		return
	}

	for _, partnerID := range partners {
		h.Deliver(partnerID, data)
	}
}
