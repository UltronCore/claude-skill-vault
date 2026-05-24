---
name: clickhouse-analytics
description: Build high-performance analytics pipelines with ClickHouse. Covers table engines, data ingestion from Kafka/S3, materialized views, query optimization, and running real-time analytics at scale.
version: 1.0.0
tags: [clickhouse, analytics, OLAP, data-warehouse, materialized-views, kafka-integration]
---

# ClickHouse Analytics

## Overview

This skill covers ClickHouse — the OLAP database optimized for analytical queries on billions of rows with sub-second latency. It addresses schema design with column-oriented storage, MergeTree table engines, ingesting data from Kafka and S3, using materialized views for real-time aggregations, and optimizing queries for analytics workloads. ClickHouse can replace heavy Spark jobs for many analytics use cases with simpler SQL.

## When to Use

- Analytics queries that are too slow in PostgreSQL (count/group-by on 100M+ rows)
- Real-time dashboards that need sub-second query times on recent data
- Processing and storing event streams from Kafka at high volume
- Replacing expensive data warehouse services (BigQuery/Snowflake) for high-volume datasets
- Time-series analytics, log analysis, user behavior funnels

## Step-by-Step Workflow

### 1. Table Design with MergeTree
```sql
-- Events table (append-only time-series)
CREATE TABLE events
(
    -- Ordering key: most-filtered-on columns first
    event_date     Date,
    event_time     DateTime,
    user_id        UInt64,
    event_type     LowCardinality(String),  -- LowCardinality for repeated strings
    session_id     String,
    page_url       String,
    properties     String,                   -- JSON blob
    revenue_cents  Nullable(Int32),
    
    -- Derived/denormalized columns for fast filtering
    country        LowCardinality(String),
    device_type    LowCardinality(String),
    
    -- Metadata
    _ingested_at   DateTime DEFAULT now()
)
ENGINE = MergeTree()
PARTITION BY toYYYYMM(event_date)    -- Monthly partitions
ORDER BY (event_date, user_id, event_time)  -- Sorting key = sparse index
PRIMARY KEY (event_date, user_id)    -- Subset of ORDER BY for primary index
SETTINGS index_granularity = 8192;  -- Default

-- TTL: auto-delete old data
ALTER TABLE events MODIFY TTL event_date + INTERVAL 2 YEAR;

-- ReplacingMergeTree for upserts (deduplication by ORDER BY key)
CREATE TABLE users (
    user_id     UInt64,
    email       String,
    plan        LowCardinality(String),
    updated_at  DateTime
)
ENGINE = ReplacingMergeTree(updated_at)  -- Keeps latest by updated_at
ORDER BY user_id;
```

### 2. Kafka Integration
```sql
-- Create Kafka engine table (reads from Kafka topic)
CREATE TABLE events_kafka_queue
(
    event_time  DateTime,
    user_id     UInt64,
    event_type  String,
    properties  String
)
ENGINE = Kafka()
SETTINGS
    kafka_broker_list = 'kafka:9092',
    kafka_topic_list = 'user-events',
    kafka_group_name = 'clickhouse-consumer',
    kafka_format = 'JSONEachRow',
    kafka_num_consumers = 4;

-- Materialized view that moves Kafka data to MergeTree
CREATE MATERIALIZED VIEW events_kafka_mv TO events AS
SELECT
    toDate(event_time) AS event_date,
    event_time,
    user_id,
    event_type,
    properties
FROM events_kafka_queue;
```

### 3. Real-Time Materialized Views (Pre-Aggregation)
```sql
-- AggregatingMergeTree for incremental aggregation
CREATE TABLE hourly_revenue (
    hour        DateTime,
    country     LowCardinality(String),
    plan        LowCardinality(String),
    total_revenue AggregateFunction(sum, Int64),
    order_count   AggregateFunction(count, UInt64),
    unique_users  AggregateFunction(uniq, UInt64)
)
ENGINE = AggregatingMergeTree()
ORDER BY (hour, country, plan);

-- Populate from events (runs on every INSERT into events)
CREATE MATERIALIZED VIEW hourly_revenue_mv TO hourly_revenue AS
SELECT
    toStartOfHour(event_time)  AS hour,
    country,
    plan,
    sumState(revenue_cents)    AS total_revenue,
    countState()               AS order_count,
    uniqState(user_id)         AS unique_users
FROM events
WHERE event_type = 'purchase'
GROUP BY hour, country, plan;

-- Query the aggregated view (merges states on read)
SELECT
    hour,
    country,
    sumMerge(total_revenue) / 100 AS revenue_usd,
    countMerge(order_count) AS orders,
    uniqMerge(unique_users) AS users
FROM hourly_revenue
WHERE hour >= now() - INTERVAL 24 HOUR
GROUP BY hour, country
ORDER BY hour DESC, revenue_usd DESC;
```

### 4. S3 Integration (Data Lake Ingestion)
```sql
-- Query S3 files directly (Parquet, CSV, JSON)
SELECT count(), sum(amount)
FROM s3(
    'https://my-bucket.s3.amazonaws.com/events/2024/01/*.parquet',
    'ACCESS_KEY', 'SECRET_KEY',
    'Parquet'
);

-- Create table backed by S3 (no local storage)
CREATE TABLE events_cold
ENGINE = S3('s3://my-bucket/events/{_partition_id}/*.parquet', 'Parquet')
PARTITION BY toYYYYMM(event_date)
ORDER BY (event_date, user_id);

-- Async insert from S3
INSERT INTO events
SELECT * FROM s3('s3://bucket/batch/events_*.json', 'JSONEachRow')
SETTINGS max_insert_threads = 16;
```

### 5. Analytics Queries
```sql
-- Funnel analysis
WITH funnel_events AS (
    SELECT
        user_id,
        groupArray(event_type) AS events_array
    FROM events
    WHERE event_date >= today() - 30
      AND event_type IN ('page_view', 'add_to_cart', 'checkout_start', 'purchase')
    GROUP BY user_id
)
SELECT
    countIf(has(events_array, 'page_view')) AS step1_views,
    countIf(has(events_array, 'add_to_cart')) AS step2_adds,
    countIf(has(events_array, 'checkout_start')) AS step3_checkout,
    countIf(has(events_array, 'purchase')) AS step4_purchase
FROM funnel_events;

-- Session analysis with window functions
SELECT
    user_id,
    session_id,
    min(event_time) AS session_start,
    max(event_time) AS session_end,
    dateDiff('second', min(event_time), max(event_time)) AS session_duration_s,
    count() AS page_views
FROM events
WHERE event_date >= today() - 7
GROUP BY user_id, session_id
HAVING session_duration_s > 0
ORDER BY session_duration_s DESC
LIMIT 100;

-- Retention cohort
SELECT
    cohort_month,
    activity_month,
    count(DISTINCT user_id) AS users,
    round(count(DISTINCT user_id) / first_value(count(DISTINCT user_id)) OVER (
        PARTITION BY cohort_month ORDER BY activity_month
    ) * 100, 1) AS retention_pct
FROM (
    SELECT
        user_id,
        toStartOfMonth(first_purchase) AS cohort_month,
        toStartOfMonth(event_date) AS activity_month
    FROM events
    JOIN (
        SELECT user_id, min(event_date) AS first_purchase
        FROM events WHERE event_type = 'purchase'
        GROUP BY user_id
    ) USING (user_id)
    WHERE event_type = 'purchase'
)
GROUP BY cohort_month, activity_month
ORDER BY cohort_month, activity_month;
```

### 6. Ingestion with Python
```python
import clickhouse_connect

client = clickhouse_connect.get_client(
    host='clickhouse.example.com',
    port=8443,
    username='default',
    password='password',
    secure=True,
)

# Bulk insert (columnar format — much faster than row-by-row)
data = [
    ('2024-01-15', 'click', 12345, 'US', 'mobile'),
    ('2024-01-15', 'purchase', 67890, 'GB', 'desktop'),
]

client.insert(
    'events',
    data,
    column_names=['event_date', 'event_type', 'user_id', 'country', 'device_type'],
    settings={'async_insert': 1, 'wait_for_async_insert': 0}  # Non-blocking batch insert
)

# Async insert for high throughput (batches automatically)
for batch in batches(rows, size=10000):
    client.insert('events', batch, settings={'async_insert': 1})

# Query to DataFrame
df = client.query_df("SELECT event_date, sum(revenue_cents)/100 as revenue FROM events GROUP BY 1 ORDER BY 1")
```

## Key Commands Reference

```bash
# Start ClickHouse
docker run -d --name clickhouse -p 8123:8123 -p 9000:9000 clickhouse/clickhouse-server

# Connect
clickhouse-client --host localhost --port 9000

# Monitor in clickhouse-client:
SELECT * FROM system.processes;  -- Running queries
SELECT * FROM system.merges;     -- Background merges
SELECT * FROM system.mutations;  -- Running mutations

# Check table sizes
SELECT table, formatReadableSize(sum(bytes_on_disk)) AS size, sum(rows) AS rows
FROM system.parts WHERE active
GROUP BY table ORDER BY sum(bytes_on_disk) DESC;

# Explain query plan
EXPLAIN SELECT count() FROM events WHERE user_id = 12345;
EXPLAIN PIPELINE SELECT ...;  -- Full execution pipeline

# Force merge (avoid in production)
OPTIMIZE TABLE events FINAL;
```

## Common Patterns

### Pattern 1: Dictionary for Dimension Joins
```sql
-- Fast joins without scanning: use dictionary for user metadata
CREATE DICTIONARY user_dict (
    user_id  UInt64,
    country  String,
    plan     String
)
PRIMARY KEY user_id
SOURCE(CLICKHOUSE(TABLE 'users'))
LIFETIME(MIN 300 MAX 600)  -- Refresh every 5-10 minutes
LAYOUT(HASHED());

-- Use in query (no JOIN, direct lookup)
SELECT
    event_type,
    dictGet('user_dict', 'country', user_id) AS country,
    count() AS events
FROM events
WHERE event_date = today()
GROUP BY event_type, country;
```

### Pattern 2: Approximate Aggregations (Massive Scale)
```sql
-- uniq (HyperLogLog): count distinct users in billions of rows
SELECT uniq(user_id) FROM events WHERE event_date >= today() - 90;

-- quantile: percentile latency
SELECT quantile(0.99)(response_time_ms) as p99 FROM api_logs;

-- topK: most common values
SELECT topK(10)(page_url) FROM events WHERE event_date = today();
```

### Pattern 3: Moving/Rolling Windows
```sql
-- 7-day moving average of revenue
SELECT
    event_date,
    avg(daily_revenue) OVER (
        ORDER BY event_date
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS moving_avg_7d
FROM (
    SELECT event_date, sum(revenue_cents)/100 AS daily_revenue
    FROM events GROUP BY event_date
)
ORDER BY event_date;
```

## Pitfalls to Avoid

1. **Wrong ORDER BY key**: The ORDER BY / PRIMARY KEY determines how data is physically sorted on disk — this is the most critical schema decision. Put the most-filtered column first (usually date), then the next most-selective (user_id). Wrong ordering causes full-table scans on common queries.

2. **Too many parts (mutations/inserts)**: Each INSERT creates new "parts" on disk. ClickHouse merges them in the background, but too many small inserts overwhelm the merger. Always insert in batches of at least 10,000 rows. Use async_insert for streaming scenarios. Check `system.parts` — if you see thousands of parts per partition, add batching.

3. **FINAL keyword on large tables**: `SELECT ... FROM table FINAL` deduplicates ReplacingMergeTree at query time — it reads ALL parts and merges them in memory. On a 100B row table this takes minutes. Schedule `OPTIMIZE TABLE FINAL` during off-hours instead and query without FINAL for fresh reads.

## Related Skills

- `dbt-analytics` — Use dbt to manage ClickHouse transformations
- `kafka-event-streaming` — Feeding ClickHouse from Kafka
- `data-quality-validation` — Validating ClickHouse data quality
- `elasticsearch-search` — When full-text search is also needed

## GitNexus Index

```json
{
  "skill": "clickhouse-analytics",
  "category": "data-engineering",
  "triggers": ["clickhouse", "OLAP", "analytics database", "materialized view clickhouse", "clickhouse kafka", "real-time analytics"],
  "outputs": ["CREATE TABLE", "materialized view", "analytics query", "kafka integration"],
  "complexity": "high",
  "tools": ["clickhouse", "clickhouse-client", "clickhouse-connect", "kafka"]
}
```
