-- Migration: 000018_add_pinned_messages.down.sql

ALTER TABLE messages DROP COLUMN IF EXISTS is_pinned;
ALTER TABLE group_messages DROP COLUMN IF EXISTS is_pinned;
