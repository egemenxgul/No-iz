-- Migration: 000024_create_vault_messages.up.sql

CREATE TABLE IF NOT EXISTS vault_messages (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    conversation_id UUID NOT NULL,
    ciphertext TEXT NOT NULL,
    msg_type VARCHAR(50) NOT NULL,
    original_created_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_vault_messages_user_conv ON vault_messages(user_id, conversation_id, original_created_at DESC);
