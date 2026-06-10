-- Migration: 000004_create_messages.up.sql

CREATE TABLE IF NOT EXISTS messages (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    recipient_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

    -- Encrypted payload (server is blind — never stores plaintext)
    ciphertext      TEXT NOT NULL,       -- base64 AES-256-GCM encrypted
    msg_type        VARCHAR(20) NOT NULL DEFAULT 'text', -- text|image|video|file|audio

    -- Double Ratchet header info
    ratchet_key     TEXT,                -- sender's current DH ratchet public key (base64)
    prev_counter    INTEGER NOT NULL DEFAULT 0,
    counter         INTEGER NOT NULL DEFAULT 0,

    -- Status
    delivered_at    TIMESTAMPTZ,
    read_at         TIMESTAMPTZ,

    -- Disappearing messages
    expires_at      TIMESTAMPTZ,

    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_messages_recipient ON messages(recipient_id, created_at DESC);
CREATE INDEX idx_messages_sender    ON messages(sender_id,    created_at DESC);
-- Conversation index: ordered pair so lookup works in both directions
CREATE INDEX idx_messages_convo ON messages(
    LEAST(sender_id::text, recipient_id::text),
    GREATEST(sender_id::text, recipient_id::text),
    created_at DESC
);
