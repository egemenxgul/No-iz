ALTER TABLE users DROP COLUMN IF EXISTS last_pin_prompt_at;

DROP INDEX IF EXISTS idx_webauthn_credential_id;
DROP INDEX IF EXISTS idx_webauthn_user_id;

DROP TABLE IF EXISTS webauthn_credentials;
