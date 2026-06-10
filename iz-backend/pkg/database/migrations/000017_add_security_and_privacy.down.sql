-- Migration: 000017_add_security_and_privacy.down.sql

DROP TRIGGER IF EXISTS user_chat_settings_updated_at ON user_chat_settings;
DROP TABLE IF EXISTS user_chat_settings;

ALTER TABLE users DROP COLUMN IF EXISTS totp_secret;
ALTER TABLE users DROP COLUMN IF EXISTS is_totp_enabled;
