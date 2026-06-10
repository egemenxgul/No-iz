-- Migration: 000005_create_groups.up.sql

-- ─── Groups ──────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS groups (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name            VARCHAR(128)  NOT NULL,
    description     TEXT          NOT NULL DEFAULT '',
    avatar_url      TEXT          NOT NULL DEFAULT '',
    invite_link     VARCHAR(64)   UNIQUE,          -- short invite token
    is_private      BOOLEAN       NOT NULL DEFAULT FALSE,
    max_members     INTEGER       NOT NULL DEFAULT 5000,
    created_by      UUID          NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_groups_created_by ON groups(created_by);

-- Automatically update updated_at on row changes
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER groups_updated_at
    BEFORE UPDATE ON groups
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ─── Group Members ────────────────────────────────────────────────────────────
CREATE TYPE group_role AS ENUM ('owner', 'admin', 'member');

CREATE TABLE IF NOT EXISTS group_members (
    group_id    UUID        NOT NULL REFERENCES groups(id)  ON DELETE CASCADE,
    user_id     UUID        NOT NULL REFERENCES users(id)   ON DELETE CASCADE,
    role        group_role  NOT NULL DEFAULT 'member',
    joined_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (group_id, user_id)
);

CREATE INDEX idx_group_members_user  ON group_members(user_id);
CREATE INDEX idx_group_members_group ON group_members(group_id);

-- ─── Sender Key Distribution Records ─────────────────────────────────────────
-- Each (group_id, sender_id) pair has a Sender Key that other members store.
CREATE TABLE IF NOT EXISTS sender_keys (
    group_id        UUID    NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
    sender_id       UUID    NOT NULL REFERENCES users(id)  ON DELETE CASCADE,
    -- Encrypted sender key record (encrypted for each recipient individually — stored as JSON array)
    -- Structure: { "iteration": int, "chain_key": "base64", "signature_key": "base64" }
    distribution    TEXT    NOT NULL,
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (group_id, sender_id)
);

-- ─── Group Messages ───────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS group_messages (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id        UUID        NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
    sender_id       UUID        NOT NULL REFERENCES users(id)  ON DELETE CASCADE,

    -- Sender-key encrypted payload (server is blind)
    ciphertext      TEXT        NOT NULL,
    msg_type        VARCHAR(20) NOT NULL DEFAULT 'text',

    -- Sender Keys ratchet state
    iteration       INTEGER     NOT NULL DEFAULT 0,
    distribution_id VARCHAR(64) NOT NULL DEFAULT '',

    -- Disappearing messages
    expires_at      TIMESTAMPTZ,

    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_group_messages_group  ON group_messages(group_id, created_at DESC);
CREATE INDEX idx_group_messages_sender ON group_messages(sender_id);

-- ─── Delivery receipts (per-member) ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS group_message_receipts (
    message_id      UUID        NOT NULL REFERENCES group_messages(id) ON DELETE CASCADE,
    user_id         UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    delivered_at    TIMESTAMPTZ,
    read_at         TIMESTAMPTZ,
    PRIMARY KEY (message_id, user_id)
);

CREATE INDEX idx_group_receipts_user ON group_message_receipts(user_id, delivered_at);
