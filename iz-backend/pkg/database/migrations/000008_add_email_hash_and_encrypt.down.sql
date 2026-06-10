-- Migration: 000008_add_email_hash_and_encrypt.down.sql
DROP INDEX IF EXISTS idx_users_email_hash;
ALTER TABLE users DROP COLUMN IF EXISTS email_hash;
