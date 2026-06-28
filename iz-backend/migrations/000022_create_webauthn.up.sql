CREATE TABLE IF NOT EXISTS webauthn_credentials (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    credential_id BYTEA NOT NULL UNIQUE,
    public_key BYTEA NOT NULL,
    attestation_type VARCHAR(64) NOT NULL,
    transport TEXT[],
    flags JSONB,
    authenticator_aaguid BYTEA,
    sign_count INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_webauthn_user_id ON webauthn_credentials(user_id);
CREATE INDEX idx_webauthn_credential_id ON webauthn_credentials(credential_id);

ALTER TABLE users ADD COLUMN IF NOT EXISTS last_pin_prompt_at TIMESTAMPTZ;
