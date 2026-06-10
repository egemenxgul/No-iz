-- Migration: 000008_add_email_hash_and_encrypt.up.sql
ALTER TABLE users ADD COLUMN email_hash TEXT;

-- Drop old index and unique constraint from email column (it's now encrypted)
DROP INDEX IF EXISTS idx_users_email;
ALTER TABLE users DROP CONSTRAINT IF EXISTS users_email_key;

-- Add unique index for email hash
CREATE UNIQUE INDEX idx_users_email_hash ON users(email_hash);
