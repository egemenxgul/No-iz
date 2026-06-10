-- Migration: 000010_create_friendships.up.sql

CREATE TABLE IF NOT EXISTS friendships (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id1      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    user_id2      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    initiator_id  UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status        VARCHAR(20) NOT NULL DEFAULT 'pending',
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Ensure ordered pair uniqueness (user_id1 < user_id2) to avoid duplicates
    CONSTRAINT chk_user_order CHECK (user_id1 < user_id2),
    CONSTRAINT uq_friendship UNIQUE (user_id1, user_id2)
);

CREATE INDEX idx_friendships_user1 ON friendships(user_id1);
CREATE INDEX idx_friendships_user2 ON friendships(user_id2);
