-- Migration: Add User Fields
-- Created: 2024-11-27 21:45:00
-- Description: Add name and updated_at columns, create email index
-- Author: Ananke Migration Generator
-- Version: 2.0

-- ============================================
-- UP MIGRATION
-- ============================================

BEGIN;

-- Add new columns to users table
ALTER TABLE users
  ADD COLUMN name VARCHAR(255) NOT NULL DEFAULT '',
  ADD COLUMN updated_at TIMESTAMP DEFAULT NOW();

-- Create index for efficient email lookups
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);

-- Update table comment to reflect new schema version
COMMENT ON TABLE users IS 'Core user accounts with audit trail';
COMMENT ON COLUMN users.name IS 'User display name';
COMMENT ON COLUMN users.updated_at IS 'Last modification timestamp';

COMMIT;

-- ============================================
-- DOWN MIGRATION (ROLLBACK)
-- ============================================

BEGIN;

-- Remove email index
DROP INDEX IF EXISTS idx_users_email;

-- Remove added columns
ALTER TABLE users
  DROP COLUMN IF EXISTS updated_at,
  DROP COLUMN IF EXISTS name;

-- Restore original table comment
COMMENT ON TABLE users IS 'Core user accounts';

COMMIT;
