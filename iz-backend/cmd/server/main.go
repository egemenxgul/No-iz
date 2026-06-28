package main

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/no-iz/iz-backend/internal/auth"
	"github.com/no-iz/iz-backend/internal/call"
	"github.com/no-iz/iz-backend/internal/community"
	"github.com/no-iz/iz-backend/internal/group"
	"github.com/no-iz/iz-backend/internal/invite"
	"github.com/no-iz/iz-backend/internal/media"
	"github.com/no-iz/iz-backend/internal/messaging"
	"github.com/no-iz/iz-backend/internal/notification"
	"github.com/no-iz/iz-backend/internal/server"
	"github.com/no-iz/iz-backend/internal/social"
	"github.com/no-iz/iz-backend/internal/story"
	"github.com/no-iz/iz-backend/internal/report"
	"github.com/no-iz/iz-backend/internal/backup"
	"github.com/no-iz/iz-backend/internal/economy"
	"github.com/no-iz/iz-backend/pkg/config"
	"github.com/no-iz/iz-backend/pkg/database"
	"github.com/no-iz/iz-backend/pkg/logger"
)

func main() {
	// Load config
	cfg, err := config.Load()
	if err != nil {
		fmt.Fprintf(os.Stderr, "failed to load config: %v\n", err)
		os.Exit(1)
	}

	// Init logger
	log := logger.New(cfg.AppEnv)
	log.Info().Str("env", cfg.AppEnv).Str("port", cfg.AppPort).Msg("starting iz backend")

	// Connect to PostgreSQL
	db, err := database.NewPostgres(cfg)
	if err != nil {
		log.Fatal().Err(err).Msg("failed to connect to postgres")
	}
	defer db.Close()
	log.Info().Msg("connected to postgres")

	// Connect to Redis
	rdb, err := database.NewRedis(cfg)
	if err != nil {
		log.Fatal().Err(err).Msg("failed to connect to redis")
	}
	defer rdb.Close()
	log.Info().Msg("connected to redis")

	// Run DB migrations
	if err := database.RunMigrations(cfg); err != nil {
		log.Fatal().Err(err).Msg("failed to run migrations")
	}
	log.Info().Msg("migrations applied")

	// Build service dependencies
	authSvc := auth.NewService(db, rdb, cfg, log)

	inviteRepo := invite.NewRepository(db)
	inviteSvc := invite.NewService(inviteRepo, cfg, log)

	// Notifications
	notificationRepo := notification.NewRepository(db)
	notificationSvc := notification.NewService(db, notificationRepo, log)
	notificationHandler := notification.NewHandler(notificationSvc, log)

	// Social (Friendship & Message Requests)
	socialRepo := social.NewRepository(db)
	socialSvc := social.NewService(socialRepo, log)
	socialHandler := social.NewHandler(socialSvc, log)

	// Messaging
	msgRepo := messaging.NewRepository(db)
	msgHub := messaging.NewHub(msgRepo, log)
	msgSvc := messaging.NewService(msgRepo, msgHub, notificationSvc, log)
	msgSvc.SetSocialRepo(socialRepo) // Wire social repository to messaging service
	msgHandler := messaging.NewHandler(msgHub, msgRepo, msgSvc, log)

	// Groups
	groupRepo := group.NewRepository(db)
	groupSvc := group.NewService(groupRepo, msgHub, log)
	groupHandler := group.NewHandler(groupSvc, log)

	// Wire group service into ws handler (breaks import cycle)
	msgHandler.SetGroupSvc(groupSvc)

	// Communities
	communityRepo := community.NewRepository(db)
	communitySvc := community.NewService(communityRepo, log)
	communityHandler := community.NewHandler(communitySvc, log)

	// Economy
	economyRepo := economy.NewRepository(db)
	economySvc := economy.NewService(economyRepo, log)
	economyHandler := economy.NewHandler(economySvc, log)
	
	// Start Economy Cron Worker
	economy.StartCronWorker(context.Background(), economyRepo, log)

	// Calls (WebRTC Signaling)
	callRepo := call.NewRepository(db)
	callSvc := call.NewService(callRepo, msgHub, notificationSvc, economySvc, authSvc, log)
	callSvc.SetSocialRepo(socialRepo) // Inject social repository to check user blocks in calls
	callHandler := call.NewHandler(callSvc, log)

	// Wire call service into ws handler
	msgHandler.SetCallSvc(callSvc)

	// Media Storage Service (MinIO)
	mediaSvc, err := media.NewService(cfg, log)
	if err != nil {
		log.Fatal().Err(err).Msg("failed to initialize media service")
	}
	mediaHandler := media.NewHandler(mediaSvc, economySvc, cfg, log)

	// E2EE Stories
	storyRepo := story.NewRepository(db)
	storySvc := story.NewService(storyRepo, log)
	storyHandler := story.NewHandler(storySvc, log)

	// Abuse Reports
	reportRepo := report.NewRepository(db)
	reportSvc := report.NewService(reportRepo, log)
	reportHandler := report.NewHandler(reportSvc, log)

	// Zero-Knowledge Backups
	backupRepo := backup.NewRepository(db)
	backupSvc := backup.NewService(backupRepo, log)
	backupHandler := backup.NewHandler(backupSvc, log)

	// Build HTTP server
	srv := server.New(cfg, log, rdb, authSvc, inviteSvc, msgHandler, groupHandler, communityHandler, callHandler, mediaHandler, socialHandler, storyHandler, reportHandler, backupHandler, notificationHandler, economyHandler)

	httpSrv := &http.Server{
		Addr:         ":" + cfg.AppPort,
		Handler:      srv.Router(),
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	// Start server in goroutine
	go func() {
		log.Info().Str("addr", httpSrv.Addr).Msg("iz backend listening")
		if err := httpSrv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatal().Err(err).Msg("server error")
		}
	}()

	// Graceful shutdown on SIGINT/SIGTERM
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.Info().Msg("shutting down gracefully...")
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	if err := httpSrv.Shutdown(ctx); err != nil {
		log.Error().Err(err).Msg("shutdown error")
	}
	log.Info().Msg("iz backend stopped")
}
