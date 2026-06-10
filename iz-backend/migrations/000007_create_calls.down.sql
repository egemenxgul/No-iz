-- Migration: 000007_create_calls.down.sql

DROP TABLE IF EXISTS call_participants;
DROP TABLE IF EXISTS calls;
DROP TYPE  IF EXISTS call_status;
DROP TYPE  IF EXISTS call_type;
