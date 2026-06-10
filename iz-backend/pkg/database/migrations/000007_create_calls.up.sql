-- Migration: 000007_create_calls.up.sql

CREATE TYPE call_type   AS ENUM ('audio', 'video');
CREATE TYPE call_status AS ENUM ('ringing', 'active', 'ended', 'missed', 'rejected', 'busy');

CREATE TABLE IF NOT EXISTS calls (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    call_type       call_type   NOT NULL DEFAULT 'audio',
    status          call_status NOT NULL DEFAULT 'ringing',

    -- 1-1 call
    caller_id       UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    callee_id       UUID                 REFERENCES users(id) ON DELETE SET NULL,

    -- Group call (optional)
    group_id        UUID                 REFERENCES groups(id) ON DELETE SET NULL,

    -- Timing
    ringing_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    accepted_at     TIMESTAMPTZ,
    ended_at        TIMESTAMPTZ,
    duration_secs   INTEGER              GENERATED ALWAYS AS (
        CASE WHEN accepted_at IS NOT NULL AND ended_at IS NOT NULL
             THEN EXTRACT(EPOCH FROM (ended_at - accepted_at))::INTEGER
             ELSE NULL
        END
    ) STORED,

    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_calls_caller ON calls(caller_id, created_at DESC);
CREATE INDEX idx_calls_callee ON calls(callee_id, created_at DESC);
CREATE INDEX idx_calls_group  ON calls(group_id,  created_at DESC);
CREATE INDEX idx_calls_status ON calls(status) WHERE status IN ('ringing', 'active');

-- Per-participant state for group calls (mesh signaling)
CREATE TABLE IF NOT EXISTS call_participants (
    call_id     UUID NOT NULL REFERENCES calls(id) ON DELETE CASCADE,
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    joined_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    left_at     TIMESTAMPTZ,
    PRIMARY KEY (call_id, user_id)
);
