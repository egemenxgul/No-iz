-- Migration: 000006_create_communities.up.sql

-- ─── Communities ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS communities (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name            VARCHAR(128)  NOT NULL,
    slug            VARCHAR(64)   UNIQUE NOT NULL,        -- URL-friendly identifier
    description     TEXT          NOT NULL DEFAULT '',
    avatar_url      TEXT          NOT NULL DEFAULT '',
    banner_url      TEXT          NOT NULL DEFAULT '',
    invite_link     VARCHAR(64)   UNIQUE,
    is_public       BOOLEAN       NOT NULL DEFAULT TRUE,
    max_members     INTEGER       NOT NULL DEFAULT 500000,
    max_groups      INTEGER       NOT NULL DEFAULT 15,
    created_by      UUID          NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_communities_slug       ON communities(slug);
CREATE INDEX idx_communities_created_by ON communities(created_by);
CREATE INDEX idx_communities_public     ON communities(is_public, created_at DESC);

CREATE TRIGGER communities_updated_at
    BEFORE UPDATE ON communities
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ─── Community Members ───────────────────────────────────────────────────────
CREATE TYPE community_role AS ENUM ('owner', 'admin', 'moderator', 'member');

CREATE TABLE IF NOT EXISTS community_members (
    community_id UUID           NOT NULL REFERENCES communities(id) ON DELETE CASCADE,
    user_id      UUID           NOT NULL REFERENCES users(id)       ON DELETE CASCADE,
    role         community_role NOT NULL DEFAULT 'member',
    joined_at    TIMESTAMPTZ    NOT NULL DEFAULT NOW(),
    PRIMARY KEY (community_id, user_id)
);

CREATE INDEX idx_community_members_user  ON community_members(user_id);
CREATE INDEX idx_community_members_comm  ON community_members(community_id);

-- ─── Community ↔ Group links (max 15 per community) ──────────────────────────
CREATE TABLE IF NOT EXISTS community_groups (
    community_id UUID NOT NULL REFERENCES communities(id) ON DELETE CASCADE,
    group_id     UUID NOT NULL REFERENCES groups(id)      ON DELETE CASCADE,
    position     SMALLINT NOT NULL DEFAULT 0,             -- ordering within the community
    linked_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (community_id, group_id)
);

CREATE INDEX idx_community_groups_comm  ON community_groups(community_id, position);
CREATE INDEX idx_community_groups_group ON community_groups(group_id);

-- ─── Community Posts (announcement / feed channel) ───────────────────────────
CREATE TABLE IF NOT EXISTS community_posts (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    community_id UUID    NOT NULL REFERENCES communities(id) ON DELETE CASCADE,
    author_id    UUID    NOT NULL REFERENCES users(id)       ON DELETE CASCADE,

    -- Plaintext title + body (community posts are public by design)
    title        VARCHAR(256)  NOT NULL,
    body         TEXT          NOT NULL DEFAULT '',
    media_urls   TEXT[]        NOT NULL DEFAULT '{}',

    -- Engagement
    like_count   INTEGER NOT NULL DEFAULT 0,
    reply_count  INTEGER NOT NULL DEFAULT 0,

    -- Pinned announcements
    is_pinned    BOOLEAN NOT NULL DEFAULT FALSE,

    expires_at   TIMESTAMPTZ,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_community_posts_comm   ON community_posts(community_id, is_pinned DESC, created_at DESC);
CREATE INDEX idx_community_posts_author ON community_posts(author_id);

CREATE TRIGGER community_posts_updated_at
    BEFORE UPDATE ON community_posts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ─── Post Likes ───────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS community_post_likes (
    post_id  UUID NOT NULL REFERENCES community_posts(id) ON DELETE CASCADE,
    user_id  UUID NOT NULL REFERENCES users(id)           ON DELETE CASCADE,
    liked_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (post_id, user_id)
);
