---
name: database-migration-strategies
description: Execute safe database migrations for PostgreSQL and MySQL using zero-downtime patterns, backward-compatible schema changes, Flyway/Alembic/Prisma migrate, and the expand-contract pattern. Covers rollback strategies, large table migrations, and CI/CD integration.
version: 1.0.0
tags: [database, migrations, postgresql, mysql, alembic, flyway, prisma, zero-downtime, schema, devops]
---

# Database Migration Strategies

## Overview

Database migrations are the highest-risk part of most deployments — a failed migration can take down production for hours while a rollback strategy is scrambled. Safe migrations rely on three principles: backward compatibility (old and new code both work with the migrated schema), small incremental changes (one column or index per migration), and the expand-contract pattern (never rename or drop in the same deployment that adds). Modern migration tools provide versioning, checksums, and replay safety; the patterns here apply across Alembic, Flyway, Prisma Migrate, and django-migrations.

## When to Use

- Adding, renaming, or removing columns from tables receiving live traffic
- Migrating a table with millions of rows without locking or causing downtime
- Coordinating schema changes with blue-green or rolling deployments
- Setting up migration pipelines in CI/CD that run against staging before production
- Recovering from a failed migration and rolling back safely
- Any multi-service system where different services share a database

## Step-by-Step Workflow

### 1. Alembic (Python / SQLAlchemy)

```python
# alembic/env.py — configure Alembic for async SQLAlchemy
from logging.config import fileConfig
from sqlalchemy import engine_from_config, pool
from alembic import context
from myapp.models import Base  # Your declarative base

config = context.config
fileConfig(config.config_file_name)
target_metadata = Base.metadata

def run_migrations_offline():
    url = config.get_main_option("sqlalchemy.url")
    context.configure(url=url, target_metadata=target_metadata,
                       literal_binds=True, dialect_opts={"paramstyle": "named"})
    with context.begin_transaction():
        context.run_migrations()

def run_migrations_online():
    connectable = engine_from_config(
        config.get_section(config.config_ini_section),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )
    with connectable.connect() as connection:
        context.configure(connection=connection, target_metadata=target_metadata)
        with context.begin_transaction():
            context.run_migrations()
```

```python
# alembic/versions/001_add_display_name.py — safe additive migration
"""Add display_name column to users table"""
from alembic import op
import sqlalchemy as sa

revision = "001_add_display_name"
down_revision = None

def upgrade():
    # SAFE: adding nullable column never locks the table on Postgres 11+
    op.add_column(
        "users",
        sa.Column("display_name", sa.String(255), nullable=True)
    )
    # Backfill existing rows (batched to avoid long lock)
    op.execute("""
        UPDATE users SET display_name = username
        WHERE display_name IS NULL
    """)

def downgrade():
    op.drop_column("users", "display_name")
```

```bash
# Alembic CLI
alembic upgrade head           # Apply all migrations
alembic upgrade +1             # Apply one migration
alembic downgrade -1           # Roll back one migration
alembic current                # Show current revision
alembic history --verbose      # Show all revisions
alembic revision --autogenerate -m "Add display_name"  # Auto-detect from models

# Run against specific database URL
DATABASE_URL="postgresql://..." alembic upgrade head
```

### 2. Flyway (Java / Any Language via CLI)

```sql
-- db/migration/V1__create_users.sql
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- db/migration/V2__add_username.sql
ALTER TABLE users ADD COLUMN username VARCHAR(100);
UPDATE users SET username = split_part(email, '@', 1) WHERE username IS NULL;
ALTER TABLE users ALTER COLUMN username SET NOT NULL;
```

```yaml
# flyway.conf
flyway.url=jdbc:postgresql://localhost:5432/mydb
flyway.user=postgres
flyway.password=${DB_PASSWORD}
flyway.locations=filesystem:db/migration
flyway.validateOnMigrate=true
flyway.outOfOrder=false        # Strict ordering
flyway.baselineOnMigrate=true  # For existing databases
```

```bash
# Flyway CLI
flyway migrate    # Apply pending migrations
flyway info       # Show migration status
flyway validate   # Validate checksums
flyway repair     # Fix failed migration metadata
flyway clean      # Drop all objects (NEVER in production!)
```

### 3. Prisma Migrate (Node.js)

```prisma
// prisma/schema.prisma
model User {
  id          String   @id @default(cuid())
  email       String   @unique
  username    String?  // Nullable during migration window
  displayName String?  @map("display_name")
  createdAt   DateTime @default(now()) @map("created_at")

  @@map("users")
}
```

```bash
# Prisma migrate workflow
npx prisma migrate dev --name add_display_name  # Dev: creates + applies migration
npx prisma migrate deploy                        # Prod: applies pending migrations
npx prisma migrate status                        # Check migration status
npx prisma db push                               # Dev only: push schema without migration file
npx prisma migrate reset                         # Dev only: reset and reapply all migrations

# Generate migration SQL without applying
npx prisma migrate dev --create-only --name add_index
# Edit the generated SQL, then:
npx prisma migrate deploy
```

### 4. Expand-Contract Pattern (Zero-Downtime Column Rename)

```sql
-- WRONG: Rename breaks old code still running during deployment
-- ALTER TABLE users RENAME COLUMN username TO display_name;  -- DON'T

-- CORRECT: 3-phase approach across 3 separate deployments

-- === Phase 1: EXPAND (deploy with old code) ===
-- Migration V10__add_display_name.sql
ALTER TABLE users ADD COLUMN display_name VARCHAR(255);

-- === Phase 1 Code: Write to BOTH columns ===
-- def update_username(user_id, name):
--     db.execute("UPDATE users SET username=$1, display_name=$1 WHERE id=$2", name, user_id)

-- === Phase 2: MIGRATE DATA ===
-- Migration V11__backfill_display_name.sql (runs after Phase 1 is fully deployed)
UPDATE users SET display_name = username WHERE display_name IS NULL;

-- === Phase 2 Code: Read from NEW column, write to BOTH ===
-- def get_display_name(user_id):
--     return db.fetchval("SELECT display_name FROM users WHERE id=$1", user_id)

-- === Phase 3: CONTRACT (after old code is fully gone) ===
-- Migration V12__drop_username.sql
ALTER TABLE users DROP COLUMN username;
```

### 5. Large Table Migrations (No Lock)

```sql
-- Adding index to a large table without locking
-- WRONG: locks the whole table while building index
-- CREATE INDEX idx_users_email ON users (email);

-- CORRECT: concurrent index build
CREATE INDEX CONCURRENTLY idx_users_email ON users (email);

-- Adding NOT NULL constraint to large table
-- WRONG: locks table while checking constraint
-- ALTER TABLE orders ALTER COLUMN status SET NOT NULL;

-- CORRECT: add constraint with NOT VALID, then validate separately
ALTER TABLE orders ADD CONSTRAINT orders_status_not_null
  CHECK (status IS NOT NULL) NOT VALID;

-- Validate in background (no full table lock)
ALTER TABLE orders VALIDATE CONSTRAINT orders_status_not_null;

-- Batched backfill for large tables
-- Don't UPDATE millions of rows in one transaction
DO $$
DECLARE
  batch_size INT := 10000;
  offset_val INT := 0;
  rows_affected INT;
BEGIN
  LOOP
    UPDATE orders
    SET status = 'pending'
    WHERE status IS NULL
    AND id IN (
      SELECT id FROM orders WHERE status IS NULL
      ORDER BY id LIMIT batch_size
    );
    GET DIAGNOSTICS rows_affected = ROW_COUNT;
    EXIT WHEN rows_affected = 0;
    PERFORM pg_sleep(0.1);  -- Brief pause between batches
  END LOOP;
END $$;
```

## Key Commands Reference

```bash
# PostgreSQL — check running locks during migration
SELECT pid, query, state, wait_event_type, wait_event
FROM pg_stat_activity
WHERE state != 'idle'
ORDER BY duration DESC;

# Kill a blocking query if needed
SELECT pg_terminate_backend(<pid>);

# Check table size before/after
SELECT
  pg_size_pretty(pg_total_relation_size('users')) as total_size,
  pg_size_pretty(pg_relation_size('users')) as table_size,
  pg_size_pretty(pg_indexes_size('users')) as index_size;

# Monitor index build progress
SELECT phase, blocks_done, blocks_total,
       (blocks_done::float / blocks_total * 100)::int as pct
FROM pg_stat_progress_create_index;

# Show blocking locks
SELECT
  blocked_locks.pid AS blocked_pid,
  blocking_locks.pid AS blocking_pid,
  blocked_activity.query AS blocked_query
FROM pg_catalog.pg_locks blocked_locks
JOIN pg_catalog.pg_locks blocking_locks ON blocking_locks.locktype = blocked_locks.locktype
  AND blocking_locks.relation = blocked_locks.relation
  AND blocking_locks.granted
  AND NOT blocked_locks.granted
JOIN pg_catalog.pg_stat_activity blocked_activity ON blocked_activity.pid = blocked_locks.pid;

# Alembic generate migration
alembic revision --autogenerate -m "Add status column"
# Review the generated file before applying!
alembic upgrade head

# Prisma check drift
npx prisma migrate diff \
  --from-schema-datasource prisma/schema.prisma \
  --to-url postgresql://prod-db/mydb \
  --script
```

## Common Patterns

### Pattern 1: CI/CD Migration Pipeline

```yaml
# .github/workflows/migrate.yml
name: Database Migration
on:
  push:
    branches: [main]
    paths: ["db/migrations/**", "alembic/versions/**"]

jobs:
  migrate-staging:
    runs-on: ubuntu-latest
    environment: staging
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with: { python-version: "3.12" }
      - run: pip install alembic sqlalchemy psycopg2-binary

      - name: Run migrations on staging
        env:
          DATABASE_URL: ${{ secrets.STAGING_DATABASE_URL }}
        run: alembic upgrade head

      - name: Run migration tests
        run: pytest tests/migration/ -v

  migrate-production:
    needs: migrate-staging
    runs-on: ubuntu-latest
    environment: production
    steps:
      - uses: actions/checkout@v4
      - name: Backup before migrate
        run: |
          pg_dump ${{ secrets.PROD_DATABASE_URL }} \
            --schema-only \
            -f schema_backup_$(date +%Y%m%d_%H%M%S).sql

      - name: Run migrations
        env:
          DATABASE_URL: ${{ secrets.PROD_DATABASE_URL }}
        run: alembic upgrade head
```

### Pattern 2: Migration with Data Transformation

```python
# alembic/versions/005_encrypt_emails.py
"""Encrypt email addresses in users table"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.sql import text

def upgrade():
    # Add encrypted column
    op.add_column("users",
        sa.Column("email_encrypted", sa.LargeBinary, nullable=True))

    # Migrate data (in batches)
    conn = op.get_bind()
    offset = 0
    batch_size = 1000

    while True:
        result = conn.execute(text(
            "SELECT id, email FROM users ORDER BY id LIMIT :limit OFFSET :offset"
        ), {"limit": batch_size, "offset": offset})
        rows = result.fetchall()
        if not rows:
            break

        for row in rows:
            encrypted = encrypt_email(row.email)  # Your encryption function
            conn.execute(text(
                "UPDATE users SET email_encrypted = :enc WHERE id = :id"
            ), {"enc": encrypted, "id": row.id})

        offset += batch_size
        conn.commit()

    # Make encrypted column not null after backfill
    op.alter_column("users", "email_encrypted", nullable=False)

def downgrade():
    op.drop_column("users", "email_encrypted")
```

### Pattern 3: Zero-Downtime Column Default

```sql
-- Adding NOT NULL column with default — the safe way for large tables
-- WRONG on large tables (rewrites entire table):
-- ALTER TABLE events ADD COLUMN processed BOOLEAN NOT NULL DEFAULT FALSE;

-- CORRECT: volatile default (Postgres 11+) — no table rewrite
ALTER TABLE events
  ADD COLUMN processed BOOLEAN DEFAULT FALSE;  -- Nullable first

-- This is fast — stored as a catalog default, no rows written
-- But this works even better on Postgres 11+:
ALTER TABLE events
  ADD COLUMN processed2 BOOLEAN NOT NULL DEFAULT FALSE;
-- Postgres 11+ handles this without rewriting the table
-- Check your Postgres version before choosing which approach!
```

## Pitfalls to Avoid

1. **Running a migration that holds a lock for minutes on a production table**: `ALTER TABLE ... SET NOT NULL` on a table with 50M rows will lock it for minutes. Always check if your migration will acquire an ACCESS EXCLUSIVE lock and use alternatives (`CREATE INDEX CONCURRENTLY`, `NOT VALID` constraints, `REINDEX CONCURRENTLY`) for large tables. Set `statement_timeout` in your migration sessions to fail fast if a lock cannot be acquired.

2. **Not testing the `downgrade()` path**: Teams write `upgrade()` carefully and write `downgrade()` as `pass`. When a migration needs to be rolled back under pressure, the downgrade is broken. Write and test `downgrade()` in every migration — it should restore the exact schema state the migration started from. Run `alembic downgrade -1` in your test suite to verify.

3. **Deploying code that requires a migration before the migration runs**: In rolling deployments or blue-green setups, old pods run simultaneously with new ones. If the new code requires a column that doesn't exist yet, old pods crash. Always deploy the migration first, then deploy the code — or make new code tolerant of the column's absence with graceful fallback.

## Related Skills

- `blue-green-deployments` — Deployment strategy that works with expand-contract pattern
- `postgres-advanced` — PostgreSQL internals and performance
- `sql-expert` — SQL query patterns and optimization
- `database-cdc-patterns` — Change data capture for tracking migration progress
- `data-versioning-dvc` — Versioning data alongside schema changes

## GitNexus Index

```json
{
  "skill": "database-migration-strategies",
  "category": "backend",
  "triggers": ["database migration", "zero-downtime migration", "alembic", "flyway", "prisma migrate", "expand-contract", "schema migration", "large table migration", "concurrent index", "migration rollback", "backward-compatible schema"],
  "outputs": ["alembic upgrade head", "CREATE INDEX CONCURRENTLY", "expand-contract phases", "batched backfill", "NOT VALID constraint", "migration CI/CD pipeline"],
  "complexity": "high",
  "tools": ["alembic", "flyway", "prisma", "postgresql", "mysql", "python", "sqlalchemy", "github-actions"]
}
```
