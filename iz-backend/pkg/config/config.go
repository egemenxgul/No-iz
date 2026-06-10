package config

import (
	"fmt"
	"os"
	"strconv"
	"time"

	"github.com/joho/godotenv"
)

// Config holds all application configuration loaded from environment variables.
type Config struct {
	// App
	AppEnv    string
	AppPort   string
	AppSecret string

	// JWT
	JWTAccessSecret  string
	JWTRefreshSecret string
	JWTAccessTTL     time.Duration
	JWTRefreshTTL    time.Duration

	// PostgreSQL
	DBHost     string
	DBPort     string
	DBName     string
	DBUser     string
	DBPassword string
	DBSSLMode  string
	DBMaxConns int

	// Redis
	RedisHost     string
	RedisPort     string
	RedisPassword string
	RedisDB       int

	// MinIO
	MinioEndpoint   string
	MinioAccessKey  string
	MinioSecretKey  string
	MinioUseSSL     bool
	MinioBucketMedia   string
	MinioBucketAvatars string

	// Message TTL
	MsgDefaultTTLDays int
	MsgMaxTTLDays     int
	MsgMinTTLDays     int

	// Invite
	InviteUserMonthlyLimit int
	InviteUserCodeMax      int
	InviteCodeLength       int

	// Argon2id
	Argon2Memory      uint32
	Argon2Iterations  uint32
	Argon2Parallelism uint8

	// Security
	MasterKey string
}

// Load reads the .env file (if present) and then environment variables.
func Load() (*Config, error) {
	// Best-effort: load .env if it exists
	for _, envFile := range []string{".env", "../.env", "../../.env"} {
		if err := godotenv.Load(envFile); err == nil {
			break
		}
	}

	cfg := &Config{}
	var errs []string

	// App
	cfg.AppEnv = getEnv("APP_ENV", "development")
	cfg.AppPort = getEnv("APP_PORT", "8080")
	cfg.AppSecret = mustEnv("APP_SECRET", &errs)

	// JWT
	cfg.JWTAccessSecret = mustEnv("JWT_ACCESS_SECRET", &errs)
	cfg.JWTRefreshSecret = mustEnv("JWT_REFRESH_SECRET", &errs)
	cfg.JWTAccessTTL = parseDuration("JWT_ACCESS_TTL", 15*time.Minute)
	cfg.JWTRefreshTTL = parseDuration("JWT_REFRESH_TTL", 30*24*time.Hour)

	// PostgreSQL
	cfg.DBHost = getEnv("DB_HOST", "localhost")
	cfg.DBPort = getEnv("DB_PORT", "5432")
	cfg.DBName = getEnv("DB_NAME", "iz_db")
	cfg.DBUser = getEnv("DB_USER", "iz_user")
	cfg.DBPassword = getEnv("DB_PASSWORD", "iz_password")
	cfg.DBSSLMode = getEnv("DB_SSL_MODE", "require")
	cfg.DBMaxConns = parseInt("DB_MAX_CONNS", 25)

	// Redis
	cfg.RedisHost = getEnv("REDIS_HOST", "localhost")
	cfg.RedisPort = getEnv("REDIS_PORT", "6379")
	cfg.RedisPassword = getEnv("REDIS_PASSWORD", "")
	cfg.RedisDB = parseInt("REDIS_DB", 0)

	// MinIO
	cfg.MinioEndpoint = getEnv("MINIO_ENDPOINT", "localhost:9000")
	cfg.MinioAccessKey = getEnv("MINIO_ACCESS_KEY", "iz_minio_access")
	cfg.MinioSecretKey = getEnv("MINIO_SECRET_KEY", "iz_minio_secret_change_me")
	cfg.MinioUseSSL = parseBool("MINIO_USE_SSL", false)
	cfg.MinioBucketMedia = getEnv("MINIO_BUCKET_MEDIA", "iz-media")
	cfg.MinioBucketAvatars = getEnv("MINIO_BUCKET_AVATARS", "iz-avatars")

	// Message TTL
	cfg.MsgDefaultTTLDays = parseInt("MSG_DEFAULT_TTL_DAYS", 30)
	cfg.MsgMaxTTLDays = parseInt("MSG_MAX_TTL_DAYS", 90)
	cfg.MsgMinTTLDays = parseInt("MSG_MIN_TTL_DAYS", 1)

	// Invite
	cfg.InviteUserMonthlyLimit = parseInt("INVITE_USER_MONTHLY_LIMIT", 5)
	cfg.InviteUserCodeMax = parseInt("INVITE_USER_CODE_MAX", 5)
	cfg.InviteCodeLength = parseInt("INVITE_CODE_LENGTH", 8)

	// Argon2id
	cfg.Argon2Memory = uint32(parseInt("ARGON2_MEMORY", 65536))
	cfg.Argon2Iterations = uint32(parseInt("ARGON2_ITERATIONS", 3))
	cfg.Argon2Parallelism = uint8(parseInt("ARGON2_PARALLELISM", 4))

	// Security
	cfg.MasterKey = getEnv("MASTER_KEY", cfg.AppSecret)

	if len(errs) > 0 {
		return nil, fmt.Errorf("missing required env vars: %v", errs)
	}

	return cfg, nil
}

// DSN returns the PostgreSQL connection string.
func (c *Config) DSN() string {
	return fmt.Sprintf(
		"host=%s port=%s dbname=%s user=%s password=%s sslmode=%s pool_max_conns=%d",
		c.DBHost, c.DBPort, c.DBName, c.DBUser, c.DBPassword, c.DBSSLMode, c.DBMaxConns,
	)
}

// RedisAddr returns host:port for Redis.
func (c *Config) RedisAddr() string {
	return c.RedisHost + ":" + c.RedisPort
}

// IsProd returns true when running in production.
func (c *Config) IsProd() bool {
	return c.AppEnv == "production"
}

// --- helpers ---

func getEnv(key, defaultVal string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return defaultVal
}

func mustEnv(key string, errs *[]string) string {
	v := os.Getenv(key)
	if v == "" {
		*errs = append(*errs, key)
	}
	return v
}

func parseInt(key string, defaultVal int) int {
	v := os.Getenv(key)
	if v == "" {
		return defaultVal
	}
	n, err := strconv.Atoi(v)
	if err != nil {
		return defaultVal
	}
	return n
}

func parseBool(key string, defaultVal bool) bool {
	v := os.Getenv(key)
	if v == "" {
		return defaultVal
	}
	b, err := strconv.ParseBool(v)
	if err != nil {
		return defaultVal
	}
	return b
}

func parseDuration(key string, defaultVal time.Duration) time.Duration {
	v := os.Getenv(key)
	if v == "" {
		return defaultVal
	}
	d, err := time.ParseDuration(v)
	if err != nil {
		return defaultVal
	}
	return d
}
