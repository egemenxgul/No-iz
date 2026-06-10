-- Migration: 000004_create_messages.down.sql

DROP INDEX IF EXISTS idx_messages_convo;
DROP INDEX IF EXISTS idx_messages_sender;
DROP INDEX IF EXISTS idx_messages_recipient;
DROP TABLE IF EXISTS messages;
