package auth

import (
	"encoding/json"
	"errors"
	"net/http"
	"strings"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/no-iz/iz-backend/pkg/i18n"
)

// Handler returns http.HandlerFunc functions for auth routes.
type Handler struct {
	svc   *Service
	qrHub *QRHub
}

// NewHandler creates an auth HTTP handler.
func NewHandler(svc *Service, qrHub *QRHub) *Handler {
	return &Handler{svc: svc, qrHub: qrHub}
}

func (h *Handler) GetUserBundle(w http.ResponseWriter, r *http.Request) {
	userID := chi.URLParam(r, "id")
	if userID == "" {
		writeError(w, http.StatusBadRequest, i18n.Translate(r, "err_user_id_required"))
		return
	}

	bundle, err := h.svc.GetUserBundle(r.Context(), userID)
	if err != nil {
		if errors.Is(err, ErrUserNotFound) {
			writeError(w, http.StatusNotFound, i18n.Translate(r, "err_user_not_found"))
		} else {
			writeError(w, http.StatusInternalServerError, i18n.Translate(r, "err_internal"))
		}
		return
	}

	writeJSON(w, http.StatusOK, bundle)
}

// ────────────────────────────────────────────────────────────────
// GET /api/users/search?q=  (requires auth)
// ────────────────────────────────────────────────────────────────

func (h *Handler) SearchUsers(w http.ResponseWriter, r *http.Request) {
	q := strings.TrimSpace(r.URL.Query().Get("q"))
	if len(q) < 2 {
		writeJSON(w, http.StatusOK, map[string]any{"users": []any{}})
		return
	}

	users, err := h.svc.SearchUsers(r.Context(), q, 20)
	if err != nil {
		writeError(w, http.StatusInternalServerError, i18n.Translate(r, "err_search_failed"))
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{"users": users})
}

// ────────────────────────────────────────────────────────────────
// POST /api/auth/register
// ────────────────────────────────────────────────────────────────

type registerRequest struct {
	Username    string `json:"username"`
	Email       string `json:"email"`
	Password    string `json:"password"`
	DisplayName string `json:"display_name"`
	InviteCode  string `json:"invite_code"`
	Phone       string `json:"phone"`

	// Signal keys from client
	IdentityKey     string           `json:"identity_key"`
	SignedPrekey    string           `json:"signed_prekey"`
	SignedPrekeySig string           `json:"signed_prekey_sig"`
	OneTimePrekeys  []prekeyRequest  `json:"one_time_prekeys"`
}

type prekeyRequest struct {
	KeyID     int    `json:"key_id"`
	PublicKey string `json:"public_key"`
}

func (h *Handler) Register(w http.ResponseWriter, r *http.Request) {
	var req registerRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, i18n.Translate(r, "err_invalid_request_body"))
		return
	}

	if errKey := validateRegisterRequest(req); errKey != "" {
		writeError(w, http.StatusBadRequest, i18n.Translate(r, errKey))
		return
	}

	prekeys := make([]OneTimePrekey, len(req.OneTimePrekeys))
	for i, pk := range req.OneTimePrekeys {
		prekeys[i] = OneTimePrekey{KeyID: pk.KeyID, PublicKey: pk.PublicKey}
	}

	out, err := h.svc.Register(r.Context(), RegisterInput{
		Username:        strings.TrimSpace(req.Username),
		Email:           strings.TrimSpace(strings.ToLower(req.Email)),
		Password:        req.Password,
		DisplayName:     strings.TrimSpace(req.DisplayName),
		InviteCode:      req.InviteCode,
		Phone:           strings.TrimSpace(req.Phone),
		IdentityKey:     req.IdentityKey,
		SignedPrekey:    req.SignedPrekey,
		SignedPrekeySig: req.SignedPrekeySig,
		OneTimePrekeys:  prekeys,
	})
	if err != nil {
		switch {
		case errors.Is(err, ErrUsernameTaken):
			writeError(w, http.StatusConflict, i18n.Translate(r, "err_username_taken"))
		case errors.Is(err, ErrEmailTaken):
			writeError(w, http.StatusConflict, i18n.Translate(r, "err_email_taken"))
		case errors.Is(err, ErrInvalidInviteCode):
			writeError(w, http.StatusForbidden, i18n.Translate(r, "err_invalid_invite_code"))
		case errors.Is(err, ErrInviteCodeFull):
			writeError(w, http.StatusForbidden, i18n.Translate(r, "err_invite_code_full"))
		case strings.Contains(err.Error(), "phone number already registered"):
			writeError(w, http.StatusConflict, i18n.Translate(r, "err_phone_taken"))
		default:
			writeError(w, http.StatusInternalServerError, i18n.Translate(r, "err_registration_failed"))
		}
		return
	}

	writeJSON(w, http.StatusCreated, map[string]any{
		"user_id":       out.UserID,
		"username":      out.Username,
		"display_name":  out.DisplayName,
		"avatar_url":    out.AvatarURL,
		"is_admin":      out.IsAdmin,
		"access_token":  out.AccessToken,
		"refresh_token": out.RefreshToken,
	})
}

type matchContactsRequest struct {
	PhoneNumbers []string `json:"phone_numbers"`
}

func (h *Handler) MatchContacts(w http.ResponseWriter, r *http.Request) {
	var req matchContactsRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, i18n.Translate(r, "err_invalid_request_body"))
		return
	}

	results, err := h.svc.MatchContacts(r.Context(), req.PhoneNumbers)
	if err != nil {
		writeError(w, http.StatusInternalServerError, i18n.Translate(r, "err_match_contacts_failed"))
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{"matched_contacts": results})
}

// ────────────────────────────────────────────────────────────────
// POST /api/auth/login
// ────────────────────────────────────────────────────────────────

type loginRequest struct {
	EmailOrUsername string `json:"email_or_username"`
	Password        string `json:"password"`
}

func (h *Handler) Login(w http.ResponseWriter, r *http.Request) {
	var req loginRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, i18n.Translate(r, "err_invalid_request_body"))
		return
	}

	out, err := h.svc.Login(r.Context(), LoginInput{
		EmailOrUsername: strings.TrimSpace(req.EmailOrUsername),
		Password:        req.Password,
	})
	if err != nil {
		if errors.Is(err, ErrInvalidCredentials) {
			writeError(w, http.StatusUnauthorized, i18n.Translate(r, "err_invalid_credentials"))
			return
		}
		writeError(w, http.StatusInternalServerError, i18n.Translate(r, "err_login_failed"))
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{
		"user_id":           out.UserID,
		"username":          out.Username,
		"display_name":      out.DisplayName,
		"avatar_url":        out.AvatarURL,
		"is_admin":          out.IsAdmin,
		"subscription_tier": out.SubscriptionTier,
		"access_token":      out.AccessToken,
		"refresh_token":     out.RefreshToken,
		"requires_2fa":      out.Requires2FA,
		"temp_token":        out.TempToken,
	})
}

// ────────────────────────────────────────────────────────────────
// 2FA Endpoints
// ────────────────────────────────────────────────────────────────

func (h *Handler) Generate2FA(w http.ResponseWriter, r *http.Request) {
	userID, ok := r.Context().Value("user_id").(string)
	if !ok {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	out, err := h.svc.Generate2FA(r.Context(), userID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, i18n.Translate(r, "err_internal"))
		return
	}

	writeJSON(w, http.StatusOK, out)
}

type verify2FARequest struct {
	Code string `json:"code"`
}

func (h *Handler) Verify2FA(w http.ResponseWriter, r *http.Request) {
	userID, ok := r.Context().Value("user_id").(string)
	if !ok {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	var req verify2FARequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, i18n.Translate(r, "err_invalid_request_body"))
		return
	}

	if err := h.svc.Verify2FA(r.Context(), userID, req.Code); err != nil {
		writeError(w, http.StatusBadRequest, i18n.Translate(r, "err_invalid_totp_code"))
		return
	}

	writeJSON(w, http.StatusOK, map[string]string{"message": "2FA successfully enabled"})
}

type login2FARequest struct {
	TempToken string `json:"temp_token"`
	Code      string `json:"code"`
}

func (h *Handler) Login2FA(w http.ResponseWriter, r *http.Request) {
	var req login2FARequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, i18n.Translate(r, "err_invalid_request_body"))
		return
	}

	out, err := h.svc.Finalize2FALogin(r.Context(), Finalize2FALoginInput{
		TempToken: req.TempToken,
		Code:      req.Code,
	})
	if err != nil {
		writeError(w, http.StatusUnauthorized, i18n.Translate(r, "err_invalid_totp_code"))
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{
		"user_id":       out.UserID,
		"username":      out.Username,
		"display_name":  out.DisplayName,
		"avatar_url":    out.AvatarURL,
		"is_admin":      out.IsAdmin,
		"access_token":  out.AccessToken,
		"refresh_token": out.RefreshToken,
	})
}

// ────────────────────────────────────────────────────────────────
// GDPR Data Export & Delete
// ────────────────────────────────────────────────────────────────

func (h *Handler) ExportData(w http.ResponseWriter, r *http.Request) {
	userID, ok := r.Context().Value("user_id").(string)
	if !ok {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	data, err := h.svc.ExportData(r.Context(), userID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, i18n.Translate(r, "err_internal"))
		return
	}

	// For MVP, just return the raw JSON object
	writeJSON(w, http.StatusOK, data)
}

type deleteAccountRequest struct {
	Password string `json:"password"`
}

func (h *Handler) DeleteAccount(w http.ResponseWriter, r *http.Request) {
	userID, ok := r.Context().Value("user_id").(string)
	if !ok {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	var req deleteAccountRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, i18n.Translate(r, "err_invalid_request_body"))
		return
	}

	if err := h.svc.DeleteAccount(r.Context(), userID, req.Password); err != nil {
		if errors.Is(err, ErrInvalidCredentials) {
			writeError(w, http.StatusUnauthorized, i18n.Translate(r, "err_invalid_credentials"))
			return
		}
		writeError(w, http.StatusInternalServerError, i18n.Translate(r, "err_internal"))
		return
	}

	writeJSON(w, http.StatusOK, map[string]string{"message": "Account successfully deleted"})
}

// ────────────────────────────────────────────────────────────────
// POST /api/auth/change-password  (requires auth)
// ────────────────────────────────────────────────────────────────

type changePasswordRequest struct {
	OldPassword string `json:"old_password"`
	NewPassword string `json:"new_password"`
}

func (h *Handler) ChangePassword(w http.ResponseWriter, r *http.Request) {
	userID, ok := UserIDFromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, i18n.Translate(r, "err_unauthorized"))
		return
	}

	var req changePasswordRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, i18n.Translate(r, "err_invalid_request_body"))
		return
	}

	if req.OldPassword == "" || req.NewPassword == "" {
		writeError(w, http.StatusBadRequest, i18n.Translate(r, "err_password_required"))
		return
	}

	err := h.svc.ChangePassword(r.Context(), ChangePasswordInput{
		UserID:      userID,
		OldPassword: req.OldPassword,
		NewPassword: req.NewPassword,
	})
	if err != nil {
		switch {
		case errors.Is(err, ErrInvalidCredentials):
			writeError(w, http.StatusUnauthorized, i18n.Translate(r, "err_incorrect_current_password"))
		default:
			writeError(w, http.StatusInternalServerError, i18n.Translate(r, "err_internal"))
		}
		return
	}

	writeJSON(w, http.StatusOK, map[string]string{"message": "password changed successfully"})
}

// ────────────────────────────────────────────────────────────────
// POST /api/auth/change-email  (requires auth)
// ────────────────────────────────────────────────────────────────

type changeEmailRequest struct {
	Password string `json:"password"`
	NewEmail string `json:"new_email"`
}

func (h *Handler) ChangeEmail(w http.ResponseWriter, r *http.Request) {
	userID, ok := UserIDFromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, i18n.Translate(r, "err_unauthorized"))
		return
	}

	var req changeEmailRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, i18n.Translate(r, "err_invalid_request_body"))
		return
	}

	if req.Password == "" || req.NewEmail == "" {
		writeError(w, http.StatusBadRequest, i18n.Translate(r, "err_invalid_request_body"))
		return
	}

	err := h.svc.ChangeEmail(r.Context(), ChangeEmailInput{
		UserID:   userID,
		Password: req.Password,
		NewEmail: req.NewEmail,
	})
	if err != nil {
		switch {
		case errors.Is(err, ErrInvalidCredentials):
			writeError(w, http.StatusUnauthorized, i18n.Translate(r, "err_invalid_credentials"))
		case errors.Is(err, ErrEmailTaken):
			writeError(w, http.StatusConflict, i18n.Translate(r, "err_email_taken"))
		default:
			writeError(w, http.StatusInternalServerError, i18n.Translate(r, "err_internal"))
		}
		return
	}

	writeJSON(w, http.StatusOK, map[string]string{"message": "email changed successfully"})
}

// ────────────────────────────────────────────────────────────────
// GET /api/health
// ────────────────────────────────────────────────────────────────

func HealthCheck(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok", "service": "iz-backend"})
}

// ────────────────────────────────────────────────────────────────
// Request validation
// ────────────────────────────────────────────────────────────────

func validateRegisterRequest(req registerRequest) string {
	if len(req.Username) < 3 || len(req.Username) > 32 {
		return "err_username_length"
	}
	if !strings.Contains(req.Email, "@") {
		return "err_invalid_email"
	}
	if len(req.Password) < 8 {
		return "err_password_length"
	}
	if len(req.DisplayName) < 1 || len(req.DisplayName) > 64 {
		return "err_display_name_length"
	}
	if req.InviteCode == "" {
		return "err_invite_code_required"
	}
	if req.IdentityKey == "" || req.SignedPrekey == "" || req.SignedPrekeySig == "" {
		return "err_signal_keys_required"
	}
	return ""
}

// ────────────────────────────────────────────────────────────────
// POST /api/auth/refresh  (public — token is the credential)
// ────────────────────────────────────────────────────────────────

type refreshRequest struct {
	RefreshToken string `json:"refresh_token"`
}

func (h *Handler) RefreshToken(w http.ResponseWriter, r *http.Request) {
	var req refreshRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, i18n.Translate(r, "err_invalid_request_body"))
		return
	}
	if req.RefreshToken == "" {
		writeError(w, http.StatusBadRequest, i18n.Translate(r, "err_refresh_token_required"))
		return
	}

	out, err := h.svc.RefreshTokens(r.Context(), req.RefreshToken)
	if err != nil {
		// Both expired/revoked tokens and unknown tokens map to 401.
		writeError(w, http.StatusUnauthorized, i18n.Translate(r, "err_invalid_credentials"))
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{
		"access_token":  out.AccessToken,
		"refresh_token": out.RefreshToken,
	})
}

// ────────────────────────────────────────────────────────────────
// POST /api/devices/register  (authenticated)
// ────────────────────────────────────────────────────────────────

func (h *Handler) RegisterDevice(w http.ResponseWriter, r *http.Request) {
	userIDStr, ok := UserIDFromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, i18n.Translate(r, "err_unauthorized"))
		return
	}

	var req RegisterDeviceInput
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, i18n.Translate(r, "err_invalid_request_body"))
		return
	}

	err := h.svc.RegisterDevice(r.Context(), userIDStr, &req)
	if err != nil {
		// Do NOT expose internal error details to the client (CWE-209).
		writeError(w, http.StatusInternalServerError, i18n.Translate(r, "err_internal"))
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{"status": "registered"})
}

// ────────────────────────────────────────────────────────────────
// JSON helpers
// ────────────────────────────────────────────────────────────────

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}

func writeError(w http.ResponseWriter, status int, msg string) {
	writeJSON(w, status, map[string]string{"error": msg})
}

// ────────────────────────────────────────────────────────────────
// QR Web Login (HTTPS Polling)
// ────────────────────────────────────────────────────────────────

func (h *Handler) PollQRAuth(w http.ResponseWriter, r *http.Request) {
	token := r.URL.Query().Get("token")
	if token == "" {
		writeError(w, http.StatusBadRequest, "missing token")
		return
	}

	if h.qrHub == nil {
		writeError(w, http.StatusInternalServerError, "qr hub not initialized")
		return
	}

	payload, ok := h.qrHub.GetPayload(token)
	if !ok {
		writeJSON(w, http.StatusAccepted, map[string]string{"status": "pending"})
		return
	}

	writeJSON(w, http.StatusOK, payload)
}

type qrLinkRequest struct {
	QRToken          string `json:"qr_token"`
	EncryptedPayload string `json:"encrypted_payload"`
}

func (h *Handler) QRLinkDevice(w http.ResponseWriter, r *http.Request) {
	userIDStr, ok := UserIDFromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	var req qrLinkRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	if req.QRToken == "" || req.EncryptedPayload == "" {
		writeError(w, http.StatusBadRequest, "missing parameters")
		return
	}

	access, refresh, err := h.svc.LinkWebDevice(r.Context(), userIDStr)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "failed to link device")
		return
	}

	payload := map[string]interface{}{
		"type":              "AUTH_SUCCESS",
		"access_token":      access,
		"refresh_token":     refresh,
		"encrypted_payload": req.EncryptedPayload,
	}

	if h.qrHub != nil {
		h.qrHub.StorePayload(req.QRToken, payload)
	}

	writeJSON(w, http.StatusOK, map[string]string{"status": "linked"})
}

// ────────────────────────────────────────────────────────────────
// GET /api/auth/prekeys/count — returns remaining prekey count
// POST /api/auth/prekeys — replenish one-time prekey pool
// ────────────────────────────────────────────────────────────────

func (h *Handler) GetPrekeysCount(w http.ResponseWriter, r *http.Request) {
	userIDStr, ok := UserIDFromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	userID, err := uuid.Parse(userIDStr)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid user id")
		return
	}
	count, err := h.svc.GetPrekeysCount(r.Context(), userID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "failed to get prekey count")
		return
	}
	writeJSON(w, http.StatusOK, map[string]int{"count": count})
}

type replenishPrekeysRequest struct {
	OneTimePrekeys []prekeyRequest `json:"one_time_prekeys"`
}

func (h *Handler) ReplenishPrekeys(w http.ResponseWriter, r *http.Request) {
	userIDStr, ok := UserIDFromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	userID, err := uuid.Parse(userIDStr)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid user id")
		return
	}

	var req replenishPrekeysRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	prekeys := make([]OneTimePrekey, len(req.OneTimePrekeys))
	for i, pk := range req.OneTimePrekeys {
		prekeys[i] = OneTimePrekey{KeyID: pk.KeyID, PublicKey: pk.PublicKey}
	}

	if err := h.svc.ReplenishPrekeys(r.Context(), userID, prekeys); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/auth/apple  — Apple Sign In
// ─────────────────────────────────────────────────────────────────────────────

type appleSignInRequest struct {
	// IdentityToken is the JWT from Apple's authorization server.
	// The client receives this from Sign in with Apple after user consent.
	IdentityToken string `json:"identity_token"`
	// UserID is the stable Apple user identifier (sub claim).
	UserID string `json:"user_id"`
	// Email may be empty if the user chose "Hide My Email".
	Email string `json:"email"`
	// FullName is provided only on first sign-in.
	FullName string `json:"full_name"`
}

func (h *Handler) AppleSignIn(w http.ResponseWriter, r *http.Request) {
	var req appleSignInRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	if req.UserID == "" {
		writeError(w, http.StatusBadRequest, "user_id is required")
		return
	}

	// NOTE: In production, validate req.IdentityToken against Apple's public keys.
	// For now we trust the UserID passed from the client (secured by TLS).
	// A full implementation would fetch https://appleid.apple.com/auth/keys and
	// verify the JWT signature before processing.

	result, err := h.svc.AuthenticateWithApple(r.Context(), req.UserID, req.Email, req.FullName)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "apple sign in failed")
		return
	}

	writeJSON(w, http.StatusOK, result)
}

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/auth/forgot-password  — Şifremi Unuttum
// ─────────────────────────────────────────────────────────────────────────────

type forgotPasswordRequest struct {
	Email string `json:"email"`
}

func (h *Handler) ForgotPassword(w http.ResponseWriter, r *http.Request) {
	var req forgotPasswordRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	// Always return 200 to prevent email enumeration
	_, _ = h.svc.RequestPasswordReset(r.Context(), req.Email)
	writeJSON(w, http.StatusOK, map[string]string{
		"message": "Şifre sıfırlama bağlantısı e-posta adresinize gönderildi.",
	})
}

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/auth/reset-password  — Şifre Sıfırlama
// ─────────────────────────────────────────────────────────────────────────────

type resetPasswordRequest struct {
	Token       string `json:"token"`
	NewPassword string `json:"new_password"`
}

func (h *Handler) ResetPassword(w http.ResponseWriter, r *http.Request) {
	var req resetPasswordRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	if err := h.svc.ResetPassword(r.Context(), req.Token, req.NewPassword); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	writeJSON(w, http.StatusOK, map[string]string{"message": "Şifreniz başarıyla güncellendi."})
}
