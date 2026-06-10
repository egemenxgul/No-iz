-- Migration: 000016_add_message_edits_and_reactions.down.sql

DROP TABLE IF EXISTS group_message_reactions;
DROP TABLE IF EXISTS message_reactions;

ALTER TABLE group_messages DROP COLUMN IF EXISTS edited_at;
ALTER TABLE messages DROP COLUMN IF EXISTS edited_at;
