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

	r.Post("/vault", h.SaveVault)
	r.Get("/vault/{convID}", h.GetVault)

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

func (h *Handler) SaveVault(w http.ResponseWriter, r *http.Request) {
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
		Messages []VaultMessage `json:"messages"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		h.errorResponse(w, http.StatusBadRequest, "invalid request body")
		return
	}

	if len(req.Messages) == 0 {
		h.errorResponse(w, http.StatusBadRequest, "no messages provided")
		return
	}

	err = h.svc.SaveVaultMessages(r.Context(), myID, req.Messages)
	if err != nil {
		h.errorResponse(w, http.StatusInternalServerError, "failed to save vault messages")
		return
	}

	h.jsonResponse(w, http.StatusOK, map[string]string{"status": "ok"})
}

func (h *Handler) GetVault(w http.ResponseWriter, r *http.Request) {
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

	convIDStr := chi.URLParam(r, "convID")
	convID, err := uuid.Parse(convIDStr)
	if err != nil {
		h.errorResponse(w, http.StatusBadRequest, "invalid conversation ID")
		return
	}

	limit := 50
	offset := 0

	msgs, err := h.svc.GetVaultMessages(r.Context(), myID, convID, limit, offset)
	if err != nil {
		h.errorResponse(w, http.StatusInternalServerError, "failed to get vault messages")
		return
	}

	h.jsonResponse(w, http.StatusOK, map[string]interface{}{"messages": msgs})
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
