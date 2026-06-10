package main

import (
	"context"
	"fmt"
	"log"

	"github.com/no-iz/iz-backend/internal/auth"
	"github.com/no-iz/iz-backend/pkg/config"
	"github.com/no-iz/iz-backend/pkg/database"
	"github.com/rs/zerolog"
	"os"
)

func main() {
	cfg, err := config.Load()
	if err != nil {
		log.Fatal(err)
	}

	db, err := database.NewPostgres(cfg)
	if err != nil {
		log.Fatal(err)
	}
	defer db.Close()

	logger := zerolog.New(os.Stdout)
	svc := auth.NewService(db, nil, cfg, logger)

	ctx := context.Background()

	// Try login with username
	fmt.Println("Attempting login with username 'admin'...")
	out, err := svc.Login(ctx, auth.LoginInput{
		EmailOrUsername: "admin",
		Password:        "admin123",
	})
	if err != nil {
		fmt.Printf("Login failed: %v\n", err)
	} else {
		fmt.Printf("Login success! UserID: %s, IsAdmin: %v\n", out.UserID, out.IsAdmin)
	}

	// Try login with email
	fmt.Println("\nAttempting login with email 'admin@no-iz.app'...")
	out, err = svc.Login(ctx, auth.LoginInput{
		EmailOrUsername: "admin@no-iz.app",
		Password:        "admin123",
	})
	if err != nil {
		fmt.Printf("Login failed: %v\n", err)
	} else {
		fmt.Printf("Login success! UserID: %s, IsAdmin: %v\n", out.UserID, out.IsAdmin)
	}
}
