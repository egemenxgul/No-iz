package community

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

// authKey mirrors the auth package's context key type to avoid import cycle.
type authKey string

const userIDCtxKey authKey = "user_id"

// Handler provides HTTP handlers for community endpoints.
type Handler struct {
	svc *Service
	log zerolog.Logger
}

// NewHandler creates a new community Handler.
func NewHandler(svc *Service, log zerolog.Logger) *Handler {
	return &Handler{svc: svc, log: log}
}

// Routes registers all community endpoints on a chi router.
func (h *Handler) Routes() chi.Router {
	r := chi.NewRouter()

	// Discovery & CRUD
	r.Post("/", h.Create)
	r.Get("/discover", h.Discover)
	r.Get("/me", h.MyCommunities)
	r.Get("/{slug}", h.GetBySlug)

	// Membership
	r.Post("/{communityID}/join", h.Join)
	r.Post("/join/{token}", h.JoinByInvite)
	r.Delete("/{communityID}/leave", h.Leave)
	r.Delete("/{communityID}/members/{userID}", h.KickMember)
	r.Put("/{communityID}/members/{userID}/role", h.UpdateRole)

	// Groups
	r.Get("/{communityID}/groups", h.ListGroups)
	r.Post("/{communityID}/groups/{groupID}", h.LinkGroup)
	r.Delete("/{communityID}/groups/{groupID}", h.UnlinkGroup)

	// Posts (community feed)
	r.Post("/{communityID}/posts", h.CreatePost)
	r.Get("/{communityID}/posts", h.ListPosts)
	r.Delete("/{communityID}/posts/{postID}", h.DeletePost)
	r.Put("/{communityID}/posts/{postID}/pin", h.PinPost)
	r.Post("/{communityID}/posts/{postID}/like", h.LikePost)
	r.Delete("/{communityID}/posts/{postID}/like", h.UnlikePost)

	return r
}

// ─── Community Handlers ───────────────────────────────────────────────────────

func (h *Handler) Create(w http.ResponseWriter, r *http.Request) {
	caller := h.callerID(r)

	var body struct {
		Name        string `json:"name"`
		Slug        string `json:"slug"`
		Description string `json:"description"`
		IsPublic    *bool  `json:"is_public"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	isPublic := true
	if body.IsPublic != nil {
		isPublic = *body.IsPublic
	}

	c, err := h.svc.Create(r.Context(), caller, body.Name, body.Slug, body.Description, isPublic)
	if err != nil {
		switch {
		case errors.Is(err, ErrSlugTaken):
			writeError(w, http.StatusConflict, err.Error())
		default:
			writeError(w, http.StatusBadRequest, err.Error())
		}
		return
	}
	writeJSON(w, http.StatusCreated, c)
}

func (h *Handler) GetBySlug(w http.ResponseWriter, r *http.Request) {
	slug := chi.URLParam(r, "slug")
	c, err := h.svc.GetBySlug(r.Context(), slug)
	if err != nil {
		writeError(w, http.StatusNotFound, "community not found")
		return
	}
	writeJSON(w, http.StatusOK, c)
}

func (h *Handler) Discover(w http.ResponseWriter, r *http.Request) {
	limit, _ := strconv.Atoi(r.URL.Query().Get("limit"))
	offset, _ := strconv.Atoi(r.URL.Query().Get("offset"))

	communities, err := h.svc.Discover(r.Context(), limit, offset)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "failed to fetch communities")
		return
	}
	writeJSON(w, http.StatusOK, map[string]interface{}{"communities": communities})
}

func (h *Handler) MyCommunities(w http.ResponseWriter, r *http.Request) {
	caller := h.callerID(r)
	communities, err := h.svc.MyCommunities(r.Context(), caller)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "failed to fetch communities")
		return
	}
	writeJSON(w, http.StatusOK, map[string]interface{}{"communities": communities})
}

// ─── Membership Handlers ──────────────────────────────────────────────────────

func (h *Handler) Join(w http.ResponseWriter, r *http.Request) {
	caller := h.callerID(r)
	communityID := parseUUID(chi.URLParam(r, "communityID"))

	c, err := h.svc.Join(r.Context(), caller, communityID)
	if err != nil {
		switch {
		case errors.Is(err, ErrCommunityFull):
			writeError(w, http.StatusConflict, err.Error())
		case errors.Is(err, ErrPermissionDenied):
			writeError(w, http.StatusForbidden, "community is private — use an invite link")
		default:
			writeError(w, http.StatusNotFound, "community not found")
		}
		return
	}
	writeJSON(w, http.StatusOK, c)
}

func (h *Handler) JoinByInvite(w http.ResponseWriter, r *http.Request) {
	caller := h.callerID(r)
	token := chi.URLParam(r, "token")

	c, err := h.svc.JoinByInvite(r.Context(), caller, token)
	if err != nil {
		switch {
		case errors.Is(err, ErrCommunityFull):
			writeError(w, http.StatusConflict, err.Error())
		default:
			writeError(w, http.StatusNotFound, "invalid invite link")
		}
		return
	}
	writeJSON(w, http.StatusOK, c)
}

func (h *Handler) Leave(w http.ResponseWriter, r *http.Request) {
	caller := h.callerID(r)
	communityID := parseUUID(chi.URLParam(r, "communityID"))

	if err := h.svc.Leave(r.Context(), caller, communityID); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": "left"})
}

func (h *Handler) KickMember(w http.ResponseWriter, r *http.Request) {
	caller := h.callerID(r)
	communityID := parseUUID(chi.URLParam(r, "communityID"))
	targetID := parseUUID(chi.URLParam(r, "userID"))

	if err := h.svc.KickMember(r.Context(), caller, targetID, communityID); err != nil {
		writeError(w, http.StatusForbidden, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": "kicked"})
}

func (h *Handler) UpdateRole(w http.ResponseWriter, r *http.Request) {
	caller := h.callerID(r)
	communityID := parseUUID(chi.URLParam(r, "communityID"))
	targetID := parseUUID(chi.URLParam(r, "userID"))

	var body struct {
		Role string `json:"role"`
	}
	json.NewDecoder(r.Body).Decode(&body)

	role := CommunityRole(body.Role)
	if role != RoleAdmin && role != RoleModerator && role != RoleMember {
		writeError(w, http.StatusBadRequest, "role must be admin, moderator or member")
		return
	}

	if err := h.svc.UpdateRole(r.Context(), caller, targetID, communityID, role); err != nil {
		writeError(w, http.StatusForbidden, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": "updated"})
}

// ─── Group Link Handlers ──────────────────────────────────────────────────────

func (h *Handler) ListGroups(w http.ResponseWriter, r *http.Request) {
	communityID := parseUUID(chi.URLParam(r, "communityID"))
	groups, err := h.svc.ListGroups(r.Context(), communityID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "failed to list groups")
		return
	}
	writeJSON(w, http.StatusOK, map[string]interface{}{"groups": groups})
}

func (h *Handler) LinkGroup(w http.ResponseWriter, r *http.Request) {
	caller := h.callerID(r)
	communityID := parseUUID(chi.URLParam(r, "communityID"))
	groupID := parseUUID(chi.URLParam(r, "groupID"))

	var body struct{ Position int `json:"position"` }
	json.NewDecoder(r.Body).Decode(&body)

	if err := h.svc.LinkGroup(r.Context(), caller, communityID, groupID, body.Position); err != nil {
		switch {
		case errors.Is(err, ErrTooManyGroups):
			writeError(w, http.StatusConflict, err.Error())
		case errors.Is(err, ErrPermissionDenied):
			writeError(w, http.StatusForbidden, err.Error())
		default:
			writeError(w, http.StatusBadRequest, err.Error())
		}
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": "linked"})
}

func (h *Handler) UnlinkGroup(w http.ResponseWriter, r *http.Request) {
	caller := h.callerID(r)
	communityID := parseUUID(chi.URLParam(r, "communityID"))
	groupID := parseUUID(chi.URLParam(r, "groupID"))

	if err := h.svc.UnlinkGroup(r.Context(), caller, communityID, groupID); err != nil {
		writeError(w, http.StatusForbidden, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": "unlinked"})
}

// ─── Post Handlers ────────────────────────────────────────────────────────────

func (h *Handler) CreatePost(w http.ResponseWriter, r *http.Request) {
	caller := h.callerID(r)
	communityID := parseUUID(chi.URLParam(r, "communityID"))

	var body struct {
		Title     string   `json:"title"`
		Body      string   `json:"body"`
		MediaURLs []string `json:"media_urls"`
		ExpiresIn int      `json:"expires_in"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	p, err := h.svc.CreatePost(r.Context(), caller, communityID, body.Title, body.Body, body.MediaURLs, body.ExpiresIn)
	if err != nil {
		switch {
		case errors.Is(err, ErrNotMember):
			writeError(w, http.StatusForbidden, err.Error())
		default:
			writeError(w, http.StatusBadRequest, err.Error())
		}
		return
	}
	writeJSON(w, http.StatusCreated, p)
}

func (h *Handler) ListPosts(w http.ResponseWriter, r *http.Request) {
	caller := h.callerID(r)
	communityID := parseUUID(chi.URLParam(r, "communityID"))

	limit, _ := strconv.Atoi(r.URL.Query().Get("limit"))
	var before time.Time
	if b := r.URL.Query().Get("before"); b != "" {
		before, _ = time.Parse(time.RFC3339Nano, b)
	}

	posts, err := h.svc.ListPosts(r.Context(), caller, communityID, limit, before)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "failed to fetch posts")
		return
	}
	writeJSON(w, http.StatusOK, map[string]interface{}{"posts": posts})
}

func (h *Handler) DeletePost(w http.ResponseWriter, r *http.Request) {
	caller := h.callerID(r)
	postID := parseUUID(chi.URLParam(r, "postID"))

	if err := h.svc.DeletePost(r.Context(), caller, postID); err != nil {
		writeError(w, http.StatusForbidden, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": "deleted"})
}

func (h *Handler) PinPost(w http.ResponseWriter, r *http.Request) {
	caller := h.callerID(r)
	communityID := parseUUID(chi.URLParam(r, "communityID"))
	postID := parseUUID(chi.URLParam(r, "postID"))

	var body struct{ Pin bool `json:"pin"` }
	json.NewDecoder(r.Body).Decode(&body)

	if err := h.svc.PinPost(r.Context(), caller, communityID, postID, body.Pin); err != nil {
		writeError(w, http.StatusForbidden, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": "updated"})
}

func (h *Handler) LikePost(w http.ResponseWriter, r *http.Request) {
	caller := h.callerID(r)
	postID := parseUUID(chi.URLParam(r, "postID"))
	if err := h.svc.LikePost(r.Context(), caller, postID); err != nil {
		writeError(w, http.StatusInternalServerError, "failed to like post")
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": "liked"})
}

func (h *Handler) UnlikePost(w http.ResponseWriter, r *http.Request) {
	caller := h.callerID(r)
	postID := parseUUID(chi.URLParam(r, "postID"))
	if err := h.svc.UnlikePost(r.Context(), caller, postID); err != nil {
		writeError(w, http.StatusInternalServerError, "failed to unlike post")
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": "unliked"})
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
