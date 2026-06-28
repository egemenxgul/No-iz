package economy

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
		log: log.With().Str("handler", "economy").Logger(),
	}
}

func (h *Handler) RegisterRoutes(r chi.Router) {
	r.Get("/subscription", h.GetSubscription)
	r.Post("/subscribe", h.Subscribe)
}

func (h *Handler) GetSubscription(w http.ResponseWriter, r *http.Request) {
	userIDStr, ok := auth.UserIDFromContext(r.Context())
	if !ok {
		h.respondError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	userID, _ := uuid.Parse(userIDStr)

	info, err := h.svc.GetUserSubscriptionDetails(r.Context(), userID)
	if err != nil {
		h.respondError(w, http.StatusInternalServerError, "failed to fetch subscription")
		return
	}

	features := GetFeatures(info.Tier)

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"tier":                info.Tier,
		"period_end":          info.PeriodEnd,
		"scheduled_downgrade": info.ScheduledDowngrade,
		"features":            features,
		"storage_used":        info.StorageUsedBytes,
		"storage_total":       features.MaxStorageBytes,
	})
}

func (h *Handler) Subscribe(w http.ResponseWriter, r *http.Request) {
	userIDStr, ok := auth.UserIDFromContext(r.Context())
	if !ok {
		h.respondError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	userID, _ := uuid.Parse(userIDStr)

	var p struct {
		Tier string `json:"tier"`
	}
	if err := json.NewDecoder(r.Body).Decode(&p); err != nil {
		h.respondError(w, http.StatusBadRequest, "invalid request")
		return
	}

	newTier := Tier(p.Tier)
	if newTier != TierFree && newTier != TierPlus && newTier != TierPro && newTier != TierElite {
		h.respondError(w, http.StatusBadRequest, "invalid tier")
		return
	}

	if err := h.svc.Subscribe(r.Context(), userID, newTier); err != nil {
		h.respondError(w, http.StatusInternalServerError, "failed to subscribe")
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]bool{"success": true})
}

func (h *Handler) respondError(w http.ResponseWriter, status int, msg string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(map[string]string{"error": msg})
}
