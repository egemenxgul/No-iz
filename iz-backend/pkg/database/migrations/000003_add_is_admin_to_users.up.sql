-- Migration: 000003_add_is_admin_to_users.up.sql

ALTER TABLE users ADD COLUMN is_admin BOOLEAN NOT NULL DEFAULT FALSE;
