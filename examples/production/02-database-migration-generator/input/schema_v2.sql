-- Database Schema Version 2.0
-- Created: 2024-11-27
-- Description: Enhanced user schema with name tracking and audit fields

-- Users table stores user information with audit trail
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Index for efficient email lookups
CREATE INDEX idx_users_email ON users(email);

-- Add comments for documentation
COMMENT ON TABLE users IS 'Core user accounts with audit trail';
COMMENT ON COLUMN users.id IS 'Auto-incrementing user identifier';
COMMENT ON COLUMN users.email IS 'Unique email address for authentication';
COMMENT ON COLUMN users.name IS 'User display name';
COMMENT ON COLUMN users.created_at IS 'Account creation timestamp';
COMMENT ON COLUMN users.updated_at IS 'Last modification timestamp';
