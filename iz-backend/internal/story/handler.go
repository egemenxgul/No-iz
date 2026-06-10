package story

import (
	"encoding/json"
	"net/http"

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

	r.Post("/", h.Create)
	r.Get("/", h.GetFeed)
	r.Delete("/{storyID}", h.Delete)

	return r
}

func (h *Handler) Create(w http.ResponseWriter, r *http.Request) {
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

	var req struct {
		MediaURL  string `json:"media_url"`
		Caption   string `json:"caption"`
		MediaType string `json:"media_type"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		h.errorResponse(w, http.StatusBadRequest, "invalid request body")
		return
	}

	if req.MediaURL == "" {
		h.errorResponse(w, http.StatusBadRequest, "media_url is required")
		return
	}

	if req.MediaType == "" {
		req.MediaType = "image"
	}

	story := &Story{
		UserID:    myID,
		MediaURL:  req.MediaURL,
		Caption:   req.Caption,
		MediaType: req.MediaType,
	}

	err = h.svc.CreateStory(r.Context(), story)
	if err != nil {
		h.errorResponse(w, http.StatusInternalServerError, "failed to post story")
		return
	}

	h.jsonResponse(w, http.StatusCreated, story)
}

func (h *Handler) GetFeed(w http.ResponseWriter, r *http.Request) {
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

	feed, err := h.svc.GetFeed(r.Context(), myID)
	if err != nil {
		h.errorResponse(w, http.StatusInternalServerError, "failed to load story feed")
		return
	}

	h.jsonResponse(w, http.StatusOK, feed)
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

	storyIDStr := chi.URLParam(r, "storyID")
	storyID, err := uuid.Parse(storyIDStr)
	if err != nil {
		h.errorResponse(w, http.StatusBadRequest, "invalid story ID")
		return
	}

	err = h.svc.DeleteStory(r.Context(), storyID, myID)
	if err != nil {
		h.errorResponse(w, http.StatusInternalServerError, "failed to delete story")
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
