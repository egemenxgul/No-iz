-- Migration: 000001_create_users.up.sql
-- Users table — core identity for iz platform

CREATE TABLE IF NOT EXISTS users (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username        VARCHAR(32)  NOT NULL UNIQUE,
    email           VARCHAR(255) NOT NULL UNIQUE,
    phone           VARCHAR(20)  UNIQUE,
    password_hash   TEXT         NOT NULL,

    -- Display
    display_name    VARCHAR(64)  NOT NULL,
    bio             TEXT         DEFAULT '',
    avatar_url      TEXT         DEFAULT '',

    -- Keys (Signal Protocol)
    identity_key        TEXT NOT NULL,  -- X25519 public key (base64)
    signed_prekey       TEXT NOT NULL,  -- Signed PreKey (base64)
    signed_prekey_sig   TEXT NOT NULL,  -- Signature of signed prekey

    -- Account state
    is_verified     BOOLEAN      NOT NULL DEFAULT FALSE,
    is_banned       BOOLEAN      NOT NULL DEFAULT FALSE,
    is_deleted      BOOLEAN      NOT NULL DEFAULT FALSE,

    -- Invite tracking
    invited_by_id   UUID REFERENCES users(id) ON DELETE SET NULL,
    show_invited_by BOOLEAN NOT NULL DEFAULT TRUE,

    -- Subscription
    subscription_tier   VARCHAR(20) NOT NULL DEFAULT 'free', -- free | pro | creator
    subscription_until  TIMESTAMPTZ,

    -- Timestamps
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    last_seen_at    TIMESTAMPTZ
);

-- Indexes
CREATE INDEX idx_users_username    ON users(username);
CREATE INDEX idx_users_email       ON users(email);
CREATE INDEX idx_users_invited_by  ON users(invited_by_id);
CREATE INDEX idx_users_subscription ON users(subscription_tier);

-- Auto-update updated_at
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- One-time prekeys pool (Signal Protocol)
CREATE TABLE IF NOT EXISTS user_prekeys (
    id          BIGSERIAL    PRIMARY KEY,
    user_id     UUID         NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    key_id      INTEGER      NOT NULL,
    public_key  TEXT         NOT NULL,
    used        BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE(user_id, key_id)
);

CREATE INDEX idx_prekeys_user_unused ON user_prekeys(user_id, used) WHERE used = FALSE;

-- User devices (multi-device support)
CREATE TABLE IF NOT EXISTS user_devices (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    device_name     VARCHAR(64) NOT NULL,
    device_token    TEXT,           -- FCM/APNs push token
    platform        VARCHAR(10) NOT NULL, -- ios | android | web
    identity_key    TEXT        NOT NULL, -- device-specific key
    last_active_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_devices_user ON user_devices(user_id);

-- Refresh tokens
CREATE TABLE IF NOT EXISTS refresh_tokens (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    device_id   UUID        REFERENCES user_devices(id) ON DELETE CASCADE,
    token_hash  TEXT        NOT NULL UNIQUE,
    expires_at  TIMESTAMPTZ NOT NULL,
    revoked     BOOLEAN     NOT NULL DEFAULT FALSE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_refresh_tokens_user   ON refresh_tokens(user_id);
CREATE INDEX idx_refresh_tokens_hash   ON refresh_tokens(token_hash);
