package backup

import (
	"encoding/json"
	"errors"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
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

	r.Post("/", h.Save)
	r.Get("/", h.Get)

	return r
}

func (h *Handler) Save(w http.ResponseWriter, r *http.Request) {
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
		EncryptedBlob string `json:"encrypted_blob"`
		Salt          string `json:"salt"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		h.errorResponse(w, http.StatusBadRequest, "invalid request body")
		return
	}

	if req.EncryptedBlob == "" || req.Salt == "" {
		h.errorResponse(w, http.StatusBadRequest, "encrypted_blob and salt are required")
		return
	}

	b := &Backup{
		UserID:        myID,
		EncryptedBlob: req.EncryptedBlob,
		Salt:          req.Salt,
	}

	err = h.svc.SaveBackup(r.Context(), b)
	if err != nil {
		h.errorResponse(w, http.StatusInternalServerError, "failed to save backup")
		return
	}

	h.jsonResponse(w, http.StatusOK, b)
}

func (h *Handler) Get(w http.ResponseWriter, r *http.Request) {
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

	b, err := h.svc.GetBackup(r.Context(), myID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			h.errorResponse(w, http.StatusNotFound, "no backup found")
			return
		}
		h.errorResponse(w, http.StatusInternalServerError, "failed to retrieve backup")
		return
	}

	h.jsonResponse(w, http.StatusOK, b)
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
