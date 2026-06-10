package media

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"mime/multipart"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/go-chi/chi/v5"
	"github.com/no-iz/iz-backend/internal/auth"
	"github.com/no-iz/iz-backend/pkg/config"
	"github.com/rs/zerolog"
)

// MockStorage implements the Storage interface for testing.
type MockStorage struct {
	UploadFunc   func(ctx context.Context, bucket string, filename string, reader io.Reader, size int64, contentType string) (string, error)
	DownloadFunc func(ctx context.Context, bucket string, filename string) (io.ReadCloser, int64, string, error)
}

func (m *MockStorage) UploadFile(ctx context.Context, bucket string, filename string, reader io.Reader, size int64, contentType string) (string, error) {
	if m.UploadFunc != nil {
		return m.UploadFunc(ctx, bucket, filename, reader, size, contentType)
	}
	return filename, nil
}

func (m *MockStorage) DownloadFile(ctx context.Context, bucket string, filename string) (io.ReadCloser, int64, string, error) {
	if m.DownloadFunc != nil {
		return m.DownloadFunc(ctx, bucket, filename)
	}
	return io.NopCloser(strings.NewReader("mocked content")), 14, "image/png", nil
}

func setupTestHandler(storage Storage) (*Handler, *config.Config) {
	cfg := &config.Config{
		MinioBucketMedia:   "iz-media",
		MinioBucketAvatars: "iz-avatars",
	}
	h := NewHandler(storage, cfg, zerolog.Nop())
	return h, cfg
}

func TestUpload_Success(t *testing.T) {
	var calledBucket, calledFilename, calledContentType string
	var calledSize int64

	mockStorage := &MockStorage{
		UploadFunc: func(ctx context.Context, bucket string, filename string, reader io.Reader, size int64, contentType string) (string, error) {
			calledBucket = bucket
			calledFilename = filename
			calledSize = size
			calledContentType = contentType
			return filename, nil
		},
	}

	h, _ := setupTestHandler(mockStorage)

	// Create a multipart form body
	body := &bytes.Buffer{}
	writer := multipart.NewWriter(body)
	part, err := writer.CreateFormFile("file", "chat_image.png")
	if err != nil {
		t.Fatal(err)
	}
	// Use real PNG magic bytes so http.DetectContentType returns "image/png".
	pngBytes := []byte{0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
		0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52}
	_, _ = part.Write(pngBytes)
	_ = writer.Close()

	req := httptest.NewRequest("POST", "/api/media/upload", body)
	req.Header.Set("Content-Type", writer.FormDataContentType())

	// Authenticate request using helper
	ctx := auth.WithUserID(req.Context(), "user-123")
	req = req.WithContext(ctx)

	rec := httptest.NewRecorder()
	h.Upload(rec, req)

	res := rec.Result()
	defer res.Body.Close()

	if res.StatusCode != http.StatusOK {
		t.Errorf("expected status 200, got %d", res.StatusCode)
	}

	var respMap map[string]interface{}
	if err := json.NewDecoder(res.Body).Decode(&respMap); err != nil {
		t.Fatal(err)
	}

	if respMap["key"] == "" {
		t.Error("expected generated key to not be empty")
	}

	expectedPrefix := "/api/media/download/"
	if !strings.HasPrefix(respMap["url"].(string), expectedPrefix) {
		t.Errorf("expected url to start with %s, got %s", expectedPrefix, respMap["url"])
	}

	// Validate random UUID is in filename instead of original "chat_image"
	if strings.Contains(calledFilename, "chat_image") {
		t.Errorf("expected original filename to be scrubbed, but got: %s", calledFilename)
	}

	if !strings.HasSuffix(calledFilename, ".png") {
		t.Errorf("expected filename to preserve .png extension, got: %s", calledFilename)
	}

	if calledBucket != "iz-media" {
		t.Errorf("expected media bucket, got %s", calledBucket)
	}

	if calledSize != int64(len(pngBytes)) {
		t.Errorf("expected size %d, got %d", len(pngBytes), calledSize)
	}

	if calledContentType == "" {
		t.Error("expected content type to be set and not empty")
	}
}

func TestUpload_AvatarBucket(t *testing.T) {
	var calledBucket string
	mockStorage := &MockStorage{
		UploadFunc: func(ctx context.Context, bucket string, filename string, reader io.Reader, size int64, contentType string) (string, error) {
			calledBucket = bucket
			return filename, nil
		},
	}

	h, _ := setupTestHandler(mockStorage)

	body := &bytes.Buffer{}
	writer := multipart.NewWriter(body)
	part, _ := writer.CreateFormFile("file", "avatar.jpg")
	// Use real JPEG magic bytes (FFD8FF).
	jpgBytes := []byte{0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01}
	_, _ = part.Write(jpgBytes)
	_ = writer.Close()

	// Request with ?type=avatar query param
	req := httptest.NewRequest("POST", "/api/media/upload?type=avatar", body)
	req.Header.Set("Content-Type", writer.FormDataContentType())

	ctx := auth.WithUserID(req.Context(), "user-123")
	req = req.WithContext(ctx)

	rec := httptest.NewRecorder()
	h.Upload(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", rec.Code)
	}

	if calledBucket != "iz-avatars" {
		t.Errorf("expected upload to avatars bucket, got: %s", calledBucket)
	}
}

func TestUpload_InvalidExtension(t *testing.T) {
	mockStorage := &MockStorage{}
	h, _ := setupTestHandler(mockStorage)

	body := &bytes.Buffer{}
	writer := multipart.NewWriter(body)
	part, _ := writer.CreateFormFile("file", "shell.php")
	_, _ = part.Write([]byte("<?php echo 'malicious'; ?>"))
	_ = writer.Close()

	req := httptest.NewRequest("POST", "/api/media/upload", body)
	req.Header.Set("Content-Type", writer.FormDataContentType())

	ctx := auth.WithUserID(req.Context(), "user-123")
	req = req.WithContext(ctx)

	rec := httptest.NewRecorder()
	h.Upload(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Errorf("expected 400 Bad Request, got %d", rec.Code)
	}

	var errorResponse map[string]string
	_ = json.NewDecoder(rec.Body).Decode(&errorResponse)
	if errorResponse["error"] != "unsupported file format" {
		t.Errorf("expected format error, got: %s", errorResponse["error"])
	}
}

func TestUpload_Unauthorized(t *testing.T) {
	mockStorage := &MockStorage{}
	h, _ := setupTestHandler(mockStorage)

	req := httptest.NewRequest("POST", "/api/media/upload", nil)

	rec := httptest.NewRecorder()
	h.Upload(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Errorf("expected 401, got %d", rec.Code)
	}
}

func TestDownload_Success(t *testing.T) {
	mockStorage := &MockStorage{
		DownloadFunc: func(ctx context.Context, bucket string, filename string) (io.ReadCloser, int64, string, error) {
			if filename != "file-uuid.enc" {
				return nil, 0, "", errors.New("wrong filename requested")
			}
			return io.NopCloser(strings.NewReader("encrypted bytes payload")), 22, "application/octet-stream", nil
		},
	}

	h, _ := setupTestHandler(mockStorage)

	req := httptest.NewRequest("GET", "/api/media/download/file-uuid.enc", nil)
	ctx := auth.WithUserID(req.Context(), "user-123")

	// Set chi URL Parameter
	chiCtx := chi.NewRouteContext()
	chiCtx.URLParams.Add("key", "file-uuid.enc")
	ctx = context.WithValue(ctx, chi.RouteCtxKey, chiCtx)
	req = req.WithContext(ctx)

	rec := httptest.NewRecorder()
	h.Download(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", rec.Code)
	}

	headers := rec.Result().Header
	if headers.Get("X-Content-Type-Options") != "nosniff" {
		t.Errorf("expected nosniff header, got: %s", headers.Get("X-Content-Type-Options"))
	}

	expectedDisp := `attachment; filename="file-uuid.enc"`
	if headers.Get("Content-Disposition") != expectedDisp {
		t.Errorf("expected Content-Disposition %s, got: %s", expectedDisp, headers.Get("Content-Disposition"))
	}

	bodyBytes, _ := io.ReadAll(rec.Body)
	if string(bodyBytes) != "encrypted bytes payload" {
		t.Errorf("expected payload, got: %s", string(bodyBytes))
	}
}

func TestDownload_NotFound(t *testing.T) {
	mockStorage := &MockStorage{
		DownloadFunc: func(ctx context.Context, bucket string, filename string) (io.ReadCloser, int64, string, error) {
			return nil, 0, "", fmt.Errorf("file not found")
		},
	}

	h, _ := setupTestHandler(mockStorage)

	req := httptest.NewRequest("GET", "/api/media/download/nonexistent.png", nil)
	ctx := auth.WithUserID(req.Context(), "user-123")

	chiCtx := chi.NewRouteContext()
	chiCtx.URLParams.Add("key", "nonexistent.png")
	ctx = context.WithValue(ctx, chi.RouteCtxKey, chiCtx)
	req = req.WithContext(ctx)

	rec := httptest.NewRecorder()
	h.Download(rec, req)

	if rec.Code != http.StatusNotFound {
		t.Errorf("expected 404, got %d", rec.Code)
	}
}

func TestUpload_PathTraversalSanitized(t *testing.T) {
	// This is already covered by UUID filename generation (step 5 of the handler),
	// but we verify it stays as is.
	mockStorage := &MockStorage{}
	h, _ := setupTestHandler(mockStorage)

	body := &bytes.Buffer{}
	writer := multipart.NewWriter(body)
	part, _ := writer.CreateFormFile("file", "../../../../etc/passwd.png")
	pngBytes := []byte{0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A}
	_, _ = part.Write(pngBytes)
	_ = writer.Close()

	req := httptest.NewRequest("POST", "/api/media/upload", body)
	req.Header.Set("Content-Type", writer.FormDataContentType())
	ctx := auth.WithUserID(req.Context(), "user-123")
	req = req.WithContext(ctx)

	rec := httptest.NewRecorder()
	h.Upload(rec, req)

	// Should succeed — UUID-based filename means original name is irrelevant.
	if rec.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", rec.Code)
	}
}

func TestUpload_DangerousMIMEType(t *testing.T) {
	// Test that a file with a .png extension but HTML content is rejected.
	mockStorage := &MockStorage{}
	h, _ := setupTestHandler(mockStorage)

	body := &bytes.Buffer{}
	writer := multipart.NewWriter(body)
	part, _ := writer.CreateFormFile("file", "xss.png")
	// HTML content disguised as a PNG file — magic-byte check should catch this.
	_, _ = part.Write([]byte("<!DOCTYPE html><html><script>alert('xss')</script></html>"))
	_ = writer.Close()

	req := httptest.NewRequest("POST", "/api/media/upload", body)
	req.Header.Set("Content-Type", writer.FormDataContentType())
	ctx := auth.WithUserID(req.Context(), "user-123")
	req = req.WithContext(ctx)

	rec := httptest.NewRecorder()
	h.Upload(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Errorf("expected 400 Bad Request for HTML content, got %d", rec.Code)
	}

	var errResp map[string]string
	_ = json.NewDecoder(rec.Body).Decode(&errResp)
	if errResp["error"] != "unsupported file format" {
		t.Errorf("expected unsupported file format error, got: %s", errResp["error"])
	}
}

func TestDownload_PathTraversalSanitized(t *testing.T) {
	var requestedKey string
	mockStorage := &MockStorage{
		DownloadFunc: func(ctx context.Context, bucket string, filename string) (io.ReadCloser, int64, string, error) {
			requestedKey = filename
			return io.NopCloser(strings.NewReader("data")), 4, "application/octet-stream", nil
		},
	}

	h, _ := setupTestHandler(mockStorage)

	// Try traversal payload
	req := httptest.NewRequest("GET", "/api/media/download/..%2f..%2fscary-file.enc", nil)
	ctx := auth.WithUserID(req.Context(), "user-123")

	chiCtx := chi.NewRouteContext()
	chiCtx.URLParams.Add("key", "../../scary-file.enc")
	ctx = context.WithValue(ctx, chi.RouteCtxKey, chiCtx)
	req = req.WithContext(ctx)

	rec := httptest.NewRecorder()
	h.Download(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", rec.Code)
	}

	if requestedKey != "scary-file.enc" {
		t.Errorf("expected traversal path to be stripped, but service requested: %s", requestedKey)
	}
}
