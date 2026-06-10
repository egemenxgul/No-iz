-- Migration: 000016_add_message_edits_and_reactions.up.sql

-- 1. Add edited_at to messages
ALTER TABLE messages ADD COLUMN edited_at TIMESTAMPTZ;

-- 2. Add edited_at to group_messages
ALTER TABLE group_messages ADD COLUMN edited_at TIMESTAMPTZ;

-- 3. Create message_reactions table
CREATE TABLE IF NOT EXISTS message_reactions (
    message_id UUID NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
    user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    reaction   VARCHAR(32) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (message_id, user_id)
);

CREATE INDEX idx_msg_reactions_msg ON message_reactions(message_id);

-- 4. Create group_message_reactions table
CREATE TABLE IF NOT EXISTS group_message_reactions (
    message_id UUID NOT NULL REFERENCES group_messages(id) ON DELETE CASCADE,
    user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    reaction   VARCHAR(32) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (message_id, user_id)
);

CREATE INDEX idx_group_msg_reactions_msg ON group_message_reactions(message_id);
