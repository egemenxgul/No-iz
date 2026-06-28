package auth

import (
	"encoding/json"
	"net/http"
)

type pinSetupRequest struct {
	PIN             string          `json:"pin"`
	IdentityKey     string          `json:"identity_key"`
	SignedPrekey    string          `json:"signed_prekey"`
	SignedPrekeySig string          `json:"signed_prekey_sig"`
	OneTimePrekeys  []prekeyRequest `json:"one_time_prekeys"`
}

// POST /api/auth/pin/setup (requires auth)
func (h *Handler) SetupPIN(w http.ResponseWriter, r *http.Request) {
	userIDStr := r.Header.Get("X-User-ID")
	if userIDStr == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	var req pinSetupRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	if len(req.PIN) != 6 {
		writeError(w, http.StatusBadRequest, "PIN must be exactly 6 characters")
		return
	}

	if req.IdentityKey == "" || req.SignedPrekey == "" || req.SignedPrekeySig == "" {
		writeError(w, http.StatusBadRequest, "err_signal_keys_required")
		return
	}

	// Save PIN and Signal keys
	if err := h.svc.SetupPINAndKeys(r.Context(), userIDStr, req.PIN, req.IdentityKey, req.SignedPrekey, req.SignedPrekeySig, req.OneTimePrekeys); err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}

	writeJSON(w, http.StatusOK, map[string]string{"message": "PIN and keys configured successfully"})
}

// POST /api/auth/pin/verify (requires auth)
type pinVerifyRequest struct {
	PIN string `json:"pin"`
}

func (h *Handler) VerifyPIN(w http.ResponseWriter, r *http.Request) {
	userIDStr := r.Header.Get("X-User-ID")
	if userIDStr == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	var req pinVerifyRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	if err := h.svc.VerifyPIN(r.Context(), userIDStr, req.PIN); err != nil {
		writeError(w, http.StatusUnauthorized, "invalid PIN")
		return
	}

	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}
