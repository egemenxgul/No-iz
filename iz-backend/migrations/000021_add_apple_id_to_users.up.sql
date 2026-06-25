-- Apple Sign In için apple_id kolonu
ALTER TABLE users ADD COLUMN IF NOT EXISTS apple_id TEXT UNIQUE;
-- Şifremi unuttum için password_reset_token ve süresi
ALTER TABLE users ADD COLUMN IF NOT EXISTS password_reset_token TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS password_reset_expires_at TIMESTAMPTZ;
CREATE INDEX IF NOT EXISTS idx_users_apple_id ON users(apple_id) WHERE apple_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_users_reset_token ON users(password_reset_token) WHERE password_reset_token IS NOT NULL;
