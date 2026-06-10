-- Migration: 000002_create_invites.up.sql
-- Invite system: admin codes + user-generated codes

-- Admin-created invite codes (custom codes like "HELLO")
CREATE TABLE IF NOT EXISTS invite_codes (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code            VARCHAR(32)  NOT NULL UNIQUE,
    created_by_id   UUID         REFERENCES users(id) ON DELETE SET NULL, -- NULL = admin
    max_uses        INTEGER      NOT NULL DEFAULT 1,
    use_count       INTEGER      NOT NULL DEFAULT 0,
    is_active       BOOLEAN      NOT NULL DEFAULT TRUE,
    expires_at      TIMESTAMPTZ,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_invite_codes_code   ON invite_codes(code);
CREATE INDEX idx_invite_codes_active ON invite_codes(is_active, expires_at);

-- Track which user used which code
CREATE TABLE IF NOT EXISTS invite_uses (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code_id         UUID        NOT NULL REFERENCES invite_codes(id) ON DELETE CASCADE,
    used_by_id      UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    used_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(code_id, used_by_id)
);

CREATE INDEX idx_invite_uses_code   ON invite_uses(code_id);
CREATE INDEX idx_invite_uses_user   ON invite_uses(used_by_id);

-- Monthly usage tracking per user (reset each month)
CREATE TABLE IF NOT EXISTS user_invite_quotas (
    user_id         UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    month           DATE        NOT NULL,  -- first day of month (2025-01-01)
    codes_generated INTEGER     NOT NULL DEFAULT 0,
    PRIMARY KEY (user_id, month)
);
