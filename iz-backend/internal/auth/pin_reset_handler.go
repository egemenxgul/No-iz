package auth

import (
	"encoding/json"
	"net/http"
)

type ResetPasswordWithPinRequest struct {
	Email string `json:"email"`
}

func (h *Handler) ResetPasswordWithPin(w http.ResponseWriter, r *http.Request) {
	var req ResetPasswordWithPinRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	// This is a placeholder for PIN reset via email.
	// Since keys are encrypted with PIN, resetting PIN means losing E2E history.
	_, _ = h.svc.RequestPasswordReset(r.Context(), req.Email)
	writeJSON(w, http.StatusOK, map[string]string{
		"message": "PIN sıfırlama bağlantısı e-posta adresinize gönderildi. DİKKAT: PIN sıfırlandığında eski mesajlarınız okunamayacaktır.",
	})
}
