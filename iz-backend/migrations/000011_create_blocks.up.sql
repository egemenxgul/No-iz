-- Migration: 000011_create_blocks.up.sql

CREATE TABLE IF NOT EXISTS blocks (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    blocker_id  UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    blocked_id  UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Ensure unique constraint to avoid duplicate block records
    CONSTRAINT uq_block UNIQUE (blocker_id, blocked_id),
    
    -- Prevent self blocking
    CONSTRAINT chk_not_self CHECK (blocker_id != blocked_id)
);

CREATE INDEX idx_blocks_blocker ON blocks(blocker_id);
CREATE INDEX idx_blocks_blocked ON blocks(blocked_id);
