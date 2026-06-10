-- Migration: 000009_add_performance_indexes.up.sql
-- Adds indexes and columns for features added in Sprint 2:
--   - Read receipts (read_at queries)
--   - Phone number lookup (contact matching)
--   - Device push tokens (notification delivery)
--   - Message delivery status index

-- ── Read receipt index ────────────────────────────────────────────────────────
-- Speeds up "mark all unread messages as read" queries in handleMarkRead.
CREATE INDEX IF NOT EXISTS idx_messages_read_at
    ON messages(recipient_id, read_at)
    WHERE read_at IS NULL;

-- ── Delivery status index ─────────────────────────────────────────────────────
-- Speeds up queries finding undelivered messages for a recipient.
CREATE INDEX IF NOT EXISTS idx_messages_delivered_at
    ON messages(recipient_id, delivered_at)
    WHERE delivered_at IS NULL;

-- ── Phone number index ────────────────────────────────────────────────────────
-- Speeds up contact matching by phone number (MatchContacts endpoint).
-- The index is on the raw phone column which stores normalized E.164 numbers.
CREATE INDEX IF NOT EXISTS idx_users_phone
    ON users(phone)
    WHERE phone IS NOT NULL;

-- ── Device token index ───────────────────────────────────────────────────────
-- Speeds up push notification delivery lookup (FCM/APNs token by user+platform).
CREATE INDEX IF NOT EXISTS idx_devices_user_platform
    ON user_devices(user_id, platform);

-- ── Unique device token per platform ─────────────────────────────────────────
-- Prevents duplicate push tokens from being registered.
-- Uses a partial unique index: only enforce uniqueness when token is non-null.
CREATE UNIQUE INDEX IF NOT EXISTS idx_devices_token_unique
    ON user_devices(device_token)
    WHERE device_token IS NOT NULL;
