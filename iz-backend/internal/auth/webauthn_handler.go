package auth

import (
	"encoding/json"
	"net/http"
)

// ─────────────────────────────────────────────────────────────────────────────
// REGISTRATION
// ─────────────────────────────────────────────────────────────────────────────

type passkeyRegisterBeginRequest struct {
	Username    string `json:"username"`
	Email       string `json:"email"`
	DisplayName string `json:"display_name"`
	InviteCode  string `json:"invite_code"`
}

func (h *Handler) PasskeyRegisterBegin(w http.ResponseWriter, r *http.Request) {
	var req passkeyRegisterBeginRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	creationData, sessionID, err := h.svc.BeginPasskeyRegistration(r.Context(), req.Username, req.Email, req.DisplayName, req.InviteCode)
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"session_id": sessionID,
		"options":    creationData,
	})
}

func (h *Handler) PasskeyRegisterFinish(w http.ResponseWriter, r *http.Request) {
	sessionID := r.URL.Query().Get("session_id")
	if sessionID == "" {
		writeError(w, http.StatusBadRequest, "session_id is required")
		return
	}

	// Fetch session from Redis
	b, err := h.svc.rdb.Get(r.Context(), "wa:reg:"+sessionID).Bytes()
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid or expired session")
		return
	}

	var regData PasskeyRegistrationData
	if err := json.Unmarshal(b, &regData); err != nil {
		writeError(w, http.StatusInternalServerError, "failed to parse session")
		return
	}

	credential, err := h.svc.wa.FinishRegistration(&regData.User, regData.SessionData, r)
	if err != nil {
		writeError(w, http.StatusBadRequest, "failed to finish registration: "+err.Error())
		return
	}

	// Create user
	authResult, err := h.svc.CreatePasskeyUser(r.Context(), regData, credential)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "failed to create user: "+err.Error())
		return
	}

	// Clean up session
	h.svc.rdb.Del(r.Context(), "wa:reg:"+sessionID)

	writeJSON(w, http.StatusOK, authResult)
}

// ─────────────────────────────────────────────────────────────────────────────
// LOGIN
// ─────────────────────────────────────────────────────────────────────────────

type passkeyLoginBeginRequest struct {
	Username string `json:"username"`
}

func (h *Handler) PasskeyLoginBegin(w http.ResponseWriter, r *http.Request) {
	var req passkeyLoginBeginRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	assertionData, sessionID, err := h.svc.BeginPasskeyLogin(r.Context(), req.Username)
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"session_id": sessionID,
		"options":    assertionData,
	})
}

func (h *Handler) PasskeyLoginFinish(w http.ResponseWriter, r *http.Request) {
	sessionID := r.URL.Query().Get("session_id")
	if sessionID == "" {
		writeError(w, http.StatusBadRequest, "session_id is required")
		return
	}

	b, err := h.svc.rdb.Get(r.Context(), "wa:log:"+sessionID).Bytes()
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid or expired session")
		return
	}

	var regData PasskeyRegistrationData
	if err := json.Unmarshal(b, &regData); err != nil {
		writeError(w, http.StatusInternalServerError, "failed to parse session")
		return
	}

	credential, err := h.svc.wa.FinishLogin(&regData.User, regData.SessionData, r)
	if err != nil {
		writeError(w, http.StatusBadRequest, "failed to finish login: "+err.Error())
		return
	}

	authResult, err := h.svc.AuthenticatePasskeyUser(r.Context(), regData, credential)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "failed to authenticate: "+err.Error())
		return
	}

	h.svc.rdb.Del(r.Context(), "wa:log:"+sessionID)

	writeJSON(w, http.StatusOK, authResult)
}
