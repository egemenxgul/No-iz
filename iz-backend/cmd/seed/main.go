package main

import (
	"context"
	"crypto/rand"
	"encoding/base64"
	"fmt"
	"log"

	"github.com/google/uuid"
	"github.com/no-iz/iz-backend/pkg/config"
	"github.com/no-iz/iz-backend/pkg/database"
	"golang.org/x/crypto/argon2"
	"crypto/aes"
	"crypto/cipher"
	"crypto/hmac"
	"crypto/sha256"
	"strings"
)

func main() {
	fmt.Println("Starting seed...")
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("failed to load config: %v", err)
	}

	db, err := database.NewPostgres(cfg)
	if err != nil {
		log.Fatalf("failed to connect to db: %v", err)
	}
	defer db.Close()

	ctx := context.Background()

	// Check if admin already exists
	var count int
	_ = db.QueryRow(ctx, "SELECT COUNT(1) FROM users WHERE username = 'admin'").Scan(&count)
	if count > 0 {
		fmt.Println("Admin user already exists. Exiting.")
		return
	}

	// Generate salt and hash for default password "admin123"
	password := "admin123"
	salt := make([]byte, 16)
	rand.Read(salt)

	hash := argon2.IDKey(
		[]byte(password),
		salt,
		cfg.Argon2Iterations,
		cfg.Argon2Memory,
		cfg.Argon2Parallelism,
		32,
	)

	passwordHash := fmt.Sprintf("$argon2id$%s$%s",
		base64.RawStdEncoding.EncodeToString(salt),
		base64.RawStdEncoding.EncodeToString(hash),
	)

	// Create a dummy identity key for admin (base64)
	dummyKey := base64.StdEncoding.EncodeToString([]byte("dummy_admin_identity_key"))

	adminID := uuid.New()

	// Encrypt & Hash admin email
	adminEmail := "admin@no-iz.app"
	
	// Hash
	h := hmac.New(sha256.New, []byte(cfg.MasterKey))
	h.Write([]byte(strings.ToLower(strings.TrimSpace(adminEmail))))
	emailHash := base64.RawURLEncoding.EncodeToString(h.Sum(nil))

	// Encrypt
	key := sha256.Sum256([]byte(cfg.MasterKey))
	block, _ := aes.NewCipher(key[:])
	gcm, _ := cipher.NewGCM(block)
	nonce := make([]byte, gcm.NonceSize())
	rand.Read(nonce)
	ciphertext := gcm.Seal(nonce, nonce, []byte(adminEmail), nil)
	emailEnc := base64.StdEncoding.EncodeToString(ciphertext)

	query := `
		INSERT INTO users (
			id, username, email, email_hash, password_hash, display_name,
			identity_key, signed_prekey, signed_prekey_sig, is_admin
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $7, $7, TRUE)
	`
	
	_, err = db.Exec(ctx, query,
		adminID, "admin", emailEnc, emailHash, passwordHash, "System Admin", dummyKey,
	)
	
	if err != nil {
		log.Fatalf("failed to create admin user: %v", err)
	}

	// Also generate an initial "HELLO" invite code for the admin
	_, err = db.Exec(ctx, `
		INSERT INTO invite_codes (code, created_by_id, max_uses, use_count, is_active)
		VALUES ('HELLO', NULL, 1000, 0, TRUE)
	`)
	if err != nil {
		log.Printf("Warning: failed to create HELLO invite code: %v", err)
	} else {
		fmt.Println("Initial invite code 'HELLO' (1000 uses) created successfully.")
	}

	fmt.Printf("Admin user created successfully!\nEmail: admin@no-iz.app\nUsername: admin\nPassword: %s\n", password)
}
