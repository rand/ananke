-- Database Schema Version 1.0
-- Created: 2024-01-15
-- Description: Initial user management schema

-- Users table stores basic user information
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Add comment for documentation
COMMENT ON TABLE users IS 'Core user accounts';
COMMENT ON COLUMN users.id IS 'Auto-incrementing user identifier';
COMMENT ON COLUMN users.email IS 'Unique email address for authentication';
COMMENT ON COLUMN users.created_at IS 'Account creation timestamp';
