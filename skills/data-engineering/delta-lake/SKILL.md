---
name: delta-lake
description: Build reliable data lakes with Delta Lake — an open-source storage layer that brings ACID transactions, scalable metadata handling, and time travel to Apache Spark and other engines. Use this skill whenever the user mentions Delta Lake, Delta tables, ACID transactions on a data lake, or wants reliable streaming + batch on the same dataset. Trigger for "delta lake", "delta table", "deltalake python", "delta format", or "databricks delta".
---

# Delta Lake: ACID Transactions for Data Lakes

Delta Lake is an open-source storage format that adds reliability to data lakes. It brings ACID transactions, schema enforcement, time travel, and scalable metadata to Parquet files stored in any object store.

## Python with delta-rs (Standalone, no Spark required)

```bash
pip install deltalake pyarrow pandas
```

### Create and Write Delta Tables

```python
import pyarrow as pa
from deltalake import DeltaTable, write_deltalake
from datetime import datetime

# Write a new Delta table
data = pa.table({
    "order_id": ["ord_001", "ord_002", "ord_003"],
    "customer_id": ["cust_A", "cust_B", "cust_A"],
    "order_date": [datetime(2024, 3, 15), datetime(2024, 3, 15), datetime(2024, 3, 16)],
    "region": ["us-east", "eu-west", "us-east"],
    "revenue": [150.0, 280.0, 95.0],
    "status": ["shipped", "processing", "delivered"],
})

# Write (creates table if not exists)
write_deltalake(
    "data/orders",      # local path or s3://bucket/prefix
    data,
    mode="overwrite",   # "overwrite", "append", or "error"
    partition_by=["region"],
)

print("Table written successfully")
```

### Append Data

```python
from deltalake import write_deltalake
import pyarrow as pa

new_orders = pa.table({
    "order_id": ["ord_004", "ord_005"],
    "customer_id": ["cust_C", "cust_A"],
    "order_date": [datetime(2024, 3, 17), datetime(2024, 3, 17)],
    "region": ["us-west", "us-east"],
    "revenue": [320.0, 89.0],
    "status": ["pending", "shipped"],
})

write_deltalake("data/orders", new_orders, mode="append")
```

### Read Delta Tables

```python
from deltalake import DeltaTable

# Open the table
dt = DeltaTable("data/orders")

# Read as Arrow
arrow_table = dt.to_pyarrow()

# Read as Pandas
df = dt.to_pandas()

# Read with filters (partition pruning)
df = dt.to_pandas(
    partitions=[("region", "=", "us-east")],
    columns=["order_id", "customer_id", "revenue"],
)

# Convert to DuckDB for SQL queries
import duckdb
conn = duckdb.connect()
conn.register("orders", dt.to_pyarrow())
result = conn.execute("""
    SELECT region, SUM(revenue) as total_revenue, COUNT(*) as order_count
    FROM orders
    GROUP BY region
    ORDER BY total_revenue DESC
""").df()
```

### Time Travel

```python
from deltalake import DeltaTable

dt = DeltaTable("data/orders")

# List all versions
print(dt.history())

# Read a specific version
dt_v1 = DeltaTable("data/orders", version=1)
df_v1 = dt_v1.to_pandas()

# Read as of a timestamp
import datetime
dt_yesterday = DeltaTable(
    "data/orders",
    storage_options={"AWS_REGION": "us-east-1"},
).load_as_version("2024-03-15T00:00:00Z")
```

### Merge (Upsert)

```python
from deltalake import DeltaTable, write_deltalake
import pyarrow as pa

dt = DeltaTable("data/orders")

# Upsert: update existing records, insert new ones
updates = pa.table({
    "order_id": ["ord_001", "ord_099"],  # ord_001 exists, ord_099 is new
    "customer_id": ["cust_A", "cust_Z"],
    "order_date": [datetime(2024, 3, 15), datetime(2024, 3, 18)],
    "region": ["us-east", "us-west"],
    "revenue": [175.0, 450.0],  # ord_001 revenue updated
    "status": ["delivered", "pending"],
})

(
    dt.merge(
        updates,
        predicate="source.order_id = target.order_id",
        source_alias="source",
        target_alias="target",
    )
    .when_matched_update_all()
    .when_not_matched_insert_all()
    .execute()
)
```

### Schema Evolution

```python
from deltalake import write_deltalake
import pyarrow as pa

dt = DeltaTable("data/orders")

# Add a new column (schema_mode="merge" allows adding columns)
new_data = pa.table({
    "order_id": ["ord_010"],
    "customer_id": ["cust_D"],
    "order_date": [datetime(2024, 3, 20)],
    "region": ["eu-east"],
    "revenue": [199.0],
    "status": ["shipped"],
    "discount_pct": [0.10],  # new column
})

write_deltalake(
    "data/orders",
    new_data,
    mode="append",
    schema_mode="merge",  # automatically adds new columns to schema
)
```

### Table Maintenance

```python
from deltalake import DeltaTable

dt = DeltaTable("data/orders")

# Vacuum: delete old files beyond retention period (default 7 days)
dt.vacuum(retention_hours=168)  # 7 days

# Optimize: compact small files
dt.optimize.compact()

# Z-order: co-locate data for faster queries on specific columns
dt.optimize.z_order(["customer_id", "order_date"])
```

## Spark + Delta Lake

```python
from pyspark.sql import SparkSession

spark = SparkSession.builder \
    .appName("delta_example") \
    .config("spark.sql.extensions", "io.delta.sql.DeltaSparkSessionExtension") \
    .config("spark.sql.catalog.spark_catalog", "org.apache.spark.sql.delta.catalog.DeltaCatalog") \
    .getOrCreate()

# Create Delta table
spark.sql("""
    CREATE TABLE IF NOT EXISTS events (
        event_id STRING NOT NULL,
        user_id STRING,
        event_type STRING,
        event_time TIMESTAMP,
        value DOUBLE
    )
    USING DELTA
    PARTITIONED BY (date_trunc('day', event_time))
    LOCATION 's3://my-bucket/delta/events'
""")

# Write streaming + batch to same table (Delta handles concurrent writes)
streaming_df = spark.readStream.format("kafka")...
streaming_df.writeStream \
    .format("delta") \
    .outputMode("append") \
    .option("checkpointLocation", "s3://bucket/checkpoints/events") \
    .table("events") \
    .start()

# Merge (upsert)
spark.sql("""
    MERGE INTO events t
    USING updates s ON t.event_id = s.event_id
    WHEN MATCHED AND s.value > t.value THEN UPDATE SET *
    WHEN NOT MATCHED THEN INSERT *
""")

# Time travel
spark.sql("SELECT * FROM events VERSION AS OF 5")
spark.sql("SELECT * FROM events TIMESTAMP AS OF '2024-03-15'")

# View history
spark.sql("DESCRIBE HISTORY events").show(20, False)

# Optimize
spark.sql("OPTIMIZE events ZORDER BY (user_id, event_type)")

# Vacuum
spark.sql("VACUUM events RETAIN 168 HOURS")
```

## S3 Configuration

```python
from deltalake import DeltaTable, write_deltalake

storage_options = {
    "AWS_REGION": "us-east-1",
    "AWS_ACCESS_KEY_ID": "...",
    "AWS_SECRET_ACCESS_KEY": "...",
    # OR use IAM role — no credentials needed on EC2/Lambda
}

write_deltalake(
    "s3://my-bucket/delta/orders",
    data,
    mode="append",
    storage_options=storage_options,
)

dt = DeltaTable("s3://my-bucket/delta/orders", storage_options=storage_options)
```

## Delta vs Iceberg vs Hudi

| Feature | Delta Lake | Apache Iceberg | Apache Hudi |
|---|---|---|---|
| ACID transactions | Yes | Yes | Yes |
| Time travel | Yes | Yes | Yes |
| Schema evolution | Yes | Yes | Yes |
| Streaming + batch | Excellent | Good | Excellent |
| Python standalone | delta-rs | PyIceberg | — |
| Origin | Databricks | Netflix | Uber |
| Best for | Databricks/Spark | Multi-engine, catalog-first | Streaming upserts |

## GitNexus Index

This skill is indexed by GitNexus for knowledge graph traversal.
Index path: /Users/localuser/.claude/skills/delta-lake/.gitnexus
Last indexed: 2026-05-24
