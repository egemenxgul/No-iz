package notification

import (
	"encoding/json"
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/no-iz/iz-backend/internal/auth"
	"github.com/rs/zerolog"
)

type Handler struct {
	svc *Service
	log zerolog.Logger
}

func NewHandler(svc *Service, log zerolog.Logger) *Handler {
	return &Handler{
		svc: svc,
		log: log,
	}
}

func (h *Handler) Routes() chi.Router {
	r := chi.NewRouter()
	r.Get("/", h.List)
	r.Post("/{id}/read", h.MarkRead)
	r.Post("/read-all", h.MarkAllRead)
	r.Delete("/{id}", h.Delete)
	return r
}

func (h *Handler) List(w http.ResponseWriter, r *http.Request) {
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

	limit, _ := strconv.Atoi(r.URL.Query().Get("limit"))
	offset, _ := strconv.Atoi(r.URL.Query().Get("offset"))

	notifications, err := h.svc.repo.ListForUser(r.Context(), myID, limit, offset)
	if err != nil {
		h.log.Error().Err(err).Str("user_id", myID.String()).Msg("failed to list notifications")
		h.errorResponse(w, http.StatusInternalServerError, "failed to fetch notifications")
		return
	}

	h.jsonResponse(w, http.StatusOK, map[string]interface{}{
		"notifications": notifications,
	})
}

func (h *Handler) MarkRead(w http.ResponseWriter, r *http.Request) {
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

	notificationID, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		h.errorResponse(w, http.StatusBadRequest, "invalid notification ID")
		return
	}

	err = h.svc.repo.MarkRead(r.Context(), myID, notificationID)
	if err != nil {
		h.log.Error().Err(err).Str("user_id", myID.String()).Msg("failed to mark notification as read")
		h.errorResponse(w, http.StatusInternalServerError, "failed to update notification")
		return
	}

	h.jsonResponse(w, http.StatusOK, map[string]string{"status": "read"})
}

func (h *Handler) MarkAllRead(w http.ResponseWriter, r *http.Request) {
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

	err = h.svc.repo.MarkAllRead(r.Context(), myID)
	if err != nil {
		h.log.Error().Err(err).Str("user_id", myID.String()).Msg("failed to mark all notifications as read")
		h.errorResponse(w, http.StatusInternalServerError, "failed to update notifications")
		return
	}

	h.jsonResponse(w, http.StatusOK, map[string]string{"status": "all_read"})
}

func (h *Handler) Delete(w http.ResponseWriter, r *http.Request) {
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

	notificationID, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		h.errorResponse(w, http.StatusBadRequest, "invalid notification ID")
		return
	}

	err = h.svc.repo.Delete(r.Context(), myID, notificationID)
	if err != nil {
		h.log.Error().Err(err).Str("user_id", myID.String()).Msg("failed to delete notification")
		h.errorResponse(w, http.StatusInternalServerError, "failed to delete notification")
		return
	}

	h.jsonResponse(w, http.StatusOK, map[string]string{"status": "deleted"})
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
