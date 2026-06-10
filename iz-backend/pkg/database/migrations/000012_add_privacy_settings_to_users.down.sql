-- Migration: 000012_add_privacy_settings_to_users.down.sql

ALTER TABLE users DROP COLUMN IF EXISTS hide_last_seen;
ALTER TABLE users DROP COLUMN IF EXISTS hide_online;
ALTER TABLE users DROP COLUMN IF EXISTS hide_typing;
ALTER TABLE users DROP COLUMN IF EXISTS hide_read_receipts;
