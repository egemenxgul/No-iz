package database

import (
	"database/sql"
	"embed"
	"errors"
	"fmt"
	"net/url"

	"github.com/golang-migrate/migrate/v4"
	"github.com/golang-migrate/migrate/v4/database/postgres"
	"github.com/golang-migrate/migrate/v4/source/iofs"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/stdlib"
	"github.com/no-iz/iz-backend/pkg/config"
)

// migrationsFS embeds all SQL migration files into the compiled binary.
// This ensures migrations work correctly in Docker containers and any
// deployment environment without requiring the migrations/ folder to be
// present alongside the binary at runtime.
//
//go:embed migrations
var migrationsFS embed.FS

// newMigrator creates a golang-migrate instance backed by the embedded FS.
func newMigrator(cfg *config.Config) (*migrate.Migrate, error) {
	// Source: embedded SQL files under the "migrations" sub-directory of this package
	src, err := iofs.New(migrationsFS, "migrations")
	if err != nil {
		return nil, fmt.Errorf("create migration source: %w", err)
	}

	// golang-migrate needs a *sql.DB — pgxpool cannot be used directly here.
	// We use pgx's stdlib adapter to open a *sql.DB from the DSN.
	dsn := fmt.Sprintf(
		"postgres://%s:%s@%s:%s/%s?sslmode=%s",
		url.QueryEscape(cfg.DBUser), url.QueryEscape(cfg.DBPassword),
		cfg.DBHost, cfg.DBPort,
		cfg.DBName, cfg.DBSSLMode,
	)
	connCfg, err := pgx.ParseConfig(dsn)
	if err != nil {
		return nil, fmt.Errorf("parse dsn for migrator: %w", err)
	}
	sqlDB := stdlib.OpenDB(*connCfg)

	driver, err := postgres.WithInstance(sqlDB, &postgres.Config{})
	if err != nil {
		sqlDB.Close()
		return nil, fmt.Errorf("create postgres migrate driver: %w", err)
	}

	m, err := migrate.NewWithInstance("iofs", src, cfg.DBName, driver)
	if err != nil {
		return nil, fmt.Errorf("create migrator: %w", err)
	}
	return m, nil
}

// openSQLDB opens a *sql.DB for non-migrate use (e.g. health checks).
func openSQLDB(cfg *config.Config) (*sql.DB, error) {
	dsn := fmt.Sprintf(
		"postgres://%s:%s@%s:%s/%s?sslmode=%s",
		url.QueryEscape(cfg.DBUser), url.QueryEscape(cfg.DBPassword),
		cfg.DBHost, cfg.DBPort,
		cfg.DBName, cfg.DBSSLMode,
	)
	connCfg, err := pgx.ParseConfig(dsn)
	if err != nil {
		return nil, fmt.Errorf("parse dsn: %w", err)
	}
	return stdlib.OpenDB(*connCfg), nil
}

// RunMigrations applies all pending UP migrations.
// It is idempotent: calling it when the database is already at the latest version is a no-op.
func RunMigrations(cfg *config.Config) error {
	m, err := newMigrator(cfg)
	if err != nil {
		return err
	}
	defer m.Close()

	if err := m.Up(); err != nil && !errors.Is(err, migrate.ErrNoChange) {
		return fmt.Errorf("migrate up: %w", err)
	}
	return nil
}

// MigrateDown rolls back exactly n migration steps.
// Pass -1 to roll back ALL migrations (full teardown).
func MigrateDown(cfg *config.Config, steps int) error {
	m, err := newMigrator(cfg)
	if err != nil {
		return err
	}
	defer m.Close()

	if steps == -1 {
		if err := m.Down(); err != nil && !errors.Is(err, migrate.ErrNoChange) {
			return fmt.Errorf("migrate down all: %w", err)
		}
		return nil
	}
	if err := m.Steps(-steps); err != nil && !errors.Is(err, migrate.ErrNoChange) {
		return fmt.Errorf("migrate down %d step(s): %w", steps, err)
	}
	return nil
}

// GetCurrentVersion returns the current applied migration version and
// whether the database is in a dirty (failed mid-migration) state.
// Returns version=0, dirty=false if no migrations have been applied yet.
func GetCurrentVersion(cfg *config.Config) (version uint, dirty bool, err error) {
	m, mErr := newMigrator(cfg)
	if mErr != nil {
		return 0, false, mErr
	}
	defer m.Close()

	version, dirty, err = m.Version()
	if errors.Is(err, migrate.ErrNilVersion) {
		return 0, false, nil // clean slate — no migrations applied
	}
	return version, dirty, err
}

// ForceVersion force-sets the schema_migrations table to the given version
// without running any migration SQL. Use this ONLY for recovery from a dirty state
// after manually fixing the underlying issue.
func ForceVersion(cfg *config.Config, version int) error {
	m, err := newMigrator(cfg)
	if err != nil {
		return err
	}
	defer m.Close()

	if err := m.Force(version); err != nil {
		return fmt.Errorf("force version %d: %w", version, err)
	}
	return nil
}
