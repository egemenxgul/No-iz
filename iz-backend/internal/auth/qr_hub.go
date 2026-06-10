package auth

import (
	"encoding/json"
	"net/http"
	"sync"
	"time"

	"github.com/gorilla/websocket"
	"github.com/rs/zerolog"
)

var upgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
	CheckOrigin: func(r *http.Request) bool {
		return true // Allowing all for QR auth, standard CORS applies elsewhere
	},
}

type qrClient struct {
	conn *websocket.Conn
	send chan []byte
}

// QRHub manages WebSocket connections for Web clients waiting to be linked via QR code.
type QRHub struct {
	clients map[string]*qrClient // token -> client
	mu      sync.RWMutex
	log     zerolog.Logger
}

func NewQRHub(log zerolog.Logger) *QRHub {
	return &QRHub{
		clients: make(map[string]*qrClient),
		log:     log.With().Str("component", "qr_hub").Logger(),
	}
}

func (h *QRHub) Register(token string, conn *websocket.Conn) {
	client := &qrClient{
		conn: conn,
		send: make(chan []byte, 5),
	}

	h.mu.Lock()
	h.clients[token] = client
	h.mu.Unlock()

	go h.writePump(token, client)
	go h.readPump(token, client)
}

func (h *QRHub) Unregister(token string) {
	h.mu.Lock()
	if client, ok := h.clients[token]; ok {
		delete(h.clients, token)
		close(client.send)
	}
	h.mu.Unlock()
}

// SendPayload sends the encrypted keys and new session to the waiting web client.
func (h *QRHub) SendPayload(token string, payload interface{}) bool {
	h.mu.RLock()
	client, ok := h.clients[token]
	h.mu.RUnlock()

	if !ok {
		return false
	}

	data, err := json.Marshal(payload)
	if err != nil {
		h.log.Error().Err(err).Msg("failed to marshal qr payload")
		return false
	}

	select {
	case client.send <- data:
		return true
	default:
		return false
	}
}

func (h *QRHub) writePump(token string, client *qrClient) {
	ticker := time.NewTicker(50 * time.Second)
	defer func() {
		ticker.Stop()
		client.conn.Close()
	}()

	for {
		select {
		case msg, ok := <-client.send:
			client.conn.SetWriteDeadline(time.Now().Add(10 * time.Second))
			if !ok {
				client.conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}

			w, err := client.conn.NextWriter(websocket.TextMessage)
			if err != nil {
				return
			}
			w.Write(msg)
			if err := w.Close(); err != nil {
				return
			}
		case <-ticker.C:
			client.conn.SetWriteDeadline(time.Now().Add(10 * time.Second))
			if err := client.conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}

func (h *QRHub) readPump(token string, client *qrClient) {
	defer func() {
		h.Unregister(token)
		client.conn.Close()
	}()

	client.conn.SetReadLimit(512)
	client.conn.SetReadDeadline(time.Now().Add(60 * time.Second))
	client.conn.SetPongHandler(func(string) error {
		client.conn.SetReadDeadline(time.Now().Add(60 * time.Second))
		return nil
	})

	for {
		_, _, err := client.conn.ReadMessage()
		if err != nil {
			break
		}
	}
}
