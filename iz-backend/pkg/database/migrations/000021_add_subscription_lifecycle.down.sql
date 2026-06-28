ALTER TABLE users 
DROP COLUMN IF EXISTS subscription_period_end,
DROP COLUMN IF EXISTS scheduled_downgrade_tier;
