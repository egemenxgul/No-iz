-- Migration: 000015_create_backups.up.sql

CREATE TABLE IF NOT EXISTS backups (
    user_id        UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    encrypted_blob TEXT NOT NULL,
    salt           VARCHAR(256) NOT NULL,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
