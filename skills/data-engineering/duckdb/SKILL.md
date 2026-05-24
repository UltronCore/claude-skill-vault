---
name: duckdb
description: Analyze data with DuckDB — an in-process analytical database that runs SQL directly on Parquet, CSV, JSON, and Arrow files with columnar speed. Use this skill whenever the user wants to query local files with SQL, run analytics without a database server, analyze Parquet or CSV data, or use DuckDB in Python/Node.js/Wasm. Trigger for "duckdb", "query parquet files", "in-process analytics", "fast local sql", or "duckdb python".
---

# DuckDB: In-Process Analytical Database

DuckDB is an embeddable SQL OLAP database that runs inside your process. It can query Parquet, CSV, JSON, and Arrow files directly — no server, no loading data first. Think SQLite for analytics.

## Installation

```bash
# Python
pip install duckdb

# Node.js
npm install duckdb
# or newer async API
npm install @duckdb/node-api

# CLI
brew install duckdb   # macOS
```

## Python Usage

### Basic Queries

```python
import duckdb

# In-memory database (default)
con = duckdb.connect()

# Query CSV files directly — no loading needed
result = con.sql("SELECT * FROM 'data/sales.csv' LIMIT 10").df()

# Query Parquet files
result = con.sql("""
    SELECT 
        date_trunc('month', order_date) as month,
        SUM(revenue) as total_revenue,
        COUNT(*) as order_count
    FROM 'data/orders/*.parquet'
    WHERE order_date >= '2024-01-01'
    GROUP BY 1
    ORDER BY 1
""").df()  # returns pandas DataFrame

# Persistent database
con = duckdb.connect('analytics.db')
```

### Query Pandas DataFrames Directly

```python
import duckdb
import pandas as pd

df = pd.read_csv('sales.csv')

# Query the DataFrame with SQL — no copy needed
result = duckdb.sql("""
    SELECT 
        region,
        product_category,
        SUM(revenue) as total,
        AVG(profit_margin) as avg_margin
    FROM df
    WHERE year = 2024
    GROUP BY region, product_category
    HAVING SUM(revenue) > 10000
    ORDER BY total DESC
""").df()
```

### Query Remote Files (S3, HTTP)

```python
import duckdb

con = duckdb.connect()

# Install and load httpfs extension
con.execute("INSTALL httpfs; LOAD httpfs;")

# Configure S3 credentials
con.execute("""
    SET s3_region='us-east-1';
    SET s3_access_key_id='your-key';
    SET s3_secret_access_key='your-secret';
""")

# Query S3 Parquet directly
result = con.sql("""
    SELECT COUNT(*), MIN(event_time), MAX(event_time)
    FROM 's3://my-bucket/events/2024/*/*.parquet'
""").df()

# Hive partitioning
result = con.sql("""
    SELECT * 
    FROM read_parquet('s3://bucket/data/', hive_partitioning=true)
    WHERE year=2024 AND month=3
""").df()
```

### Writing Data

```python
import duckdb
import pandas as pd

con = duckdb.connect('output.db')

# Write query result to Parquet
con.execute("""
    COPY (
        SELECT region, SUM(revenue) as total
        FROM read_csv_auto('sales/*.csv')
        GROUP BY region
    ) TO 'summary.parquet' (FORMAT PARQUET)
""")

# Write to CSV
con.execute("""
    COPY (SELECT * FROM results)
    TO 'output.csv' (HEADER, DELIMITER ',')
""")

# Create a persistent table
con.execute("""
    CREATE TABLE IF NOT EXISTS monthly_sales AS
    SELECT 
        date_trunc('month', sale_date) as month,
        SUM(amount) as total
    FROM read_parquet('data/*.parquet')
    GROUP BY 1
""")
```

### Window Functions and Analytics

```python
result = con.sql("""
    SELECT
        user_id,
        event_time,
        event_type,
        -- Running total
        SUM(revenue) OVER (
            PARTITION BY user_id 
            ORDER BY event_time
        ) as cumulative_revenue,
        -- 7-day rolling average
        AVG(revenue) OVER (
            PARTITION BY user_id
            ORDER BY event_time
            RANGE BETWEEN INTERVAL 7 DAYS PRECEDING AND CURRENT ROW
        ) as rolling_7d_avg,
        -- Rank within group
        RANK() OVER (PARTITION BY region ORDER BY revenue DESC) as revenue_rank
    FROM events
""").df()
```

## Node.js Usage

```javascript
import { DuckDBInstance } from '@duckdb/node-api'

// Create instance
const instance = await DuckDBInstance.create(':memory:')
const connection = await instance.connect()

// Query a CSV
const result = await connection.run(
  "SELECT * FROM read_csv_auto('data.csv') LIMIT 100"
)
const rows = await result.fetchAllRows()
console.log(rows)

// Prepared statements
const stmt = await connection.prepare(
  "SELECT * FROM users WHERE region = ? AND active = ?"
)
const res = await stmt.run('us-east', true)

// Persistent DB
const db = await DuckDBInstance.create('analytics.db')
```

## CLI Usage

```bash
# Interactive REPL
duckdb

# Execute SQL file
duckdb -c "$(cat query.sql)"

# Query files directly
duckdb -c "SELECT * FROM 'data.parquet' LIMIT 10"

# Load persistent database
duckdb analytics.db

# Export to CSV
duckdb -c "COPY (SELECT * FROM 'large.parquet') TO 'output.csv' (HEADER)"
```

## Useful Built-in Functions

```sql
-- Auto-detect CSV schema
DESCRIBE SELECT * FROM read_csv_auto('data.csv');

-- Summary statistics
SUMMARIZE SELECT * FROM 'data.parquet';

-- Sample data
SELECT * FROM 'data.parquet' USING SAMPLE 1%;

-- JSON functions
SELECT json_extract(payload, '$.user.id') as user_id FROM events;

-- List/array functions
SELECT list_aggregate(scores, 'mean') as avg_score FROM student_data;

-- String functions
SELECT regexp_extract(url, 'utm_source=([^&]+)', 1) as utm_source FROM clicks;

-- Date/time
SELECT 
    date_trunc('week', created_at) as week,
    datepart('dow', created_at) as day_of_week
FROM orders;
```

## Performance Tips

- DuckDB reads Parquet column-by-column — only select the columns you need
- Use `WHERE` on partition columns for hive-partitioned datasets to skip files
- For repeated queries on the same data, load into a DuckDB table once
- Use `PRAGMA threads=8` to control parallelism
- Parquet > CSV for repeated analysis — better compression and faster reads
- Use `COPY ... TO '...' (FORMAT PARQUET, COMPRESSION ZSTD)` for best storage efficiency

## Integration with Polars and Arrow

```python
import duckdb
import polars as pl
import pyarrow as pa

# Query into Polars DataFrame
result = duckdb.sql("SELECT * FROM 'data.parquet'").pl()

# Query into Arrow table
result = duckdb.sql("SELECT * FROM 'data.parquet'").arrow()

# Register Polars/Arrow for SQL access
pl_df = pl.read_parquet('data.parquet')
duckdb.register('my_table', pl_df.to_arrow())
result = duckdb.sql("SELECT * FROM my_table WHERE value > 100").pl()
```

## GitNexus Index

This skill is indexed by GitNexus for knowledge graph traversal.
Index path: /Users/localuser/.claude/skills/duckdb/.gitnexus
Last indexed: 2026-05-24
