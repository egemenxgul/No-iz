-- Migration: 000005_create_groups.down.sql

DROP TABLE IF EXISTS group_message_receipts;
DROP TABLE IF EXISTS group_messages;
DROP TABLE IF EXISTS sender_keys;
DROP TABLE IF EXISTS group_members;
DROP TABLE IF EXISTS groups;
DROP TYPE  IF EXISTS group_role;
