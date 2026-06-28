package server

import (
	"encoding/json"
	"net/http"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/no-iz/iz-backend/internal/auth"
	"github.com/no-iz/iz-backend/internal/call"
	"github.com/no-iz/iz-backend/internal/community"
	"github.com/no-iz/iz-backend/internal/group"
	"github.com/no-iz/iz-backend/internal/invite"
	"github.com/no-iz/iz-backend/internal/media"
	"github.com/no-iz/iz-backend/internal/messaging"
	"github.com/no-iz/iz-backend/internal/notification"
	"github.com/no-iz/iz-backend/internal/social"
	"github.com/no-iz/iz-backend/internal/story"
	"github.com/no-iz/iz-backend/internal/report"
	"github.com/no-iz/iz-backend/internal/backup"
	"github.com/no-iz/iz-backend/internal/economy"
	"github.com/no-iz/iz-backend/pkg/config"
	"github.com/redis/go-redis/v9"
	"github.com/rs/zerolog"

	httpSwagger "github.com/swaggo/http-swagger"
	_ "github.com/no-iz/iz-backend/docs"
)

// Server holds the router and its dependencies.
type Server struct {
	cfg              *config.Config
	log              zerolog.Logger
	rdb              *redis.Client
	authSvc          *auth.Service
	inviteSvc        *invite.Service
	msgHandler       *messaging.Handler
	groupHandler     *group.Handler
	communityHandler *community.Handler
	callHandler      *call.Handler
	mediaHandler     *media.Handler
	socialHandler    *social.Handler
	storyHandler     *story.Handler
	reportHandler    *report.Handler
	backupHandler    *backup.Handler
	notificationHandler *notification.Handler
	economyHandler   *economy.Handler
}

// New creates a new Server.
func New(
	cfg *config.Config,
	log zerolog.Logger,
	rdb *redis.Client,
	authSvc *auth.Service,
	inviteSvc *invite.Service,
	msgHandler *messaging.Handler,
	groupHandler *group.Handler,
	communityHandler *community.Handler,
	callHandler *call.Handler,
	mediaHandler *media.Handler,
	socialHandler *social.Handler,
	storyHandler *story.Handler,
	reportHandler *report.Handler,
	backupHandler *backup.Handler,
	notificationHandler *notification.Handler,
	economyHandler *economy.Handler,
) *Server {
	return &Server{
		cfg:              cfg,
		log:              log,
		rdb:              rdb,
		authSvc:          authSvc,
		inviteSvc:        inviteSvc,
		msgHandler:       msgHandler,
		groupHandler:     groupHandler,
		communityHandler: communityHandler,
		callHandler:      callHandler,
		mediaHandler:     mediaHandler,
		socialHandler:    socialHandler,
		storyHandler:     storyHandler,
		reportHandler:    reportHandler,
		backupHandler:    backupHandler,
		notificationHandler: notificationHandler,
		economyHandler:   economyHandler,
	}
}

// Router builds and returns the chi router with all routes registered.
func (s *Server) Router() http.Handler {
	r := chi.NewRouter()

	// ── Rate limiters ──────────────────────────────────────────────
	// login:           10 attempts / 1 minute per IP  (brute-force protection)
	// register:        5  attempts / 10 minutes per IP (spam protection)
	// change-password: 5  attempts / 5 minutes per IP
	// refresh:         5  attempts / 1 minute per IP
	// search users:    30 requests / 1 minute per IP
	loginRL := NewRateLimiter(s.rdb, "rl:auth:login", 10, time.Minute)
	registerRL := NewRateLimiter(s.rdb, "rl:auth:register", 5, 10*time.Minute)
	changePwRL := NewRateLimiter(s.rdb, "rl:auth:changepw", 5, 5*time.Minute)
	changeEmailRL := NewRateLimiter(s.rdb, "rl:auth:changeemail", 5, 5*time.Minute)
	refreshRL := NewRateLimiter(s.rdb, "rl:auth:refresh", 5, time.Minute)
	searchRL := NewRateLimiter(s.rdb, "rl:users:search", 30, time.Minute)

	// ── Global middleware ──────────────────────────────────────────
	r.Use(middleware.RequestID)
	r.Use(middleware.RealIP)
	r.Use(s.zerologMiddleware())
	r.Use(middleware.Recoverer)
	r.Use(middleware.Timeout(30 * time.Second))
	r.Use(corsMiddleware)
	r.Use(securityHeadersMiddleware)
	// CWE-400: Limit JSON request bodies to 1 MB to prevent DoS attacks.
	// Media upload (/api/media/upload) overrides this limit internally (50 MB).
	r.Use(func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if r.Body != nil && r.URL.Path != "/api/media/upload" {
				r.Body = http.MaxBytesReader(w, r.Body, 1<<20) // 1 MB
			}
			next.ServeHTTP(w, r)
		})
	})

	// ── Public routes ──────────────────────────────────────────────
	r.Get("/api/health", auth.HealthCheck)

	// Swagger Documentation
	r.Get("/swagger/*", httpSwagger.Handler(
		httpSwagger.URL("/swagger/doc.json"),
	))

	// Auth (no token required) — rate-limited
	qrHub := auth.NewQRHub(s.log)
	authHandler := auth.NewHandler(s.authSvc, qrHub)
	r.With(registerRL.Middleware).Post("/api/auth/register", authHandler.Register)
	r.With(registerRL.Middleware).Post("/api/auth/passkey/register/begin", authHandler.PasskeyRegisterBegin)
	r.With(registerRL.Middleware).Post("/api/auth/passkey/register/finish", authHandler.PasskeyRegisterFinish)

	// Call Decline (Public / Stateless using decline_token)
	r.Post("/api/calls/{id}/decline", s.callHandler.DeclineCall)

	r.With(loginRL.Middleware).Post("/api/auth/login", authHandler.Login)
	r.With(loginRL.Middleware).Post("/api/auth/passkey/login/begin", authHandler.PasskeyLoginBegin)
	r.With(loginRL.Middleware).Post("/api/auth/passkey/login/finish", authHandler.PasskeyLoginFinish)
	
	r.With(loginRL.Middleware).Post("/api/auth/login/2fa", authHandler.Login2FA)
	r.With(refreshRL.Middleware).Post("/api/auth/refresh", authHandler.RefreshToken)

	// Protected routes (require auth token)
	r.With(s.authSvc.Middleware).Group(func(r chi.Router) {
		r.Post("/api/auth/pin/setup", authHandler.SetupPIN)
		r.Post("/api/auth/pin/verify", authHandler.VerifyPIN)
	})
	
	r.Post("/api/auth/pin/reset/request", authHandler.ResetPasswordWithPin)
	r.Get("/api/auth/qr-poll", authHandler.PollQRAuth) // HTTPS Polling endpoint for QR Auth
	r.Post("/api/auth/apple", authHandler.AppleSignIn)
	r.With(loginRL.Middleware).Post("/api/auth/forgot-password", authHandler.ForgotPassword)
	r.With(loginRL.Middleware).Post("/api/auth/reset-password", authHandler.ResetPassword)

	// ── Protected routes ───────────────────────────────────────────
	r.Group(func(r chi.Router) {
		r.Use(s.authSvc.Middleware)

		// Users
		r.Get("/api/users/me", s.meHandler)
		r.Put("/api/users/me", s.updateMeHandler)
		r.Get("/api/users/privacy", s.getPrivacyHandler)
		r.Put("/api/users/privacy", s.updatePrivacyHandler)
		r.Get("/api/users/export", authHandler.ExportData)
		r.Post("/api/users/delete-account", authHandler.DeleteAccount)
		r.With(searchRL.Middleware).Get("/api/users/search", authHandler.SearchUsers)
		r.Get("/api/users/{id}/bundle", authHandler.GetUserBundle)
		r.Post("/api/users/contacts", authHandler.MatchContacts)
		
		// QR Link Device (from mobile)
		r.Post("/api/auth/qr-link", authHandler.QRLinkDevice)

		// 2FA Setup
		r.Post("/api/auth/2fa/generate", authHandler.Generate2FA)
		r.Post("/api/auth/2fa/verify", authHandler.Verify2FA)

		// Device Registration (Push Notification Tokens)
		r.Post("/api/devices/register", authHandler.RegisterDevice)

		// PreKey management (Signal Protocol one-time prekey replenishment)
		r.Get("/api/auth/prekeys/count", authHandler.GetPrekeysCount)
		r.Post("/api/auth/prekeys", authHandler.ReplenishPrekeys)

		// Change password & email — rate-limited
		r.With(changePwRL.Middleware).Post("/api/auth/change-password", authHandler.ChangePassword)
		r.With(changeEmailRL.Middleware).Post("/api/auth/change-email", authHandler.ChangeEmail)

		// Invites — user route (any authenticated user)
		inviteHandler := invite.NewHandler(s.inviteSvc, s.log)
		r.Post("/api/invites/user", inviteHandler.HandleCreateUserCode)

		// Invites — admin-only routes
		r.Group(func(r chi.Router) {
			r.Use(s.authSvc.RequireAdmin)
			r.Get("/api/invites/admin", inviteHandler.HandleListAdminCodes)
			r.Post("/api/invites/admin", inviteHandler.HandleCreateAdminCode)
		})

		// ── Messaging ──────────────────────────────────────────────
		// WebSocket endpoint (upgrade happens inside handler)
		// REST: 1-1 conversation history
		r.Get("/api/ws", s.msgHandler.ServeWS)
		r.Get("/api/conversations", s.msgHandler.GetConversations)
		r.Get("/api/messages", s.msgHandler.GetConversation)
		r.Delete("/api/messages/{id}", s.msgHandler.DeleteMessage)
		r.Post("/api/messages/{id}/pin", s.msgHandler.PinMessage)
		r.Delete("/api/messages/{id}/pin", s.msgHandler.UnpinMessage)
		r.Post("/api/messages/mute", s.msgHandler.MuteChat)
		r.Delete("/api/messages/mute/{targetID}", s.msgHandler.UnmuteChat)

		// ── Social (Friends / Message Requests) ─────────────────────
		r.Mount("/api/friends", s.socialHandler.Routes())

		// ── Stories (Durum / Status) ───────────────────────────────
		r.Mount("/api/stories", s.storyHandler.Routes())

		// ── Reports (Şikayet) ──────────────────────────────────────
		r.Mount("/api/reports", s.reportHandler.Routes())

		// ── Backup (Yedekleme) ─────────────────────────────────────
		r.Mount("/api/backup", s.backupHandler.Routes())

		// ── Groups ─────────────────────────────────────────────────
		r.Mount("/api/groups", s.groupHandler.Routes())

		// ── Communities ────────────────────────────────────────────
		r.Mount("/api/communities", s.communityHandler.Routes())

		// ── Calls (signaling via WS; REST = history + TURN config) ─
		r.Get("/api/calls", s.callHandler.CallHistory)
		r.Get("/api/calls/turn", s.callHandler.TURNConfig)

		// ── Media Storage (MinIO) ──────────────────────────────────
		r.Post("/api/media/upload", s.mediaHandler.Upload)
		r.Get("/api/media/download/{key}", s.mediaHandler.Download)

		// ── Notifications ──────────────────────────────────────────
		r.Mount("/api/notifications", s.notificationHandler.Routes())
	})

	return r
}

// ── Handler stubs (will be replaced by proper handlers in future sprints) ──

func (s *Server) meHandler(w http.ResponseWriter, r *http.Request) {
	userID, ok := auth.UserIDFromContext(r.Context())
	if !ok {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusUnauthorized)
		_, _ = w.Write([]byte(`{"error":"unauthorized"}`))
		return
	}

	profile, err := s.authSvc.GetUserProfile(r.Context(), userID)
	if err != nil {
		s.log.Error().Err(err).Str("user_id", userID).Msg("get profile failed")
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusInternalServerError)
		_, _ = w.Write([]byte(`{"error":"internal server error"}`))
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(profile)
}

func (s *Server) updateMeHandler(w http.ResponseWriter, r *http.Request) {
	userID, ok := auth.UserIDFromContext(r.Context())
	if !ok {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusUnauthorized)
		_, _ = w.Write([]byte(`{"error":"unauthorized"}`))
		return
	}

	var req struct {
		DisplayName string `json:"display_name"`
		Bio         string `json:"bio"`
		AvatarURL   string `json:"avatar_url"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusBadRequest)
		_, _ = w.Write([]byte(`{"error":"invalid request body"}`))
		return
	}

	if req.DisplayName == "" {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusBadRequest)
		_, _ = w.Write([]byte(`{"error":"display name is required"}`))
		return
	}

	err := s.authSvc.UpdateUserProfile(r.Context(), userID, req.DisplayName, req.Bio, req.AvatarURL)
	if err != nil {
		s.log.Error().Err(err).Str("user_id", userID).Msg("update profile failed")
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusInternalServerError)
		_, _ = w.Write([]byte(`{"error":"internal server error"}`))
		return
	}

	// Fetch updated profile
	profile, err := s.authSvc.GetUserProfile(r.Context(), userID)
	if err != nil {
		s.log.Error().Err(err).Str("user_id", userID).Msg("fetch updated profile failed")
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusInternalServerError)
		_, _ = w.Write([]byte(`{"error":"internal server error"}`))
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(profile)
}

// ── Middleware helpers ─────────────────────────────────────────────────────

func (s *Server) zerologMiddleware() func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			ww := middleware.NewWrapResponseWriter(w, r.ProtoMajor)
			start := time.Now()
			
			// Inject logger with request_id into context
			reqID := middleware.GetReqID(r.Context())
			ctxLog := s.log.With().Str("request_id", reqID).Logger()
			ctx := ctxLog.WithContext(r.Context())
			
			next.ServeHTTP(ww, r.WithContext(ctx))
			
			ctxLog.Info().
				Str("method", r.Method).
				Str("path", r.URL.Path).
				Int("status", ww.Status()).
				Dur("latency", time.Since(start)).
				Msg("request")
		})
	}
}

// allowedOrigins lists the origins permitted to make cross-origin requests.
// In production these should be set via the ALLOWED_ORIGINS env var (comma-separated).
var allowedOrigins = []string{
	"https://no-iz.app",
	"https://www.no-iz.app",
	"https://admin.no-iz.app",
}

func corsMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		origin := r.Header.Get("Origin")
		if isAllowedOrigin(origin) {
			w.Header().Set("Access-Control-Allow-Origin", origin)
			w.Header().Set("Vary", "Origin")
		}
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Authorization, Content-Type, X-Request-ID")
		w.Header().Set("Access-Control-Allow-Credentials", "true")

		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		next.ServeHTTP(w, r)
	})
}

// isAllowedOrigin checks whether the given origin is in the allowedOrigins list.
// Also allows localhost origins for local development.
func isAllowedOrigin(origin string) bool {
	if origin == "" {
		return false
	}
	for _, allowed := range allowedOrigins {
		if origin == allowed {
			return true
		}
	}
	// Allow localhost / 127.0.0.1 for local development
	return strings.HasPrefix(origin, "http://localhost:") ||
		strings.HasPrefix(origin, "http://127.0.0.1:")
}

// securityHeadersMiddleware injects security-hardening HTTP response headers (CWE-693).
// These headers protect against MIME sniffing, clickjacking, information leakage,
// and unnecessary browser feature access.
func securityHeadersMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Prevent browsers from MIME-sniffing response content type.
		w.Header().Set("X-Content-Type-Options", "nosniff")
		// Prevent the page from being embedded in an iframe (clickjacking).
		w.Header().Set("X-Frame-Options", "DENY")
		// Only send the origin part of the URL when navigating cross-origin.
		w.Header().Set("Referrer-Policy", "strict-origin-when-cross-origin")
		// Disable potentially dangerous browser features.
		w.Header().Set("Permissions-Policy", "camera=(), microphone=(), geolocation=()")
		// Legacy XSS protection header for older browsers.
		w.Header().Set("X-XSS-Protection", "1; mode=block")
		// HTTP Strict Transport Security — enforce HTTPS for 2 years (CWE-319).
		w.Header().Set("Strict-Transport-Security", "max-age=63072000; includeSubDomains; preload")
		// Content-Security-Policy for the API (restricts where resources can be loaded from).
		w.Header().Set("Content-Security-Policy", "default-src 'none'; frame-ancestors 'none'")
		next.ServeHTTP(w, r)
	})
}

func (s *Server) getPrivacyHandler(w http.ResponseWriter, r *http.Request) {
	userID, ok := auth.UserIDFromContext(r.Context())
	if !ok {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusUnauthorized)
		_, _ = w.Write([]byte(`{"error":"unauthorized"}`))
		return
	}

	settings, err := s.authSvc.GetPrivacySettings(r.Context(), userID)
	if err != nil {
		s.log.Error().Err(err).Str("user_id", userID).Msg("get privacy settings failed")
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusInternalServerError)
		_, _ = w.Write([]byte(`{"error":"internal server error"}`))
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(settings)
}

func (s *Server) updatePrivacyHandler(w http.ResponseWriter, r *http.Request) {
	userID, ok := auth.UserIDFromContext(r.Context())
	if !ok {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusUnauthorized)
		_, _ = w.Write([]byte(`{"error":"unauthorized"}`))
		return
	}

	var req auth.PrivacySettings
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusBadRequest)
		_, _ = w.Write([]byte(`{"error":"invalid request body"}`))
		return
	}

	err := s.authSvc.UpdatePrivacySettings(r.Context(), userID, &req)
	if err != nil {
		s.log.Error().Err(err).Str("user_id", userID).Msg("update privacy settings failed")
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusInternalServerError)
		_, _ = w.Write([]byte(`{"error":"internal server error"}`))
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(req)
}

