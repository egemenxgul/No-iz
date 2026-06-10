package main

import (
	"context"
	"crypto/rand"
	"encoding/base64"
	"fmt"
	"log"

	"github.com/no-iz/iz-backend/pkg/config"
	"github.com/no-iz/iz-backend/pkg/database"
	"golang.org/x/crypto/argon2"
)

func main() {
	fmt.Println("Resetting admin password to 'admin123'...")
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("failed to load config: %v", err)
	}

	db, err := database.NewPostgres(cfg)
	if err != nil {
		log.Fatalf("failed to connect to db: %v", err)
	}
	defer db.Close()

	password := "admin123"
	salt := make([]byte, 16)
	if _, err := rand.Read(salt); err != nil {
		log.Fatal(err)
	}

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

	res, err := db.Exec(context.Background(), 
		"UPDATE users SET password_hash = $1 WHERE username = 'admin'", 
		passwordHash,
	)
	if err != nil {
		log.Fatalf("failed to update password: %v", err)
	}

	if res.RowsAffected() == 0 {
		fmt.Println("Error: Admin user not found.")
	} else {
		fmt.Println("Admin password successfully reset to 'admin123'.")
	}
}
