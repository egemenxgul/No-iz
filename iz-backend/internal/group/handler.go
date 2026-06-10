package group

import (
	"encoding/json"
	"errors"
	"net/http"
	"strconv"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/rs/zerolog"
)

// authKey mirrors the context key type used in auth.Middleware to avoid import cycle.
type authKey string

const userIDCtxKey authKey = "user_id"

// Handler provides HTTP handlers for group REST endpoints.
type Handler struct {
	svc *Service
	log zerolog.Logger
}

// NewHandler creates a new group Handler.
func NewHandler(svc *Service, log zerolog.Logger) *Handler {
	return &Handler{svc: svc, log: log}
}

// Routes returns a chi.Router with all group endpoints.
func (h *Handler) Routes() chi.Router {
	r := chi.NewRouter()

	// Group CRUD
	r.Post("/", h.CreateGroup)
	r.Get("/", h.ListUserGroups)
	r.Get("/{groupID}", h.GetGroup)

	// Membership
	r.Post("/join/{token}", h.JoinByInvite)
	r.Delete("/{groupID}/leave", h.LeaveGroup)
	r.Get("/{groupID}/members", h.ListMembers)
	r.Delete("/{groupID}/members/{userID}", h.KickMember)
	r.Put("/{groupID}/members/{userID}/role", h.PromoteMember)

	// Messages (REST history — real-time is over WS)
	r.Get("/{groupID}/messages", h.GetHistory)

	return r
}

// ─── Handlers ──────────────────────────────────────────────────────────────

func (h *Handler) CreateGroup(w http.ResponseWriter, r *http.Request) {
	callerID := h.callerID(r)

	var body struct {
		Name        string `json:"name"`
		Description string `json:"description"`
		IsPrivate   bool   `json:"is_private"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	g, err := h.svc.CreateGroup(r.Context(), callerID, body.Name, body.Description, body.IsPrivate)
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	writeJSON(w, http.StatusCreated, g)
}

func (h *Handler) GetGroup(w http.ResponseWriter, r *http.Request) {
	callerID := h.callerID(r)
	groupID := parseUUID(chi.URLParam(r, "groupID"))

	g, err := h.svc.GetGroup(r.Context(), callerID, groupID)
	if err != nil {
		if errors.Is(err, ErrNotMember) {
			writeError(w, http.StatusForbidden, err.Error())
			return
		}
		writeError(w, http.StatusNotFound, "group not found")
		return
	}
	writeJSON(w, http.StatusOK, g)
}

func (h *Handler) ListUserGroups(w http.ResponseWriter, r *http.Request) {
	callerID := h.callerID(r)
	groups, err := h.svc.ListUserGroups(r.Context(), callerID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "failed to list groups")
		return
	}
	writeJSON(w, http.StatusOK, map[string]interface{}{"groups": groups})
}

func (h *Handler) JoinByInvite(w http.ResponseWriter, r *http.Request) {
	callerID := h.callerID(r)
	token := chi.URLParam(r, "token")

	g, err := h.svc.JoinByInvite(r.Context(), callerID, token)
	if err != nil {
		switch {
		case errors.Is(err, ErrGroupNotFound):
			writeError(w, http.StatusNotFound, err.Error())
		case errors.Is(err, ErrGroupFull):
			writeError(w, http.StatusConflict, err.Error())
		default:
			writeError(w, http.StatusInternalServerError, "failed to join group")
		}
		return
	}
	writeJSON(w, http.StatusOK, g)
}

func (h *Handler) LeaveGroup(w http.ResponseWriter, r *http.Request) {
	callerID := h.callerID(r)
	groupID := parseUUID(chi.URLParam(r, "groupID"))

	if err := h.svc.LeaveGroup(r.Context(), callerID, groupID); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": "left"})
}

func (h *Handler) ListMembers(w http.ResponseWriter, r *http.Request) {
	callerID := h.callerID(r)
	groupID := parseUUID(chi.URLParam(r, "groupID"))

	members, err := h.svc.ListMembers(r.Context(), callerID, groupID)
	if err != nil {
		writeError(w, http.StatusForbidden, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]interface{}{"members": members})
}

func (h *Handler) KickMember(w http.ResponseWriter, r *http.Request) {
	callerID := h.callerID(r)
	groupID := parseUUID(chi.URLParam(r, "groupID"))
	targetID := parseUUID(chi.URLParam(r, "userID"))

	if err := h.svc.KickMember(r.Context(), callerID, targetID, groupID); err != nil {
		writeError(w, http.StatusForbidden, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": "kicked"})
}

func (h *Handler) PromoteMember(w http.ResponseWriter, r *http.Request) {
	callerID := h.callerID(r)
	groupID := parseUUID(chi.URLParam(r, "groupID"))
	targetID := parseUUID(chi.URLParam(r, "userID"))

	var body struct {
		Role string `json:"role"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	role := Role(body.Role)
	if role != RoleAdmin && role != RoleMember {
		writeError(w, http.StatusBadRequest, "role must be admin or member")
		return
	}

	if err := h.svc.PromoteMember(r.Context(), callerID, targetID, groupID, role); err != nil {
		writeError(w, http.StatusForbidden, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": "updated"})
}

func (h *Handler) GetHistory(w http.ResponseWriter, r *http.Request) {
	callerID := h.callerID(r)
	groupID := parseUUID(chi.URLParam(r, "groupID"))

	limit := 50
	if l := r.URL.Query().Get("limit"); l != "" {
		if n, err := strconv.Atoi(l); err == nil && n > 0 && n <= 100 {
			limit = n
		}
	}

	var before time.Time
	if b := r.URL.Query().Get("before"); b != "" {
		before, _ = time.Parse(time.RFC3339Nano, b)
	}

	msgs, err := h.svc.GroupHistory(r.Context(), callerID, groupID, limit, before)
	if err != nil {
		if errors.Is(err, ErrNotMember) {
			writeError(w, http.StatusForbidden, err.Error())
			return
		}
		writeError(w, http.StatusInternalServerError, "failed to fetch history")
		return
	}
	writeJSON(w, http.StatusOK, map[string]interface{}{"messages": msgs})
}

// ─── helpers ─────────────────────────────────────────────────────────────────

func (h *Handler) callerID(r *http.Request) uuid.UUID {
	id, _ := r.Context().Value(userIDCtxKey).(string)
	uid, _ := uuid.Parse(id)
	return uid
}

func parseUUID(s string) uuid.UUID {
	id, _ := uuid.Parse(s)
	return id
}

func writeJSON(w http.ResponseWriter, status int, v interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(v)
}

func writeError(w http.ResponseWriter, status int, msg string) {
	writeJSON(w, status, map[string]string{"error": msg})
}
