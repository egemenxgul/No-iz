// cmd/migrate/main.go — iz-backend database migration CLI tool
//
// Usage:
//
//	migrate up              — apply all pending migrations
//	migrate down [n]        — roll back n steps (default 1); use "all" to roll back everything
//	migrate version         — show current migration version and dirty state
//	migrate status          — alias for version
//	migrate force <version> — force-set schema_migrations to a specific version (recovery only)
package main

import (
	"fmt"
	"os"
	"strconv"

	"github.com/no-iz/iz-backend/pkg/config"
	"github.com/no-iz/iz-backend/pkg/database"
)

func main() {
	if len(os.Args) < 2 {
		printUsage()
		os.Exit(1)
	}

	cfg, err := config.Load()
	if err != nil {
		fatalf("load config: %v", err)
	}

	command := os.Args[1]

	switch command {
	case "up":
		runUp(cfg)
	case "down":
		steps := 1
		if len(os.Args) >= 3 {
			if os.Args[2] == "all" {
				steps = -1
			} else {
				n, err := strconv.Atoi(os.Args[2])
				if err != nil || n < 1 {
					fatalf("invalid step count %q — must be a positive integer or 'all'", os.Args[2])
				}
				steps = n
			}
		}
		runDown(cfg, steps)
	case "version", "status":
		runVersion(cfg)
	case "force":
		if len(os.Args) < 3 {
			fatalf("'force' requires a version number argument")
		}
		v, err := strconv.Atoi(os.Args[2])
		if err != nil || v < 0 {
			fatalf("invalid version %q — must be a non-negative integer", os.Args[2])
		}
		runForce(cfg, v)
	default:
		fmt.Fprintf(os.Stderr, "unknown command %q\n\n", command)
		printUsage()
		os.Exit(1)
	}
}

// ── command implementations ────────────────────────────────────────────────────

func runUp(cfg *config.Config) {
	fmt.Println("▶  Applying pending migrations…")
	if err := database.RunMigrations(cfg); err != nil {
		fatalf("migrate up: %v", err)
	}
	v, dirty, err := database.GetCurrentVersion(cfg)
	if err != nil {
		fatalf("get version: %v", err)
	}
	fmt.Printf("✅  Migrations applied — now at version %d (dirty=%v)\n", v, dirty)
}

func runDown(cfg *config.Config, steps int) {
	if steps == -1 {
		fmt.Println("▼  Rolling back ALL migrations…")
	} else {
		fmt.Printf("▼  Rolling back %d migration step(s)…\n", steps)
	}
	if err := database.MigrateDown(cfg, steps); err != nil {
		fatalf("migrate down: %v", err)
	}
	v, dirty, err := database.GetCurrentVersion(cfg)
	if err != nil {
		fatalf("get version: %v", err)
	}
	if v == 0 && !dirty {
		fmt.Println("✅  All migrations rolled back — database is at clean state")
	} else {
		fmt.Printf("✅  Rollback done — now at version %d (dirty=%v)\n", v, dirty)
	}
}

func runVersion(cfg *config.Config) {
	v, dirty, err := database.GetCurrentVersion(cfg)
	if err != nil {
		fatalf("get version: %v", err)
	}
	if v == 0 && !dirty {
		fmt.Println("📋  No migrations applied yet (clean database)")
		return
	}
	dirtyStr := "clean"
	if dirty {
		dirtyStr = "⚠️  DIRTY — a migration failed mid-run; manual recovery or 'force' needed"
	}
	fmt.Printf("📋  Current version : %d\n", v)
	fmt.Printf("    State           : %s\n", dirtyStr)
}

func runForce(cfg *config.Config, version int) {
	fmt.Printf("⚠️  Force-setting schema_migrations version to %d (recovery mode)…\n", version)
	// golang-migrate Force requires an integer; use the ForceVersion wrapper
	if err := database.ForceVersion(cfg, version); err != nil {
		fatalf("force version: %v", err)
	}
	fmt.Printf("✅  Version forced to %d — run 'migrate up' to resume normal migration\n", version)
}

// ── helpers ───────────────────────────────────────────────────────────────────

func fatalf(format string, args ...interface{}) {
	fmt.Fprintf(os.Stderr, "❌  "+format+"\n", args...)
	os.Exit(1)
}

func printUsage() {
	fmt.Print(`iz-backend migration tool

Usage:
  migrate up              apply all pending migrations
  migrate down [n|all]    roll back n steps (default 1) or all
  migrate version         show current version & dirty state
  migrate status          alias for 'version'
  migrate force <n>       force schema_migrations to version n (recovery)

Environment variables (same as the server):
  DB_HOST, DB_PORT, DB_USER, DB_PASSWORD, DB_NAME, DB_SSLMODE
  (loaded automatically from .env if present)
`)
}
