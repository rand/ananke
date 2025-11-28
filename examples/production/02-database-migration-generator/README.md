# Database Migration Generator

Generate type-safe PostgreSQL migration scripts from schema changes using Ananke.

## Overview

This example demonstrates how Ananke can automate database migration generation by:
- Comparing schema versions to identify changes
- Extracting patterns from existing migrations
- Generating both UP and DOWN migrations
- Ensuring type safety and rollback support
- Validating SQL syntax and semantics

**Value Proposition**: Eliminates manual migration writing, prevents migration errors, ensures schema consistency across environments.

## Use Case

When evolving a database schema, developers need to:
1. Identify what changed between schema versions
2. Write safe UP migrations (add columns, indexes, etc.)
3. Write corresponding DOWN migrations for rollback
4. Ensure changes don't break existing data
5. Follow team migration patterns and conventions

This example automates all of these steps.

## What This Example Generates

**Input**: Two schema versions (`schema_v1.sql` and `schema_v2.sql`)

**Output**: Complete migration file with:
- Timestamped migration header
- UP migration (apply changes)
- DOWN migration (rollback changes)
- Index creation/removal
- Proper constraint handling
- Transaction safety

## Directory Structure

```
02-database-migration-generator/
├── README.md                          # This file
├── run.sh                             # 4-phase execution script
├── input/
│   ├── schema_v1.sql                  # Initial schema (users table)
│   ├── schema_v2.sql                  # Updated schema (new columns + index)
│   └── existing_migrations/
│       ├── 001_initial_schema.sql     # Example migration showing patterns
│       └── 002_add_users_index.sql    # Another example migration
├── constraints/
│   └── schema_changes.json            # Generated: schema diff constraints
├── output/
│   └── migration_003_add_user_fields.sql  # Generated migration
├── tests/
│   ├── test_migration.sh              # SQL validation tests
│   └── helpers.sh                     # Test utilities
├── scripts/
│   └── schema_diff.py                 # Schema comparison tool
├── package.json                       # TypeScript dependencies
└── requirements.txt                   # Python dependencies
```

## Quick Start

### Prerequisites

- Node.js 18+ and npm
- Python 3.9+
- PostgreSQL client tools (for validation)
- Ananke CLI

### Installation

```bash
# Install dependencies
npm install
pip install -r requirements.txt

# Run the complete pipeline
./run.sh
```

The script will:
1. Extract patterns from existing migrations
2. Compare schema versions to find differences
3. Generate constraint file from schema diff
4. Use Ananke to generate the migration
5. Validate the generated SQL

## How It Works

### Phase 1: Extract Migration Patterns

Ananke analyzes existing migrations to learn:
- Transaction usage (`BEGIN` / `COMMIT`)
- Comment style (migration headers, timestamps)
- Column definition patterns
- Index creation syntax
- UP/DOWN structure

**Input**: `input/existing_migrations/*.sql`

**Extraction**:
```bash
ananke extract \
  input/existing_migrations/*.sql \
  --output constraints/migration_patterns.json \
  --focus "transaction structure, UP/DOWN sections, timestamp format"
```

### Phase 2: Identify Schema Changes

The `schema_diff.py` script:
- Parses both schema versions
- Identifies added/removed columns
- Detects new indexes
- Finds constraint changes
- Generates structured diff

**Example Schema Changes**:
```sql
-- Added to schema_v2.sql:
ALTER TABLE users ADD COLUMN name VARCHAR(255) NOT NULL;
ALTER TABLE users ADD COLUMN updated_at TIMESTAMP DEFAULT NOW();
CREATE INDEX idx_users_email ON users(email);
```

### Phase 3: Generate Migration

Ananke combines:
- Migration patterns (from Phase 1)
- Schema changes (from Phase 2)
- Type safety requirements

To produce a complete migration file.

### Phase 4: Validate

Tests verify:
- SQL syntax is valid
- UP migration applies cleanly
- DOWN migration fully reverts changes
- No data loss in rollback
- Transaction safety

## Input Files

### schema_v1.sql (Initial Schema)

```sql
-- Initial user table schema
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);
```

### schema_v2.sql (Updated Schema)

```sql
-- Updated user table schema
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- New index for email lookups
CREATE INDEX idx_users_email ON users(email);
```

**Changes**:
- Added `name` column (VARCHAR, NOT NULL)
- Added `updated_at` column (TIMESTAMP, default NOW())
- Created index on `email` column

### Existing Migrations

Example migrations that establish patterns:

**001_initial_schema.sql**:
```sql
-- Migration: Initial Schema
-- Created: 2024-01-15 10:30:00
-- Description: Create users table

BEGIN;

-- UP
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

COMMIT;

-- DOWN
BEGIN;

DROP TABLE users;

COMMIT;
```

## Generated Output

### migration_003_add_user_fields.sql

```sql
-- Migration: Add User Fields
-- Created: 2024-11-27 21:40:00
-- Description: Add name and updated_at columns, create email index

BEGIN;

-- UP: Add new columns
ALTER TABLE users
  ADD COLUMN name VARCHAR(255) NOT NULL DEFAULT '',
  ADD COLUMN updated_at TIMESTAMP DEFAULT NOW();

-- UP: Create index
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);

COMMIT;

-- DOWN: Rollback changes
BEGIN;

-- DOWN: Remove index
DROP INDEX IF EXISTS idx_users_email;

-- DOWN: Remove columns
ALTER TABLE users
  DROP COLUMN IF EXISTS updated_at,
  DROP COLUMN IF EXISTS name;

COMMIT;
```

## Schema Evolution Best Practices

### 1. Safe Column Additions

When adding NOT NULL columns to existing tables:

```sql
-- SAFE: Provide default value
ALTER TABLE users ADD COLUMN name VARCHAR(255) NOT NULL DEFAULT '';

-- UNSAFE: No default on existing table
-- ALTER TABLE users ADD COLUMN name VARCHAR(255) NOT NULL;
```

### 2. Index Creation

Always use `IF NOT EXISTS` to make migrations idempotent:

```sql
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
```

### 3. Transaction Safety

Wrap migrations in transactions for atomicity:

```sql
BEGIN;
-- All changes here
COMMIT;
```

### 4. Rollback Testing

Always verify DOWN migrations work:

```bash
# Apply migration
psql -f migration_003_add_user_fields.sql

# Test rollback
psql -c "BEGIN; $(grep -A 10 '-- DOWN' migration_003_add_user_fields.sql | tail -n +2) COMMIT;"
```

### 5. Data Backfill

For complex changes, use three-step migrations:

```sql
-- Step 1: Add nullable column
ALTER TABLE users ADD COLUMN name VARCHAR(255);

-- Step 2: Backfill data
UPDATE users SET name = 'Unknown' WHERE name IS NULL;

-- Step 3: Add constraint
ALTER TABLE users ALTER COLUMN name SET NOT NULL;
```

## Common Migration Patterns

### Add Column

```sql
ALTER TABLE table_name
  ADD COLUMN column_name TYPE [CONSTRAINT] [DEFAULT value];
```

### Remove Column

```sql
ALTER TABLE table_name
  DROP COLUMN IF EXISTS column_name;
```

### Add Index

```sql
CREATE INDEX IF NOT EXISTS idx_name ON table_name(column_name);
```

### Remove Index

```sql
DROP INDEX IF EXISTS idx_name;
```

### Add Foreign Key

```sql
ALTER TABLE table_name
  ADD CONSTRAINT fk_name
  FOREIGN KEY (column_name)
  REFERENCES other_table(id)
  ON DELETE CASCADE;
```

### Change Column Type

```sql
ALTER TABLE table_name
  ALTER COLUMN column_name
  TYPE new_type
  USING column_name::new_type;
```

## Validation and Testing

### SQL Syntax Validation

```bash
# PostgreSQL syntax check
psql -d test_db --single-transaction --dry-run -f output/migration_003_add_user_fields.sql
```

### Integration Tests

The test suite validates:
1. **Syntax**: SQL parses without errors
2. **UP Migration**: Applies successfully to v1 schema
3. **DOWN Migration**: Reverts to exact v1 schema
4. **Idempotency**: Can run UP migration multiple times safely
5. **Data Safety**: Existing data preserved during migration

Run tests:

```bash
cd tests
./test_migration.sh
```

## Extending This Example

### Support for More Schema Changes

Add support for:
- Table creation/deletion
- Constraint modifications
- Enum type changes
- Partition management

Update `scripts/schema_diff.py` to detect these patterns.

### Multi-Database Support

Adapt for MySQL, SQLite, or other databases:
- Update schema parser for dialect differences
- Adjust syntax generation (e.g., `AUTO_INCREMENT` vs `SERIAL`)
- Modify constraint patterns

### Migration Versioning

Enhance version tracking:
- Semantic versioning (major.minor.patch)
- Dependency tracking between migrations
- Conflict detection

### Production Safety

Add production safeguards:
- Required migration review checklist
- Rollback time estimation
- Lock timeout configuration
- Progress monitoring for long-running migrations

## Troubleshooting

### Schema Diff Not Detecting Changes

**Problem**: `schema_diff.py` outputs empty changeset

**Solution**:
- Verify both schema files are valid SQL
- Check for whitespace/formatting differences
- Ensure table names match exactly

### Generated Migration Has Syntax Errors

**Problem**: Migration fails PostgreSQL syntax check

**Solution**:
- Review existing migrations for correct patterns
- Verify column types are PostgreSQL-compatible
- Check constraint syntax

### DOWN Migration Doesn't Fully Revert

**Problem**: Rolling back leaves schema in inconsistent state

**Solution**:
- Ensure all UP changes have corresponding DOWN changes
- Test rollback on a copy of production database
- Add explicit DROP IF EXISTS statements

## Resources

- [PostgreSQL ALTER TABLE Documentation](https://www.postgresql.org/docs/current/sql-altertable.html)
- [PostgreSQL Index Documentation](https://www.postgresql.org/docs/current/sql-createindex.html)
- [Database Migration Best Practices](https://www.postgresql.org/docs/current/ddl-alter.html)
- [Ananke Documentation](../../README.md)

## License

MIT License - See repository root for details.
