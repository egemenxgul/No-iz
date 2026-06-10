-- iz PostgreSQL Init Script
-- Runs on first container start

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";  -- fuzzy text search

-- Set timezone
SET timezone = 'UTC';
