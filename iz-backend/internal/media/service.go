package media

import (
	"context"
	"errors"
	"fmt"
	"io"

	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"
	"github.com/no-iz/iz-backend/pkg/config"
	"github.com/rs/zerolog"
)

// Service manages interactions with MinIO storage.
type Service struct {
	client *minio.Client
	cfg    *config.Config
	log    zerolog.Logger
}

// NewService creates and initializes a new storage Service.
func NewService(cfg *config.Config, log zerolog.Logger) (*Service, error) {
	logger := log.With().Str("svc", "media").Logger()

	// Initialize minio client
	client, err := minio.New(cfg.MinioEndpoint, &minio.Options{
		Creds:  credentials.NewStaticV4(cfg.MinioAccessKey, cfg.MinioSecretKey, ""),
		Secure: cfg.MinioUseSSL,
	})
	if err != nil {
		return nil, fmt.Errorf("failed to initialize minio client: %w", err)
	}

	s := &Service{
		client: client,
		cfg:    cfg,
		log:    logger,
	}

	// Ensure configured buckets exist
	if err := s.ensureBucket(context.Background(), cfg.MinioBucketMedia); err != nil {
		return nil, fmt.Errorf("failed to ensure media bucket: %w", err)
	}
	if err := s.ensureBucket(context.Background(), cfg.MinioBucketAvatars); err != nil {
		return nil, fmt.Errorf("failed to ensure avatars bucket: %w", err)
	}

	return s, nil
}

// ensureBucket checks if a bucket exists and creates it if it doesn't.
func (s *Service) ensureBucket(ctx context.Context, bucket string) error {
	exists, err := s.client.BucketExists(ctx, bucket)
	if err != nil {
		return fmt.Errorf("failed to check if bucket %s exists: %w", bucket, err)
	}

	if !exists {
		s.log.Info().Str("bucket", bucket).Msg("bucket does not exist, creating it")
		err = s.client.MakeBucket(ctx, bucket, minio.MakeBucketOptions{})
		if err != nil {
			return fmt.Errorf("failed to create bucket %s: %w", bucket, err)
		}
		s.log.Info().Str("bucket", bucket).Msg("bucket created successfully")
	}

	return nil
}

// UploadFile uploads a file stream directly to MinIO.
func (s *Service) UploadFile(ctx context.Context, bucket string, filename string, reader io.Reader, size int64, contentType string) (string, error) {
	s.log.Info().
		Str("bucket", bucket).
		Str("filename", filename).
		Int64("size", size).
		Str("content_type", contentType).
		Msg("uploading file to MinIO")

	info, err := s.client.PutObject(ctx, bucket, filename, reader, size, minio.PutObjectOptions{
		ContentType: contentType,
	})
	if err != nil {
		s.log.Error().Err(err).Str("filename", filename).Msg("failed to put object into MinIO")
		return "", fmt.Errorf("failed to upload file: %w", err)
	}

	s.log.Info().
		Str("bucket", bucket).
		Str("filename", filename).
		Str("etag", info.ETag).
		Int64("size", info.Size).
		Msg("file uploaded successfully")

	return filename, nil
}

// DownloadFile retrieves a file from MinIO and returns its read stream, size, content-type and error.
func (s *Service) DownloadFile(ctx context.Context, bucket string, filename string) (io.ReadCloser, int64, string, error) {
	s.log.Info().
		Str("bucket", bucket).
		Str("filename", filename).
		Msg("downloading file from MinIO")

	object, err := s.client.GetObject(ctx, bucket, filename, minio.GetObjectOptions{})
	if err != nil {
		s.log.Error().Err(err).Str("filename", filename).Msg("failed to get object from MinIO")
		return nil, 0, "", fmt.Errorf("failed to get file: %w", err)
	}

	// Verify if object exists by retrieving stats
	stat, err := object.Stat()
	if err != nil {
		// Close object to avoid resource leaks
		_ = object.Close()
		
		var errResponse minio.ErrorResponse
		if errors.As(err, &errResponse) && errResponse.Code == "NoSuchKey" {
			s.log.Warn().Str("filename", filename).Msg("object not found in MinIO")
			return nil, 0, "", fmt.Errorf("file not found")
		}
		s.log.Error().Err(err).Str("filename", filename).Msg("failed to get object metadata from MinIO")
		return nil, 0, "", fmt.Errorf("failed to get file info: %w", err)
	}

	return object, stat.Size, stat.ContentType, nil
}
