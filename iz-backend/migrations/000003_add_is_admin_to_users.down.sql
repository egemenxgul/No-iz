-- Migration: 000003_add_is_admin_to_users.down.sql

ALTER TABLE users DROP COLUMN is_admin;
