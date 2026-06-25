DROP INDEX IF EXISTS idx_users_reset_token;
DROP INDEX IF EXISTS idx_users_apple_id;
ALTER TABLE users DROP COLUMN IF EXISTS password_reset_expires_at;
ALTER TABLE users DROP COLUMN IF EXISTS password_reset_token;
ALTER TABLE users DROP COLUMN IF EXISTS apple_id;
