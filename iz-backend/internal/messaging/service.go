package messaging

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/rs/zerolog"
)

// PushNotificationSender defines the interface for triggering push notifications.
type PushNotificationSender interface {
	SendPush(ctx context.Context, userID uuid.UUID, title, body string, data map[string]string) error
}

// SocialRepository defines the interface for managing friendships from messaging.
type SocialRepository interface {
	EnsureFriendshipRecord(ctx context.Context, initiator, recipient uuid.UUID) error
	HasBlocked(ctx context.Context, blocker, blocked uuid.UUID) (bool, error)
}

// Service provides the business logic for the messaging system.
type Service struct {
	repo       *Repository
	hub        *Hub
	pushSvc    PushNotificationSender
	socialRepo SocialRepository
	log        zerolog.Logger
}

// NewService creates a new messaging Service.
func NewService(repo *Repository, hub *Hub, pushSvc PushNotificationSender, log zerolog.Logger) *Service {
	return &Service{
		repo:    repo,
		hub:     hub,
		pushSvc: pushSvc,
		log:     log.With().Str("svc", "messaging").Logger(),
	}
}

// SetSocialRepo sets the social repository to allow automatic request creation.
func (s *Service) SetSocialRepo(sr SocialRepository) {
	s.socialRepo = sr
}

// SendMessage persists a message and delivers it to the recipient if online.
func (s *Service) SendMessage(
	ctx context.Context,
	senderID, recipientID uuid.UUID,
	p *SendMessagePayload,
) (*Message, error) {
	// Guard: check if recipient has blocked the sender
	if s.socialRepo != nil {
		blocked, err := s.socialRepo.HasBlocked(ctx, recipientID, senderID)
		if err == nil && blocked {
			return nil, fmt.Errorf("this user has blocked you")
		}
	}

	if p.Ciphertext == "" {
		return nil, fmt.Errorf("ciphertext is required")
	}

	var expiresAt *time.Time
	if p.ExpiresIn > 0 {
		t := time.Now().Add(time.Duration(p.ExpiresIn) * time.Second)
		expiresAt = &t
	}

	msgType := p.MsgType
	if msgType == "" {
		msgType = MsgTypeText
	}

	msg := &Message{
		SenderID:    senderID,
		RecipientID: recipientID,
		Ciphertext:  p.Ciphertext,
		MsgType:     msgType,
		RatchetKey:  p.RatchetKey,
		PrevCounter: p.PrevCounter,
		Counter:     p.Counter,
		ExpiresAt:   expiresAt,
	}

	// Persist to DB (server stores ciphertext, is blind to plaintext)
	if err := s.repo.Save(ctx, msg); err != nil {
		return nil, fmt.Errorf("save message: %w", err)
	}

	// Automatically create or update a pending friendship request (message request)
	if s.socialRepo != nil {
		if err := s.socialRepo.EnsureFriendshipRecord(ctx, senderID, recipientID); err != nil {
			s.log.Error().Err(err).Str("sender", senderID.String()).Str("recipient", recipientID.String()).Msg("failed to ensure friendship record")
		}
	}

	// Attempt real-time delivery
	data := buildNewMessageJSON(msg)
	delivered := s.hub.Deliver(recipientID, data)
	if delivered {
		_ = s.repo.MarkDelivered(ctx, msg.ID)
	} else if s.pushSvc != nil {
		// Fetch sender's display name
		var senderName string
		displayName, err := s.repo.GetSenderName(ctx, senderID)
		if err != nil || displayName == "" {
			senderName = "Yeni Mesaj" // Fallback title
		} else {
			senderName = displayName
		}

		go func() {
			// Run in background goroutine with custom timeout context
			bgCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
			defer cancel()

			pushData := map[string]string{
				"type":       "new_message",
				"message_id": msg.ID.String(),
				"sender_id":  senderID.String(),
			}

			_ = s.pushSvc.SendPush(bgCtx, recipientID, senderName, "Sana şifreli bir mesaj gönderdi.", pushData)
		}()
	}
	// If not delivered, the message stays in DB; flushPending handles it on reconnect

	s.log.Info().
		Str("msg_id", msg.ID.String()).
		Str("sender", senderID.String()).
		Str("recipient", recipientID.String()).
		Bool("ws_delivered", delivered).
		Msg("message sent")

	return msg, nil
}
