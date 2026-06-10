-- Migration: 000009_add_performance_indexes.down.sql
DROP INDEX IF EXISTS idx_devices_token_unique;
DROP INDEX IF EXISTS idx_devices_user_platform;
DROP INDEX IF EXISTS idx_users_phone;
DROP INDEX IF EXISTS idx_messages_delivered_at;
DROP INDEX IF EXISTS idx_messages_read_at;
