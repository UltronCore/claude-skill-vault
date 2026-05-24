---
name: postgres-advanced
description: Advanced PostgreSQL patterns including window functions, CTEs, JSONB, partitioning, indexes, connection pooling, and performance tuning for production workloads.
version: 1.0.0
tags: [postgresql, postgres, database, sql, performance, indexes, partitioning, jsonb]
---

# Advanced PostgreSQL

## Overview

This skill covers production PostgreSQL patterns beyond basic CRUD: window functions for analytics, recursive CTEs for hierarchical data, JSONB for flexible schemas, table partitioning for scale, index design for query optimization, connection pooling with PgBouncer, and query performance analysis with EXPLAIN ANALYZE. Targets databases serving 1M+ rows and high-concurrency workloads.

## When to Use

- Queries are slow despite having indexes — need EXPLAIN ANALYZE analysis
- Building analytics queries (rankings, running totals, cohorts)
- Storing flexible/variable schema data (JSONB vs separate tables)
- Table scans on tables >10M rows — need partitioning
- Connection pool exhaustion under load — need PgBouncer
- Implementing full-text search without Elasticsearch

## Step-by-Step Workflow

### 1. Window Functions for Analytics
```sql
-- Running total, rank, moving average
SELECT
    order_date,
    customer_id,
    amount,
    -- Running total per customer
    SUM(amount) OVER (
        PARTITION BY customer_id
        ORDER BY order_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_total,
    -- Rank within each day
    RANK() OVER (PARTITION BY order_date ORDER BY amount DESC) AS daily_rank,
    -- 7-day moving average
    AVG(amount) OVER (
        PARTITION BY customer_id
        ORDER BY order_date
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS moving_avg_7d,
    -- Lag/Lead for period comparison
    amount - LAG(amount, 1) OVER (
        PARTITION BY customer_id ORDER BY order_date
    ) AS delta_from_prev
FROM orders;

-- Cohort analysis
WITH cohorts AS (
    SELECT
        customer_id,
        DATE_TRUNC('month', MIN(order_date)) AS cohort_month
    FROM orders
    GROUP BY customer_id
),
retention AS (
    SELECT
        c.cohort_month,
        DATE_TRUNC('month', o.order_date) AS order_month,
        COUNT(DISTINCT o.customer_id) AS customers
    FROM orders o
    JOIN cohorts c USING (customer_id)
    GROUP BY 1, 2
)
SELECT
    cohort_month,
    order_month,
    customers,
    EXTRACT(MONTH FROM AGE(order_month, cohort_month)) AS months_since_cohort
FROM retention
ORDER BY cohort_month, months_since_cohort;
```

### 2. Recursive CTEs (Hierarchical Data)
```sql
-- Organization hierarchy: find all reports of manager_id=5
WITH RECURSIVE org_hierarchy AS (
    -- Base case: direct reports
    SELECT id, name, manager_id, 1 AS depth
    FROM employees
    WHERE manager_id = 5
    
    UNION ALL
    
    -- Recursive case: reports of reports
    SELECT e.id, e.name, e.manager_id, oh.depth + 1
    FROM employees e
    JOIN org_hierarchy oh ON e.manager_id = oh.id
    WHERE oh.depth < 10  -- Safety limit
)
SELECT id, name, depth
FROM org_hierarchy
ORDER BY depth, name;

-- Path enumeration for tree structures
WITH RECURSIVE category_path AS (
    SELECT id, name, parent_id, 
           name::text AS path,
           1 AS level
    FROM categories WHERE parent_id IS NULL
    
    UNION ALL
    
    SELECT c.id, c.name, c.parent_id,
           cp.path || ' > ' || c.name,
           cp.level + 1
    FROM categories c
    JOIN category_path cp ON c.parent_id = cp.id
)
SELECT * FROM category_path ORDER BY path;
```

### 3. JSONB for Flexible Schema
```sql
-- Create table with JSONB
CREATE TABLE products (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    category TEXT NOT NULL,
    attributes JSONB NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- GIN index for fast JSONB queries
CREATE INDEX idx_products_attributes ON products USING GIN (attributes);
-- Path-specific index (more selective)
CREATE INDEX idx_products_brand ON products ((attributes->>'brand'));

-- Insert with JSONB
INSERT INTO products (name, category, attributes) VALUES
('Sony WH-1000XM5', 'headphones', '{
    "brand": "Sony",
    "color": "black",
    "features": ["ANC", "USB-C", "Bluetooth 5.2"],
    "specs": {"battery_hours": 30, "weight_grams": 250}
}');

-- Query JSONB
SELECT name
FROM products
WHERE attributes->>'brand' = 'Sony'           -- Text field
  AND (attributes->'specs'->>'battery_hours')::int > 20  -- Nested numeric
  AND attributes @> '{"features": ["ANC"]}';  -- Contains element

-- Aggregation over JSONB arrays
SELECT category,
       jsonb_agg(DISTINCT attributes->>'brand') AS brands,
       AVG((attributes->'specs'->>'battery_hours')::numeric) AS avg_battery
FROM products
WHERE attributes ? 'specs'
GROUP BY category;
```

### 4. Table Partitioning
```sql
-- Range partitioning by date (for time-series data)
CREATE TABLE orders (
    id BIGINT GENERATED ALWAYS AS IDENTITY,
    customer_id BIGINT NOT NULL,
    amount DECIMAL(10,2),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
) PARTITION BY RANGE (created_at);

-- Create partitions (automate this with pg_partman)
CREATE TABLE orders_2024_01 PARTITION OF orders
    FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');
CREATE TABLE orders_2024_02 PARTITION OF orders
    FOR VALUES FROM ('2024-02-01') TO ('2024-03-01');

-- Index on each partition (inherited from parent)
CREATE INDEX ON orders (created_at, customer_id);

-- pg_partman for automatic partition management
SELECT partman.create_parent(
    p_parent_table := 'public.orders',
    p_control := 'created_at',
    p_type := 'native',
    p_interval := 'monthly',
    p_premake := 3  -- Pre-create 3 future partitions
);
```

### 5. Index Design
```sql
-- Covering index (index-only scan)
CREATE INDEX idx_orders_customer_covering
    ON orders (customer_id, created_at)
    INCLUDE (amount, status);  -- Included columns avoid heap fetch

-- Partial index (smaller, faster for common queries)
CREATE INDEX idx_orders_pending
    ON orders (created_at)
    WHERE status = 'pending';  -- Only indexes pending orders

-- Expression index (for computed predicates)
CREATE INDEX idx_users_email_lower
    ON users (LOWER(email));  -- Supports: WHERE LOWER(email) = 'user@example.com'

-- BRIN index (for naturally ordered large tables)
CREATE INDEX idx_events_timestamp_brin
    ON events USING BRIN (created_at)
    WITH (pages_per_range = 128);

-- Check index usage
SELECT schemaname, tablename, indexname, idx_scan, idx_tup_read, idx_tup_fetch
FROM pg_stat_user_indexes
ORDER BY idx_scan ASC;  -- Low idx_scan = unused index, consider dropping
```

### 6. EXPLAIN ANALYZE and Query Tuning
```sql
-- Enable timing and buffers for full picture
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT o.*, c.name
FROM orders o
JOIN customers c ON c.id = o.customer_id
WHERE o.created_at > NOW() - INTERVAL '7 days'
  AND o.status = 'pending'
ORDER BY o.created_at DESC
LIMIT 50;

-- Read the plan:
-- Seq Scan = no index used → add index
-- Rows removed by filter = estimate accuracy issue → ANALYZE table
-- Buffers: hit=X, read=Y → high read = needs caching or index
-- Nested Loop vs Hash Join → depends on row estimates

-- Update statistics (run after bulk inserts)
ANALYZE orders;
VACUUM ANALYZE orders;

-- Find slow queries
SELECT query, mean_exec_time, calls, total_exec_time
FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 20;
```

## Key Commands Reference

```bash
# Connection with PgBouncer (pgbouncer.ini)
[databases]
mydb = host=127.0.0.1 port=5432 dbname=mydb

[pgbouncer]
pool_mode = transaction
max_client_conn = 1000
default_pool_size = 25
server_pool_size = 25
reserve_pool_size = 5

# Useful psql commands
\d+ tablename          # Describe table with sizes
\di+ tablename         # Show indexes
\timing on             # Show query execution time
\x auto                # Expanded output for wide tables

# Maintenance
VACUUM ANALYZE tablename;
REINDEX INDEX idx_orders_customer;
CLUSTER orders USING idx_orders_created_at;  # Physically reorder table

# Check bloat
SELECT tablename, n_dead_tup, n_live_tup, 
       round(n_dead_tup * 100.0 / NULLIF(n_live_tup, 0), 2) as dead_pct
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC;
```

## Common Patterns

### Pattern 1: Upsert with Conflict Handling
```sql
INSERT INTO user_preferences (user_id, key, value, updated_at)
VALUES (42, 'theme', 'dark', NOW())
ON CONFLICT (user_id, key)
DO UPDATE SET
    value = EXCLUDED.value,
    updated_at = EXCLUDED.updated_at
WHERE user_preferences.value IS DISTINCT FROM EXCLUDED.value;
-- WHERE clause: only update if value actually changed
```

### Pattern 2: Skip Locked for Job Queues
```sql
-- Concurrent workers claim jobs without blocking each other
SELECT id, payload
FROM job_queue
WHERE status = 'pending'
  AND scheduled_at <= NOW()
ORDER BY priority DESC, scheduled_at ASC
LIMIT 1
FOR UPDATE SKIP LOCKED;  -- Skip rows locked by other workers
```

### Pattern 3: Full-Text Search
```sql
-- Add search column (materialized for performance)
ALTER TABLE articles ADD COLUMN search_vector tsvector
    GENERATED ALWAYS AS (
        setweight(to_tsvector('english', coalesce(title, '')), 'A') ||
        setweight(to_tsvector('english', coalesce(body, '')), 'B')
    ) STORED;

CREATE INDEX idx_articles_search ON articles USING GIN (search_vector);

-- Search query with ranking
SELECT title, ts_rank(search_vector, query) AS rank
FROM articles, to_tsquery('english', 'postgresql & performance') query
WHERE search_vector @@ query
ORDER BY rank DESC
LIMIT 10;
```

## Pitfalls to Avoid

1. **N+1 queries**: Loading a list then fetching related data per row is the #1 performance killer. Use `JOIN`, `IN (SELECT ...)`, or lateral joins. Detect with query logging: `log_min_duration_statement = 100`. In ORMs, use eager loading (`.include()`, `SELECT_RELATED`).

2. **Unindexed foreign keys**: PostgreSQL doesn't automatically index foreign key columns (unlike MySQL). Every FK column that will be used in JOINs needs an explicit index. Missing: `CREATE INDEX ON orders (customer_id)` turns O(log n) joins into O(n) scans.

3. **SELECT * in application code**: Always select only needed columns. `SELECT *` with JSONB columns or large TEXT fields can transfer MBs per query. Name columns explicitly in production queries and use covering indexes for read-heavy paths.

## Related Skills

- `dbt-analytics` — SQL transformation patterns on top of PostgreSQL
- `redis-patterns` — Caching PostgreSQL query results
- `elasticsearch-search` — When full-text search outgrows PostgreSQL
- `data-quality-validation` — Database constraint and validation patterns

## GitNexus Index

```json
{
  "skill": "postgres-advanced",
  "category": "backend",
  "triggers": ["postgresql", "postgres", "window functions", "CTE", "JSONB", "partitioning", "explain analyze", "postgres tuning"],
  "outputs": ["optimized query", "index design", "partition setup", "JSONB schema"],
  "complexity": "high",
  "tools": ["postgresql", "pgbouncer", "pg_partman", "pg_stat_statements", "psql"]
}
```
