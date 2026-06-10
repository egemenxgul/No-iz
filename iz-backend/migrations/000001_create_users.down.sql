-- Migration: 000001_create_users.down.sql
DROP TRIGGER IF EXISTS users_updated_at ON users;
DROP FUNCTION IF EXISTS update_updated_at;
DROP TABLE IF EXISTS refresh_tokens;
DROP TABLE IF EXISTS user_devices;
DROP TABLE IF EXISTS user_prekeys;
DROP TABLE IF EXISTS users;
