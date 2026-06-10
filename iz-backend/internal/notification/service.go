package notification

import (
	"context"
	"fmt"

	"os"

	firebase "firebase.google.com/go/v4"
	"firebase.google.com/go/v4/messaging"
	"google.golang.org/api/option"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/rs/zerolog"
)

type Service struct {
	db        *pgxpool.Pool
	repo      *Repository
	log       zerolog.Logger
	fcmClient *messaging.Client
}

type PushPayload struct {
	Title string            `json:"title"`
	Body  string            `json:"body"`
	Data  map[string]string `json:"data,omitempty"`
}

func NewService(db *pgxpool.Pool, repo *Repository, log zerolog.Logger) *Service {
	logger := log.With().Str("svc", "notification").Logger()
	
	svc := &Service{
		db:   db,
		repo: repo,
		log:  logger,
	}

	// Try to initialize Firebase Admin SDK
	ctx := context.Background()
	var opt option.ClientOption
	if _, err := os.Stat("firebase_credentials.json"); err == nil {
		opt = option.WithCredentialsFile("firebase_credentials.json")
		app, err := firebase.NewApp(ctx, nil, opt)
		if err == nil {
			fcmClient, err := app.Messaging(ctx)
			if err == nil {
				svc.fcmClient = fcmClient
				logger.Info().Msg("Firebase Admin SDK initialized successfully")
			} else {
				logger.Warn().Err(err).Msg("failed to initialize FCM client, falling back to mock push")
			}
		} else {
			logger.Warn().Err(err).Msg("failed to initialize Firebase App, falling back to mock push")
		}
	} else {
		logger.Info().Msg("firebase_credentials.json not found, using mock push notifications")
	}

	return svc
}

// SendPush sends push notifications to all registered devices of a user.
func (s *Service) SendPush(ctx context.Context, userID uuid.UUID, title, body string, data map[string]string) error {
	// Query user devices
	rows, err := s.db.Query(ctx, `
		SELECT id, device_token, platform 
		FROM user_devices 
		WHERE user_id = $1 AND device_token IS NOT NULL AND device_token != ''`,
		userID,
	)
	if err != nil {
		return fmt.Errorf("query user devices: %w", err)
	}
	defer rows.Close()

	type device struct {
		id       uuid.UUID
		token    string
		platform string
	}

	var devices []device
	for rows.Next() {
		var d device
		if err := rows.Scan(&d.id, &d.token, &d.platform); err != nil {
			continue
		}
		devices = append(devices, d)
	}

	if len(devices) == 0 {
		s.log.Debug().Str("user_id", userID.String()).Msg("no registered device tokens for user")
		return nil
	}

	for _, d := range devices {
		// Log sending push
		s.log.Info().
			Str("user_id", userID.String()).
			Str("device_id", d.id.String()).
			Str("platform", d.platform).
			Msg("sending push notification")

		// Send notification based on platform
		var err error
		if d.platform == "ios" {
			err = s.sendAPNs(ctx, d.token, title, body, data)
		} else {
			err = s.sendFCM(ctx, d.token, title, body, data)
		}

		if err != nil {
			s.log.Error().Err(err).Str("device_token", d.token).Msg("failed to send push, removing stale token")
			// Clean up stale token (unregistered or expired token)
			_, _ = s.db.Exec(ctx, `DELETE FROM user_devices WHERE id = $1`, d.id)
		}
	}

	return nil
}

// sendFCM mocks or sends a real HTTP request to FCM
func (s *Service) sendFCM(ctx context.Context, token, title, body string, data map[string]string) error {
	if s.fcmClient != nil {
		message := &messaging.Message{
			Token: token,
			Notification: &messaging.Notification{
				Title: title,
				Body:  body,
			},
			Data: data,
		}
		_, err := s.fcmClient.Send(ctx, message)
		if err != nil {
			return err
		}
		s.log.Info().Str("token", token).Str("title", title).Msg("FCM Push Dispatched (Real API Call)")
		return nil
	}

	// Mock mode
	s.log.Info().Str("token", token).Str("title", title).Msg("FCM Push Dispatched (Simulated REST API Call)")
	return nil
}

// sendAPNs mocks or sends a real HTTP request to APNs
func (s *Service) sendAPNs(ctx context.Context, token, title, body string, data map[string]string) error {
	s.log.Info().Str("token", token).Str("title", title).Msg("APNs Push Dispatched (Simulated HTTP/2 REST API Call)")
	return nil
}

// CreateNotification persists a notification in the database and dispatches it via push notifications.
func (s *Service) CreateNotification(ctx context.Context, userID uuid.UUID, title, body string, data map[string]string) (*Notification, error) {
	n := &Notification{
		UserID: userID,
		Title:  title,
		Body:   body,
		Data:   data,
	}

	if err := s.repo.Save(ctx, n); err != nil {
		return nil, fmt.Errorf("save notification record: %w", err)
	}

	// Send Push Notification asynchronously to not block the caller
	go func() {
		bgCtx := context.Background()
		if err := s.SendPush(bgCtx, userID, title, body, data); err != nil {
			s.log.Error().Err(err).Str("user_id", userID.String()).Msg("failed to dispatch push notification")
		}
	}()

	return n, nil
}
