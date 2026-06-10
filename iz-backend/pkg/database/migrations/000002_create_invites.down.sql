-- Migration: 000002_create_invites.down.sql
DROP TABLE IF EXISTS user_invite_quotas;
DROP TABLE IF EXISTS invite_uses;
DROP TABLE IF EXISTS invite_codes;
