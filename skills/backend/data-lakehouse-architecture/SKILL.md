---
name: data-lakehouse-architecture
description: Build data lakehouses combining data lake storage with data warehouse ACID transactions using Delta Lake, Apache Iceberg, and Apache Hudi. Covers table formats, time travel queries, schema evolution, partition pruning, and integration with Spark, Trino, and dbt.
version: 1.0.0
tags: [data-lakehouse, delta-lake, iceberg, hudi, spark, trino, dbt, parquet, time-travel, acid, data-engineering]
---

# Data Lakehouse Architecture

## Overview

A data lakehouse combines the low-cost storage of a data lake (S3, GCS, ADLS) with the ACID transactions, schema enforcement, and query performance of a data warehouse. Open table formats — Delta Lake, Apache Iceberg, and Apache Hudi — add transaction logs, metadata management, and file statistics on top of Parquet files, enabling operations that were impossible on raw data lakes: ACID writes, time travel, incremental reads, and efficient upserts. Modern lakehouses use this open storage layer with multiple query engines (Spark for ETL, Trino/Athena for ad-hoc SQL, dbt for transformations).

## When to Use

- Needing ACID guarantees on data lake storage (concurrent writers, safe deletes)
- Time travel requirements — auditing historical data or debugging data quality issues
- Streaming + batch convergence on the same table (Lambda architecture elimination)
- Regulatory compliance requiring row-level deletes (GDPR right to erasure)
- Schema evolution without breaking downstream consumers
- Replacing a data warehouse with open format + compute separation for cost savings
- Building a data mesh with federated governance across multiple teams

## Step-by-Step Workflow

### 1. Delta Lake with PySpark

```bash
# Start PySpark with Delta Lake
pyspark --packages io.delta:delta-core_2.12:2.4.0 \
  --conf "spark.sql.extensions=io.delta.sql.DeltaSparkSessionExtension" \
  --conf "spark.sql.catalog.spark_catalog=org.apache.spark.sql.delta.catalog.DeltaCatalog"

# Or: pip install delta-spark
```

```python
# src/lakehouse/delta_operations.py
from delta import DeltaTable
from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.types import StructType, StructField, StringType, LongType, TimestampType

spark = SparkSession.builder \
    .appName("Lakehouse") \
    .config("spark.sql.extensions", "io.delta.sql.DeltaSparkSessionExtension") \
    .config("spark.sql.catalog.spark_catalog",
            "org.apache.spark.sql.delta.catalog.DeltaCatalog") \
    .getOrCreate()

TABLE_PATH = "s3://my-lakehouse/tables/orders"

# --- Create a Delta table ---
schema = StructType([
    StructField("order_id", StringType(), False),
    StructField("customer_id", StringType(), False),
    StructField("amount", LongType(), True),
    StructField("status", StringType(), True),
    StructField("updated_at", TimestampType(), True),
])

initial_df = spark.createDataFrame([], schema)
initial_df.write.format("delta").partitionBy("status").save(TABLE_PATH)

# --- Append new data ---
new_orders = spark.read.json("s3://raw-data/orders/2024-01-15/")
new_orders.write.format("delta").mode("append").save(TABLE_PATH)

# --- Upsert (MERGE) — idempotent CDC ingestion ---
orders_table = DeltaTable.forPath(spark, TABLE_PATH)
cdc_updates = spark.read.json("s3://raw-data/cdc/2024-01-15/")

(orders_table.alias("target")
  .merge(
    cdc_updates.alias("source"),
    "target.order_id = source.order_id"
  )
  .whenMatchedUpdate(set={
    "status": "source.status",
    "amount": "source.amount",
    "updated_at": "source.updated_at",
  })
  .whenNotMatchedInsertAll()
  .execute()
)

# --- Time travel queries ---
# Query as of a specific version
orders_v5 = spark.read.format("delta") \
    .option("versionAsOf", 5) \
    .load(TABLE_PATH)

# Query as of a specific timestamp
orders_yesterday = spark.read.format("delta") \
    .option("timestampAsOf", "2024-01-14T00:00:00.000Z") \
    .load(TABLE_PATH)

# Show history
orders_table.history().show(truncate=False)

# --- Schema evolution ---
# Add a new column without breaking existing reads
spark.sql(f"""
    ALTER TABLE delta.`{TABLE_PATH}` 
    ADD COLUMN shipping_address STRING
""")

# Or enable automatic schema evolution on write
new_orders_with_shipping = cdc_updates.withColumn(
    "shipping_address", F.lit("123 Main St")
)
new_orders_with_shipping.write \
    .format("delta") \
    .option("mergeSchema", "true") \
    .mode("append") \
    .save(TABLE_PATH)
```

### 2. Apache Iceberg with Trino/Spark

```python
# pip install pyiceberg[s3,glue,parquet]
# src/lakehouse/iceberg_catalog.py
from pyiceberg.catalog import load_catalog
from pyiceberg.schema import Schema
from pyiceberg.types import (
    NestedField, StringType, LongType, TimestampType, DoubleType
)
from pyiceberg.partitioning import PartitionSpec, PartitionField
from pyiceberg.transforms import DayTransform
import pyarrow as pa

# Connect to a REST catalog (Polaris, Nessie, AWS Glue)
catalog = load_catalog("glue", **{
    "type": "glue",
    "s3.region": "us-east-1",
})

# Define schema
schema = Schema(
    NestedField(1, "event_id", StringType(), required=True),
    NestedField(2, "user_id", StringType(), required=True),
    NestedField(3, "event_type", StringType(), required=True),
    NestedField(4, "revenue", DoubleType()),
    NestedField(5, "event_time", TimestampType(adjust_to_utc=True), required=True),
)

# Partition by day of event_time — enables partition pruning for time-range queries
partition_spec = PartitionSpec(
    PartitionField(source_id=5, field_id=1000, transform=DayTransform(), name="event_day")
)

# Create table
table = catalog.create_table(
    "analytics.events",
    schema=schema,
    partition_spec=partition_spec,
    location="s3://my-lakehouse/iceberg/analytics/events",
)

# Write data using PyArrow
arrow_schema = pa.schema([
    pa.field("event_id", pa.string()),
    pa.field("user_id", pa.string()),
    pa.field("event_type", pa.string()),
    pa.field("revenue", pa.float64()),
    pa.field("event_time", pa.timestamp("us", tz="UTC")),
])

data = pa.table({
    "event_id": ["evt_001", "evt_002"],
    "user_id": ["user_A", "user_B"],
    "event_type": ["purchase", "view"],
    "revenue": [99.99, 0.0],
    "event_time": pa.array(
        ["2024-01-15T10:00:00", "2024-01-15T11:00:00"],
        type=pa.timestamp("us", tz="UTC")
    ),
}, schema=arrow_schema)

table.append(data)

# Snapshot-based time travel
snapshots = list(table.history())
old_snapshot_id = snapshots[0].snapshot_id  # Earliest snapshot
historical_data = table.scan(snapshot_id=old_snapshot_id).to_arrow()

# Row-level deletes (GDPR compliance)
from pyiceberg.expressions import EqualTo
table.delete(EqualTo("user_id", "user_A"))  # Deletes all rows for user_A
```

```sql
-- Trino SQL for Iceberg queries
-- Set up catalog in trino config:
-- iceberg.catalog.type=glue
-- hive.metastore.uri=thrift://metastore:9083

-- Query with partition pruning (only reads event_day=2024-01-15)
SELECT event_type, SUM(revenue) as total_revenue
FROM iceberg.analytics.events
WHERE event_time >= TIMESTAMP '2024-01-15 00:00:00'
  AND event_time < TIMESTAMP '2024-01-16 00:00:00'
GROUP BY event_type;

-- Time travel in Trino
SELECT * FROM iceberg.analytics.events
FOR VERSION AS OF 3819550825786646543;  -- snapshot ID

SELECT * FROM iceberg.analytics.events
FOR TIMESTAMP AS OF TIMESTAMP '2024-01-14 00:00:00 UTC';

-- Schema evolution — add column
ALTER TABLE iceberg.analytics.events ADD COLUMN platform VARCHAR;

-- Optimize table (rewrite small files into larger ones)
ALTER TABLE iceberg.analytics.events EXECUTE optimize
WHERE event_time >= TIMESTAMP '2024-01-01 00:00:00';
```

### 3. dbt with Delta Lake / Iceberg

```yaml
# dbt_project.yml
name: analytics
models:
  analytics:
    staging:
      +materialized: incremental
      +file_format: delta
      +location_root: "s3://my-lakehouse/dbt/staging"
    marts:
      +materialized: table
      +file_format: delta
      +table_type: delta
```

```sql
-- models/staging/stg_orders.sql
{{ config(
    materialized="incremental",
    file_format="delta",
    incremental_strategy="merge",
    unique_key="order_id",
    merge_update_columns=["status", "amount", "updated_at"],
    on_schema_change="sync_all_columns"
) }}

WITH source AS (
    SELECT
        order_id,
        customer_id,
        CAST(amount AS DECIMAL(18,2)) AS amount,
        status,
        CAST(updated_at AS TIMESTAMP) AS updated_at
    FROM {{ source("raw", "orders") }}
    WHERE updated_at >= '{{ var("start_date") }}'
),

deduped AS (
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY order_id ORDER BY updated_at DESC
           ) AS rn
    FROM source
)

SELECT order_id, customer_id, amount, status, updated_at
FROM deduped
WHERE rn = 1

{% if is_incremental() %}
  AND updated_at > (SELECT MAX(updated_at) FROM {{ this }})
{% endif %}
```

```sql
-- models/marts/revenue_by_day.sql
{{ config(
    materialized="incremental",
    file_format="delta",
    incremental_strategy="insert_overwrite",
    partition_by=["revenue_date"],
    on_schema_change="sync_all_columns"
) }}

SELECT
    DATE(o.updated_at) AS revenue_date,
    COUNT(DISTINCT o.order_id) AS order_count,
    SUM(o.amount) AS total_revenue,
    AVG(o.amount) AS avg_order_value
FROM {{ ref("stg_orders") }} o
WHERE o.status = 'completed'

{% if is_incremental() %}
  AND DATE(o.updated_at) >= DATE_SUB(CURRENT_DATE(), 3)  -- Reprocess last 3 days
{% endif %}

GROUP BY DATE(o.updated_at)
```

### 4. Streaming Ingestion with Delta Lake

```python
# Structured Streaming into Delta Lake — batch + stream unified
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, from_json, current_timestamp
from pyspark.sql.types import StructType, StringType, DoubleType

spark = SparkSession.builder \
    .appName("StreamingIngestion") \
    .config("spark.sql.extensions", "io.delta.sql.DeltaSparkSessionExtension") \
    .getOrCreate()

# Read from Kafka
event_schema = StructType() \
    .add("user_id", StringType()) \
    .add("event_type", StringType()) \
    .add("revenue", DoubleType())

stream = spark.readStream \
    .format("kafka") \
    .option("kafka.bootstrap.servers", "kafka:9092") \
    .option("subscribe", "user_events") \
    .option("startingOffsets", "latest") \
    .load()

parsed = stream.select(
    from_json(col("value").cast("string"), event_schema).alias("data"),
    col("timestamp").alias("kafka_timestamp")
).select("data.*", "kafka_timestamp") \
 .withColumn("ingested_at", current_timestamp())

# Write to Delta with exactly-once semantics
query = parsed.writeStream \
    .format("delta") \
    .outputMode("append") \
    .option("checkpointLocation", "s3://my-lakehouse/checkpoints/events") \
    .option("mergeSchema", "true") \
    .trigger(processingTime="30 seconds") \
    .start("s3://my-lakehouse/tables/events")

query.awaitTermination()
```

## Key Commands Reference

```bash
# Delta Lake maintenance
# Vacuum (remove old Parquet files beyond retention window)
spark.sql("VACUUM delta.`s3://my-lakehouse/tables/orders` RETAIN 168 HOURS")

# Optimize (compact small files)
spark.sql("OPTIMIZE delta.`s3://my-lakehouse/tables/orders` ZORDER BY (customer_id)")

# Show Delta table history
spark.sql("DESCRIBE HISTORY delta.`s3://my-lakehouse/tables/orders`").show()

# Restore to previous version
spark.sql("""
  RESTORE TABLE delta.`s3://my-lakehouse/tables/orders` 
  TO VERSION AS OF 10
""")

# Iceberg table maintenance
# Expire old snapshots
spark.sql("""
  CALL iceberg.system.expire_snapshots(
    'analytics.events',
    TIMESTAMP '2024-01-01 00:00:00',
    100  -- Keep minimum this many snapshots
  )
""")

# Rewrite data files (remove delete files, compact)
spark.sql("""
  CALL iceberg.system.rewrite_data_files(
    table => 'analytics.events',
    strategy => 'sort',
    sort_order => 'event_time ASC NULLS LAST'
  )
""")

# PyIceberg CLI
pip install pyiceberg[s3,glue]
pyiceberg list                          # List all tables
pyiceberg describe analytics.events     # Show schema and snapshots
pyiceberg files analytics.events        # List data files

# dbt commands
dbt run --select staging.*              # Run staging models
dbt run --full-refresh --select marts.* # Full refresh marts
dbt test                                # Run all data quality tests
dbt source freshness                    # Check source table freshness
```

## Common Patterns

### Pattern 1: Slowly Changing Dimensions (SCD Type 2)

```sql
-- SCD Type 2 in Delta Lake: maintain full history of dimension changes
-- models/dims/dim_customers.sql

{{ config(
    materialized="incremental",
    file_format="delta",
    incremental_strategy="merge",
    unique_key=["customer_id", "effective_from"],
) }}

WITH current_records AS (
    SELECT
        customer_id,
        email,
        tier,
        updated_at AS effective_from,
        LEAD(updated_at) OVER (
            PARTITION BY customer_id ORDER BY updated_at
        ) AS effective_to,
        ROW_NUMBER() OVER (
            PARTITION BY customer_id ORDER BY updated_at DESC
        ) = 1 AS is_current
    FROM {{ source("raw", "customer_updates") }}
)

SELECT
    customer_id,
    email,
    tier,
    effective_from,
    COALESCE(effective_to, TIMESTAMP '9999-12-31') AS effective_to,
    is_current
FROM current_records
```

### Pattern 2: Multi-Table Transaction

```python
# Atomic multi-table update using Delta Lake transactions
from delta.tables import DeltaTable

def transfer_inventory(spark, from_warehouse, to_warehouse, product_id, quantity):
    """Atomically move inventory between warehouses."""
    source_table = DeltaTable.forName(spark, "inventory.warehouse_stock")
    transfers_table = DeltaTable.forName(spark, "inventory.transfers_log")

    # Both operations in one transaction (not natively atomic across tables)
    # For true multi-table transactions: use Delta Sharing or implement via audit log

    # Decrement source
    source_table.update(
        condition=f"warehouse_id = '{from_warehouse}' AND product_id = '{product_id}'",
        set={"quantity": f"quantity - {quantity}"}
    )

    # Log the transfer
    transfer_record = spark.createDataFrame([{
        "from_warehouse": from_warehouse,
        "to_warehouse": to_warehouse,
        "product_id": product_id,
        "quantity": quantity,
        "transferred_at": "NOW()",
    }])
    transfer_record.write.format("delta").mode("append") \
        .saveAsTable("inventory.transfers_log")
```

### Pattern 3: Data Quality with Great Expectations + Lakehouse

```python
# Validate data quality before writing to the lakehouse table
import great_expectations as gx
from great_expectations.core.batch import RuntimeBatchRequest

context = gx.get_context()

# Define expectations on new data before it lands in the lakehouse
def validate_and_write(spark, new_df, table_path):
    """Validate data quality; only write if expectations pass."""
    pdf = new_df.toPandas()

    # Add datasource
    context.add_or_update_datasource(
        name="lakehouse_spark",
        class_name="PandasDatasource",
    )

    validator = context.get_validator(
        batch_request=RuntimeBatchRequest(
            datasource_name="lakehouse_spark",
            data_connector_name="default_runtime_data_connector_name",
            data_asset_name="orders",
            runtime_parameters={"batch_data": pdf},
            batch_identifiers={"run_id": "now"},
        ),
        expectation_suite_name="orders_suite",
    )

    validator.expect_column_values_to_not_be_null("order_id")
    validator.expect_column_values_to_be_between("amount", min_value=0, max_value=1_000_000)
    validator.expect_column_values_to_be_in_set("status",
        ["pending", "paid", "shipped", "delivered", "cancelled"])

    results = validator.validate()

    if results.success:
        new_df.write.format("delta").mode("append").save(table_path)
        print(f"Written {new_df.count()} rows to {table_path}")
    else:
        failed = [r for r in results.results if not r.success]
        raise ValueError(f"Data quality failed: {[str(r) for r in failed]}")
```

## Pitfalls to Avoid

1. **Creating too many small files**: Streaming and frequent small batch jobs write many tiny Parquet files. Each file requires a separate S3 GET request during queries, causing poor read performance. Run `OPTIMIZE` with Z-ordering on frequently filtered columns at least daily, and configure `spark.sql.delta.autoOptimize.optimizeWrite=true` to coalesce small files during writes. Iceberg's `rewrite_data_files` procedure does the same.

2. **Skipping partition design**: Choosing poor partition columns causes either too-many-partitions (millions of tiny files) or full table scans (no pruning). Partition on columns used in WHERE clauses with high cardinality but bounded range — `date` or `status` are common. Never partition on `user_id` (millions of partitions). Use Iceberg's hidden partitioning transforms (`days()`, `months()`, `bucket(N, col)`) to avoid partition explosion while still enabling pruning.

3. **Not vacuuming or expiring snapshots**: Delta Lake and Iceberg accumulate old data files and snapshot metadata indefinitely. Without regular `VACUUM` (Delta) or `expire_snapshots` (Iceberg), storage costs grow unboundedly and table metadata size degrades query planning. Set retention policies (default 7 days for Delta) and schedule maintenance jobs. Note: shorter retention windows reduce time-travel capability — align with your audit requirements.

## Related Skills

- `data-versioning-dvc` — Version datasets alongside model/code in ML pipelines
- `database-cdc-patterns` — Stream CDC events into the lakehouse
- `dbt-analytics` — Transform lakehouse data with dbt
- `airflow-dag-patterns` — Orchestrate lakehouse ingestion and maintenance jobs
- `clickhouse-analytics` — OLAP alternative for smaller datasets

## GitNexus Index

```json
{
  "skill": "data-lakehouse-architecture",
  "category": "data",
  "triggers": ["data lakehouse", "delta lake", "apache iceberg", "apache hudi", "open table format", "time travel query", "ACID data lake", "lakehouse architecture", "MERGE delta lake", "iceberg snapshots", "schema evolution lakehouse", "dbt delta lake"],
  "outputs": ["DeltaTable.merge()", "orders_table.history()", "pyiceberg catalog", "table.delete()", "CALL expire_snapshots", "OPTIMIZE ZORDER BY", "writeStream format delta", "dbt incremental merge"],
  "complexity": "high",
  "tools": ["delta-lake", "apache-iceberg", "apache-hudi", "pyspark", "trino", "dbt", "great-expectations", "pyiceberg", "parquet", "s3"]
}
```
