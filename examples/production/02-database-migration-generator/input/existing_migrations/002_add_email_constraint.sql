-- Migration: Add Email Constraint
-- Created: 2024-03-20 14:15:00
-- Description: Add check constraint to validate email format
-- Author: DB Team
-- Version: 1.1

BEGIN;

-- ============================================
-- UP MIGRATION
-- ============================================

-- Add email format validation constraint
ALTER TABLE users
  ADD CONSTRAINT chk_users_email_format
  CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}$');

-- Update comment to reflect validation
COMMENT ON COLUMN users.email IS 'Unique email address for authentication (validated format)';

COMMIT;

-- ============================================
-- DOWN MIGRATION (ROLLBACK)
-- ============================================

BEGIN;

-- Remove email format constraint
ALTER TABLE users
  DROP CONSTRAINT IF EXISTS chk_users_email_format;

-- Restore original comment
COMMENT ON COLUMN users.email IS 'Unique email address for authentication';

COMMIT;
