# iz-backend Makefile
# ──────────────────────────────────────────────────────────────────

BINARY_DIR   := bin
SERVER_BIN   := $(BINARY_DIR)/server
MIGRATE_BIN  := $(BINARY_DIR)/migrate

# Embedded migrations must stay in sync with the root migrations/ folder.
# Run `make sync-migrations` (or `make build`) whenever you add a new migration file.
MIGRATIONS_SRC  := migrations
MIGRATIONS_EMBED := pkg/database/migrations

.PHONY: all build build-server build-migrate sync-migrations \
        test test-race lint \
        migrate-up migrate-down migrate-version migrate-status \
        run clean help

# ── Default ──────────────────────────────────────────────────────

all: build

# ── Build ────────────────────────────────────────────────────────

## build: sync migrations, then compile server + migrate tool
build: sync-migrations build-server build-migrate

## build-server: compile the HTTP server binary
build-server:
	@mkdir -p $(BINARY_DIR)
	go build -o $(SERVER_BIN) ./cmd/server

## build-migrate: compile the database migration CLI
build-migrate:
	@mkdir -p $(BINARY_DIR)
	go build -o $(MIGRATE_BIN) ./cmd/migrate

## sync-migrations: copy root migrations/ → pkg/database/migrations/ (embed source)
## Run this whenever you add, rename, or delete a migration file.
sync-migrations:
	@echo "🔄  Syncing migrations to embed directory…"
	@mkdir -p $(MIGRATIONS_EMBED)
	@cp -r $(MIGRATIONS_SRC)/. $(MIGRATIONS_EMBED)/
	@echo "✅  Sync done — $(shell ls $(MIGRATIONS_EMBED)/*.sql 2>/dev/null | wc -l) SQL files embedded"

# ── Test ─────────────────────────────────────────────────────────

## test: run all Go tests
test:
	go test ./... -v

## test-race: run all Go tests with race detector
test-race:
	go test -race ./... -v

# ── Lint ─────────────────────────────────────────────────────────

## lint: run go vet + staticcheck
lint:
	go vet ./...
	@which staticcheck > /dev/null 2>&1 && staticcheck ./... || echo "(staticcheck not installed — skipping)"

# ── Migration helpers ─────────────────────────────────────────────
# These wrap the migrate binary. Make sure you've run `make build-migrate` first.

## migrate-up: apply all pending migrations
migrate-up: build-migrate
	@$(MIGRATE_BIN) up

## migrate-down: roll back the last migration step
migrate-down: build-migrate
	@$(MIGRATE_BIN) down 1

## migrate-version: show current migration version
migrate-version: build-migrate
	@$(MIGRATE_BIN) version

## migrate-status: alias for migrate-version
migrate-status: migrate-version

# ── Run ──────────────────────────────────────────────────────────

## run: sync migrations + build + start server
run: build
	@$(SERVER_BIN)

# ── Clean ────────────────────────────────────────────────────────

## clean: remove built binaries
clean:
	@rm -rf $(BINARY_DIR)
	@echo "🧹  Cleaned"

# ── Help ─────────────────────────────────────────────────────────

## help: display available make targets
help:
	@echo "iz-backend build targets:"
	@grep -E '^## ' Makefile | sed 's/^## /  /'
