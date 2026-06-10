package social

import (
	"encoding/json"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/no-iz/iz-backend/internal/auth"
	"github.com/rs/zerolog"
)

// Handler handles HTTP requests for friendship and message requests.
type Handler struct {
	svc *Service
	log zerolog.Logger
}

// NewHandler creates a new Handler.
func NewHandler(svc *Service, log zerolog.Logger) *Handler {
	return &Handler{
		svc: svc,
		log: log,
	}
}

// Routes returns the chi router for the social/friendship endpoints.
func (h *Handler) Routes() chi.Router {
	r := chi.NewRouter()

	// These routes will be mounted under /api/friends by the main server
	r.Post("/accept/{userID}", h.Accept)
	r.Post("/reject/{userID}", h.Reject)
	r.Post("/block/{userID}", h.Block)
	r.Post("/unblock/{userID}", h.Unblock)
	r.Get("/status", h.Status)

	return r
}

// Accept handles POST /api/friends/accept/{userID}
func (h *Handler) Accept(w http.ResponseWriter, r *http.Request) {
	myIDStr, ok := auth.UserIDFromContext(r.Context())
	if !ok {
		h.errorResponse(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	myID, err := uuid.Parse(myIDStr)
	if err != nil {
		h.errorResponse(w, http.StatusUnauthorized, "invalid user ID")
		return
	}

	otherIDStr := chi.URLParam(r, "userID")
	otherID, err := uuid.Parse(otherIDStr)
	if err != nil {
		h.errorResponse(w, http.StatusBadRequest, "invalid other user ID")
		return
	}

	err = h.svc.AcceptRequest(r.Context(), myID, otherID)
	if err != nil {
		h.errorResponse(w, http.StatusInternalServerError, "failed to accept request")
		return
	}

	h.jsonResponse(w, http.StatusOK, map[string]string{"status": "accepted"})
}

// Reject handles POST /api/friends/reject/{userID}
func (h *Handler) Reject(w http.ResponseWriter, r *http.Request) {
	myIDStr, ok := auth.UserIDFromContext(r.Context())
	if !ok {
		h.errorResponse(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	myID, err := uuid.Parse(myIDStr)
	if err != nil {
		h.errorResponse(w, http.StatusUnauthorized, "invalid user ID")
		return
	}

	otherIDStr := chi.URLParam(r, "userID")
	otherID, err := uuid.Parse(otherIDStr)
	if err != nil {
		h.errorResponse(w, http.StatusBadRequest, "invalid other user ID")
		return
	}

	err = h.svc.RejectRequest(r.Context(), myID, otherID)
	if err != nil {
		h.errorResponse(w, http.StatusInternalServerError, "failed to reject request")
		return
	}

	h.jsonResponse(w, http.StatusOK, map[string]string{"status": "rejected"})
}

// Status handles GET /api/friends/status?with={userID}
func (h *Handler) Status(w http.ResponseWriter, r *http.Request) {
	myIDStr, ok := auth.UserIDFromContext(r.Context())
	if !ok {
		h.errorResponse(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	myID, err := uuid.Parse(myIDStr)
	if err != nil {
		h.errorResponse(w, http.StatusUnauthorized, "invalid user ID")
		return
	}

	otherIDStr := r.URL.Query().Get("with")
	otherID, err := uuid.Parse(otherIDStr)
	if err != nil {
		h.errorResponse(w, http.StatusBadRequest, "invalid with parameter")
		return
	}

	status, err := h.svc.GetStatus(r.Context(), myID, otherID)
	if err != nil {
		h.errorResponse(w, http.StatusInternalServerError, "failed to get status")
		return
	}

	h.jsonResponse(w, http.StatusOK, status)
}

// Helpers
func (h *Handler) errorResponse(w http.ResponseWriter, status int, message string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(map[string]string{"error": message})
}

func (h *Handler) jsonResponse(w http.ResponseWriter, status int, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(data)
}

// Block handles POST /api/friends/block/{userID}
func (h *Handler) Block(w http.ResponseWriter, r *http.Request) {
	myIDStr, ok := auth.UserIDFromContext(r.Context())
	if !ok {
		h.errorResponse(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	myID, err := uuid.Parse(myIDStr)
	if err != nil {
		h.errorResponse(w, http.StatusUnauthorized, "invalid user ID")
		return
	}

	otherIDStr := chi.URLParam(r, "userID")
	otherID, err := uuid.Parse(otherIDStr)
	if err != nil {
		h.errorResponse(w, http.StatusBadRequest, "invalid other user ID")
		return
	}

	err = h.svc.BlockUser(r.Context(), myID, otherID)
	if err != nil {
		h.errorResponse(w, http.StatusInternalServerError, "failed to block user")
		return
	}

	h.jsonResponse(w, http.StatusOK, map[string]string{"status": "blocked"})
}

// Unblock handles POST /api/friends/unblock/{userID}
func (h *Handler) Unblock(w http.ResponseWriter, r *http.Request) {
	myIDStr, ok := auth.UserIDFromContext(r.Context())
	if !ok {
		h.errorResponse(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	myID, err := uuid.Parse(myIDStr)
	if err != nil {
		h.errorResponse(w, http.StatusUnauthorized, "invalid user ID")
		return
	}

	otherIDStr := chi.URLParam(r, "userID")
	otherID, err := uuid.Parse(otherIDStr)
	if err != nil {
		h.errorResponse(w, http.StatusBadRequest, "invalid other user ID")
		return
	}

	err = h.svc.UnblockUser(r.Context(), myID, otherID)
	if err != nil {
		h.errorResponse(w, http.StatusInternalServerError, "failed to unblock user")
		return
	}

	h.jsonResponse(w, http.StatusOK, map[string]string{"status": "unblocked"})
}
