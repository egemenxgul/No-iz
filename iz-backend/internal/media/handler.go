package media

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"path/filepath"
	"strings"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/no-iz/iz-backend/internal/auth"
	"github.com/no-iz/iz-backend/internal/economy"
	"github.com/no-iz/iz-backend/pkg/config"
	"github.com/rs/zerolog"
)

// Storage defines the interface for interacting with file storage.
type Storage interface {
	UploadFile(ctx context.Context, bucket string, filename string, reader io.Reader, size int64, contentType string) (string, error)
	DownloadFile(ctx context.Context, bucket string, filename string) (io.ReadCloser, int64, string, error)
}

// Handler handles HTTP requests for media uploads and downloads.
type Handler struct {
	storage Storage
	economySvc interface {
		GetUserLimits(ctx context.Context, userID uuid.UUID) (economy.Features, economy.Tier, int64, error)
		ConsumeStorage(ctx context.Context, userID uuid.UUID, bytes int64) error
	}
	cfg     *config.Config
	log     zerolog.Logger
}

// NewHandler creates a new HTTP media handler.
func NewHandler(storage Storage, economySvc interface {
	GetUserLimits(ctx context.Context, userID uuid.UUID) (economy.Features, economy.Tier, int64, error)
	ConsumeStorage(ctx context.Context, userID uuid.UUID, bytes int64) error
}, cfg *config.Config, log zerolog.Logger) *Handler {
	return &Handler{
		storage: storage,
		economySvc: economySvc,
		cfg:     cfg,
		log:     log.With().Str("handler", "media").Logger(),
	}
}

// Upload handles E2EE and general media file uploading.
func (h *Handler) Upload(w http.ResponseWriter, r *http.Request) {
	userID, ok := auth.UserIDFromContext(r.Context())
	if !ok {
		h.respondError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	uid, _ := uuid.Parse(userID)
	features, _, storageUsed, err := h.economySvc.GetUserLimits(r.Context(), uid)
	if err != nil {
		h.respondError(w, http.StatusInternalServerError, "failed to get user limits")
		return
	}

	// 1. Storage quota check
	if storageUsed >= features.MaxStorageBytes {
		w.Header().Set("X-Storage-Error", "cloud_lock")
		h.respondError(w, http.StatusPaymentRequired, "storage quota exceeded (Cloud Lock Mode: Read Only)")
		return
	}

	// 2. Impose dynamic size limit based on subscription tier
	maxUpload := features.MaxUploadBytes
	r.Body = http.MaxBytesReader(w, r.Body, maxUpload)

	// 3. Parse multipart form. (Keep 50MB in memory, spool rest to disk)
	if err := r.ParseMultipartForm(50 * 1024 * 1024); err != nil {
		if err.Error() == "http: request body too large" {
			h.respondError(w, http.StatusRequestEntityTooLarge, "file size exceeds your subscription's maximum limit")
			return
		}
		h.log.Warn().Err(err).Str("user_id", userID).Msg("failed to parse multipart form")
		h.respondError(w, http.StatusBadRequest, "failed to parse multipart form")
		return
	}

	file, header, err := r.FormFile("file")
	if err != nil {
		h.respondError(w, http.StatusBadRequest, "missing 'file' parameter in multipart form")
		return
	}
	defer file.Close()

	// 3. Extract and validate file extension against a strict allow-list.
	origName := header.Filename
	ext := strings.ToLower(filepath.Ext(origName))

	allowedExts := map[string]bool{
		".png":  true,
		".jpg":  true,
		".jpeg": true,
		".gif":  true,
		".mp4":  true,
		".pdf":  true,
		".doc":  true,
		".docx": true,
		".txt":  true,
		".enc":  true, // Encrypted payload block
		".bin":  true, // Generic binary payload
		".webp": true,
	}

	if !allowedExts[ext] {
		h.log.Warn().Str("user_id", userID).Str("ext", ext).Msg("rejected upload with unsupported extension")
		h.respondError(w, http.StatusBadRequest, "unsupported file format")
		return
	}

	// 4. Magic-byte validation: read first 512 bytes to detect the actual MIME type
	//    regardless of what the extension or Content-Type header claims (CWE-434).
	sniff := make([]byte, 512)
	n, _ := file.Read(sniff)
	detected := http.DetectContentType(sniff[:n])

	// Build a safe multi-reader so the rest of the upload stream is not lost.
	// Use bytes.NewReader (not strings.NewReader) for binary-correct handling.
	bodyReader := io.MultiReader(bytes.NewReader(sniff[:n]), file)

	// Reject types that could execute in a browser or be used for SSRF.
	dangerousMIME := []string{"text/html", "text/xml", "image/svg", "application/xml",
		"application/xhtml", "application/javascript", "text/javascript"}
	for _, bad := range dangerousMIME {
		if strings.HasPrefix(detected, bad) {
			h.log.Warn().Str("user_id", userID).Str("detected_mime", detected).Msg("rejected upload with dangerous MIME type")
			h.respondError(w, http.StatusBadRequest, "unsupported file format")
			return
		}
	}

	// 5. Enforce dynamic upload size limit (already checked by MaxBytesReader but good for exact header check)
	if header.Size > features.MaxUploadBytes {
		h.log.Warn().Str("user_id", userID).Int64("size", header.Size).Int64("limit", features.MaxUploadBytes).Msg("file size exceeds limit")
		h.respondError(w, http.StatusRequestEntityTooLarge, "file size exceeds the maximum limit for your subscription")
		return
	}
	
	// Check if this upload will exceed total storage limit
	if storageUsed+header.Size > features.MaxStorageBytes {
		w.Header().Set("X-Storage-Error", "cloud_lock")
		h.respondError(w, http.StatusPaymentRequired, "this upload will exceed your storage quota (Cloud Lock)")
		return
	}

	// 80% Warning header
	warningHeader := ""
	if float64(storageUsed+header.Size) >= float64(features.MaxStorageBytes)*0.8 {
		warningHeader = "StorageWarning: quota_almost_full"
		w.Header().Set("X-Storage-Warning", "80_percent_reached")
	}

	// 6. Generate unique, unpredictable, path-traversal immune filename via UUIDv4.
	newFilename := uuid.NewString() + ext

	// 6. Select target bucket based on parameter.
	bucket := h.cfg.MinioBucketMedia
	isAvatar := r.URL.Query().Get("type") == "avatar"
	if isAvatar {
		bucket = h.cfg.MinioBucketAvatars
	}

	// 7. Detect Content-Type, defaulting to generic binary stream if empty.
	contentType := header.Header.Get("Content-Type")
	if contentType == "" {
		contentType = "application/octet-stream"
	}

	// 8. Stream the file directly into MinIO (using the reconstructed reader).
	uploadedKey, err := h.storage.UploadFile(r.Context(), bucket, newFilename, bodyReader, header.Size, contentType)
	if err != nil {
		h.log.Error().Err(err).Str("user_id", userID).Msg("failed to stream upload to MinIO")
		h.respondError(w, http.StatusInternalServerError, "failed to process and store upload")
		return
	}

	// Consume storage limit
	if err := h.economySvc.ConsumeStorage(r.Context(), uid, header.Size); err != nil {
		h.log.Error().Err(err).Msg("failed to update storage usage")
	}

	// 9. Return metadata to the client.
	downloadPath := fmt.Sprintf("/api/media/download/%s", uploadedKey)
	if isAvatar {
		downloadPath = fmt.Sprintf("/api/media/download/%s?type=avatar", uploadedKey)
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"url":       downloadPath,
		"filename":  newFilename,
		"size":      header.Size,
		"mime_type": contentType,
		"warning":   warningHeader,
	})
}

// Download serves an uploaded file by proxying it from MinIO.
func (h *Handler) Download(w http.ResponseWriter, r *http.Request) {
	_, ok := auth.UserIDFromContext(r.Context())
	if !ok {
		h.respondError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	// 1. Extract path parameter and completely strip directory traversal components.
	rawKey := chi.URLParam(r, "key")
	key := filepath.Base(rawKey)
	if key == "." || key == "/" || key == "" {
		h.respondError(w, http.StatusBadRequest, "invalid file identifier")
		return
	}

	// 2. Select source bucket.
	bucket := h.cfg.MinioBucketMedia
	if r.URL.Query().Get("type") == "avatar" {
		bucket = h.cfg.MinioBucketAvatars
	}

	// 3. Fetch from MinIO.
	reader, size, contentType, err := h.storage.DownloadFile(r.Context(), bucket, key)
	if err != nil {
		if err.Error() == "file not found" {
			h.respondError(w, http.StatusNotFound, "file not found")
			return
		}
		h.log.Error().Err(err).Str("key", key).Msg("failed to retrieve file from MinIO")
		h.respondError(w, http.StatusInternalServerError, "failed to retrieve file")
		return
	}
	defer reader.Close()

	// 4. Set secure serving headers.
	w.Header().Set("Content-Type", contentType)
	w.Header().Set("Content-Length", fmt.Sprintf("%d", size))
	w.Header().Set("X-Content-Type-Options", "nosniff")
	
	// Force downlaod for files to prevent malicious code execution in browser context
	w.Header().Set("Content-Disposition", fmt.Sprintf("attachment; filename=%q", key))

	w.WriteHeader(http.StatusOK)
	_, err = io.Copy(w, reader)
	if err != nil {
		h.log.Error().Err(err).Str("key", key).Msg("failed to stream file response back to client")
	}
}

// respondError helper to output a sanitized JSON error.
func (h *Handler) respondError(w http.ResponseWriter, status int, errMsg string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(map[string]string{
		"error": errMsg,
	})
}
