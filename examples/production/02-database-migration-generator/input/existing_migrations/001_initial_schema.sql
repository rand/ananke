-- Migration: Initial Schema
-- Created: 2024-01-15 10:30:00
-- Description: Create initial users table with email authentication
-- Author: DB Team
-- Version: 1.0

BEGIN;

-- ============================================
-- UP MIGRATION
-- ============================================

-- Create users table
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Add table and column comments
COMMENT ON TABLE users IS 'Core user accounts';
COMMENT ON COLUMN users.id IS 'Auto-incrementing user identifier';
COMMENT ON COLUMN users.email IS 'Unique email address for authentication';
COMMENT ON COLUMN users.created_at IS 'Account creation timestamp';

COMMIT;

-- ============================================
-- DOWN MIGRATION (ROLLBACK)
-- ============================================

BEGIN;

-- Drop users table (cascades to dependent objects)
DROP TABLE IF EXISTS users CASCADE;

COMMIT;
