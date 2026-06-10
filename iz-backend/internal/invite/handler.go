package invite

import (
	"encoding/json"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/rs/zerolog"
)

// Handler handles HTTP requests for invites
type Handler struct {
	svc *Service
	log zerolog.Logger
}

// NewHandler creates a new invite handler
func NewHandler(svc *Service, log zerolog.Logger) *Handler {
	return &Handler{
		svc: svc,
		log: log,
	}
}

// Routes returns the router for the invite endpoints
func (h *Handler) Routes() chi.Router {
	r := chi.NewRouter()

	// These routes will be mounted under /api/invites by the main server
	// User routes (assuming auth middleware extracts userID into context)
	r.Group(func(r chi.Router) {
		// r.Use(authMiddleware)
		r.Post("/user", h.HandleCreateUserCode)
	})

	// Admin routes
	r.Group(func(r chi.Router) {
		// r.Use(authMiddleware)
		// r.Use(requireAdminMiddleware)
		r.Get("/admin", h.HandleListAdminCodes)
		r.Post("/admin", h.HandleCreateAdminCode)
	})

	return r
}

type CreateAdminCodeRequest struct {
	Code      string     `json:"code"`
	MaxUses   int        `json:"max_uses"`
	ExpiresAt *time.Time `json:"expires_at"`
}

func (h *Handler) HandleCreateAdminCode(w http.ResponseWriter, r *http.Request) {
	var req CreateAdminCodeRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		h.errorResponse(w, http.StatusBadRequest, "invalid request body")
		return
	}

	code, err := h.svc.CreateAdminCode(r.Context(), req.Code, req.MaxUses, req.ExpiresAt)
	if err != nil {
		h.errorResponse(w, http.StatusInternalServerError, err.Error())
		return
	}

	h.jsonResponse(w, http.StatusCreated, code)
}

func (h *Handler) HandleListAdminCodes(w http.ResponseWriter, r *http.Request) {
	codes, err := h.svc.ListAdminCodes(r.Context())
	if err != nil {
		h.errorResponse(w, http.StatusInternalServerError, "failed to list codes")
		return
	}

	h.jsonResponse(w, http.StatusOK, map[string]interface{}{"codes": codes})
}

func (h *Handler) HandleCreateUserCode(w http.ResponseWriter, r *http.Request) {
	// Extract userID from context (set by auth middleware)
	userIDStr := r.Context().Value("user_id").(string)
	userID, err := uuid.Parse(userIDStr)
	if err != nil {
		h.errorResponse(w, http.StatusUnauthorized, "invalid user id in token")
		return
	}

	code, err := h.svc.CreateUserCode(r.Context(), userID)
	if err != nil {
		if err == ErrQuotaExceeded {
			h.errorResponse(w, http.StatusTooManyRequests, err.Error())
			return
		}
		h.errorResponse(w, http.StatusInternalServerError, "failed to create code")
		return
	}

	h.jsonResponse(w, http.StatusCreated, code)
}

// Helpers
func (h *Handler) errorResponse(w http.ResponseWriter, status int, message string) {
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(map[string]string{"error": message})
}

func (h *Handler) jsonResponse(w http.ResponseWriter, status int, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(data)
}
