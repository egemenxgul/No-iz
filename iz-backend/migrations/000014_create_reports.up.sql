-- Migration: 000014_create_reports.up.sql

CREATE TABLE IF NOT EXISTS reports (
    id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter_id           UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    reported_user_id      UUID REFERENCES users(id) ON DELETE CASCADE,
    reported_community_id UUID REFERENCES communities(id) ON DELETE CASCADE,
    reason                VARCHAR(50) NOT NULL,
    description           TEXT,
    created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    status                VARCHAR(20) NOT NULL DEFAULT 'pending',
    CONSTRAINT check_report_target CHECK (
        (reported_user_id IS NOT NULL AND reported_community_id IS NULL) OR
        (reported_user_id IS NULL AND reported_community_id IS NOT NULL)
    )
);
