package report

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
	r.Post("/", h.Submit)
	return r
}

func (h *Handler) Submit(w http.ResponseWriter, r *http.Request) {
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
		ReportedUserID      *string `json:"reported_user_id,omitempty"`
		ReportedCommunityID *string `json:"reported_community_id,omitempty"`
		Reason              string  `json:"reason"`
		Description         string  `json:"description"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		h.errorResponse(w, http.StatusBadRequest, "invalid request body")
		return
	}

	if req.Reason == "" {
		h.errorResponse(w, http.StatusBadRequest, "reason is required")
		return
	}

	var reportedUserID, reportedCommunityID *uuid.UUID

	if req.ReportedUserID != nil && *req.ReportedUserID != "" {
		parsed, err := uuid.Parse(*req.ReportedUserID)
		if err != nil {
			h.errorResponse(w, http.StatusBadRequest, "invalid reported user ID")
			return
		}
		reportedUserID = &parsed
	}

	if req.ReportedCommunityID != nil && *req.ReportedCommunityID != "" {
		parsed, err := uuid.Parse(*req.ReportedCommunityID)
		if err != nil {
			h.errorResponse(w, http.StatusBadRequest, "invalid reported community ID")
			return
		}
		reportedCommunityID = &parsed
	}

	if reportedUserID == nil && reportedCommunityID == nil {
		h.errorResponse(w, http.StatusBadRequest, "either reported_user_id or reported_community_id must be provided")
		return
	}

	if reportedUserID != nil && reportedCommunityID != nil {
		h.errorResponse(w, http.StatusBadRequest, "cannot report both a user and a community in the same report")
		return
	}

	rep := &Report{
		ReporterID:          myID,
		ReportedUserID:      reportedUserID,
		ReportedCommunityID: reportedCommunityID,
		Reason:              req.Reason,
		Description:         req.Description,
	}

	err = h.svc.SubmitReport(r.Context(), rep)
	if err != nil {
		h.errorResponse(w, http.StatusInternalServerError, "failed to submit report")
		return
	}

	h.jsonResponse(w, http.StatusCreated, rep)
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
