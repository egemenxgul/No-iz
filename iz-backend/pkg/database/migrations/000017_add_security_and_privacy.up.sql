-- Migration: 000017_add_security_and_privacy.up.sql

-- 1. 2FA (TOTP) Alanları
ALTER TABLE users ADD COLUMN IF NOT EXISTS totp_secret TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_totp_enabled BOOLEAN NOT NULL DEFAULT FALSE;

-- 2. Sohbeti Sessize Alma (Mute Chats)
CREATE TABLE IF NOT EXISTS user_chat_settings (
    user_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    target_id     UUID NOT NULL, -- UUID of the user or group being muted
    muted_until   TIMESTAMPTZ,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, target_id)
);

CREATE INDEX idx_user_chat_settings_user ON user_chat_settings(user_id);

-- Auto-update trigger for user_chat_settings
CREATE TRIGGER user_chat_settings_updated_at
    BEFORE UPDATE ON user_chat_settings
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();
