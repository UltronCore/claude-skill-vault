---
name: iceberg
description: Work with Apache Iceberg — an open table format for huge analytic datasets that brings ACID transactions, schema evolution, time travel, and partition pruning to data lakes. Use this skill whenever the user mentions Iceberg, wants to manage large Parquet datasets with transactions, needs time travel queries on a data lake, or is building a lakehouse architecture. Trigger for "apache iceberg", "iceberg table", "iceberg catalog", "iceberg spark", or "open table format".
---

# Apache Iceberg: Open Table Format

Apache Iceberg is an open table format for large analytic datasets. It adds database-like features (ACID transactions, schema evolution, hidden partitioning, time travel) on top of object storage (S3, GCS, ADLS).

## Core Concepts

- **Table format**: Iceberg defines how data files are organized and tracked
- **Catalog**: Tracks table metadata (REST, Hive, Glue, JDBC, Nessie)
- **Snapshot**: Every write creates an immutable snapshot — enables time travel
- **Manifest**: Lists data files and their statistics for query pruning
- **Data files**: Actual Parquet/ORC/Avro files in object storage

## Python with PyIceberg

```bash
pip install pyiceberg[pyarrow,duckdb,s3fs]
```

### Create and Manage Tables

```python
from pyiceberg.catalog import load_catalog
from pyiceberg.schema import Schema
from pyiceberg.types import (
    NestedField, StringType, LongType, DoubleType, 
    TimestampType, BooleanType
)
from pyiceberg.partitioning import PartitionSpec, PartitionField
from pyiceberg.transforms import DayTransform, IdentityTransform
import pyarrow as pa

# Connect to a REST catalog
catalog = load_catalog(
    "default",
    **{
        "type": "rest",
        "uri": "http://localhost:8181",
        "s3.endpoint": "http://localhost:9000",
        "s3.access-key-id": "minioadmin",
        "s3.secret-access-key": "minioadmin",
    }
)

# Define schema
schema = Schema(
    NestedField(1, "order_id", StringType(), required=True),
    NestedField(2, "customer_id", StringType(), required=True),
    NestedField(3, "order_date", TimestampType(), required=True),
    NestedField(4, "region", StringType(), required=True),
    NestedField(5, "revenue", DoubleType()),
    NestedField(6, "status", StringType()),
)

# Partition by day and region (hidden partitioning — no partition columns in schema)
partition_spec = PartitionSpec(
    PartitionField(source_id=3, field_id=1000, name="order_date_day", transform=DayTransform()),
    PartitionField(source_id=4, field_id=1001, name="region", transform=IdentityTransform()),
)

# Create namespace and table
catalog.create_namespace("analytics")
table = catalog.create_table(
    identifier="analytics.orders",
    schema=schema,
    partition_spec=partition_spec,
    properties={
        "write.format.default": "parquet",
        "write.parquet.compression-codec": "zstd",
    }
)
```

### Append Data

```python
import pyarrow as pa
from datetime import datetime

# Create Arrow table
data = pa.table({
    "order_id": ["ord_001", "ord_002", "ord_003"],
    "customer_id": ["cust_A", "cust_B", "cust_A"],
    "order_date": [datetime(2024, 3, 15), datetime(2024, 3, 15), datetime(2024, 3, 16)],
    "region": ["us-east", "eu-west", "us-east"],
    "revenue": [150.0, 280.0, 95.0],
    "status": ["shipped", "processing", "delivered"],
})

# Append to Iceberg table (creates a new snapshot)
table.append(data)

print(f"Current snapshot ID: {table.current_snapshot().snapshot_id}")
print(f"Total files: {len(list(table.scan().plan_files()))}")
```

### Read Data

```python
# Scan with filters (partition pruning happens automatically)
scan = table.scan(
    row_filter="region = 'us-east' AND revenue > 100",
    selected_fields=("order_id", "customer_id", "revenue", "status"),
    limit=1000,
)

# Read as Arrow
arrow_table = scan.to_arrow()

# Read as Pandas
df = scan.to_pandas()

# Read as Dask
dask_df = scan.to_dask()

# Project with date filter — only reads relevant partition files
import pyarrow.compute as pc

scan_filtered = table.scan(
    row_filter=pc.field("order_date") >= pa.scalar(datetime(2024, 3, 15))
)
```

### Time Travel

```python
# List all snapshots
for snapshot in table.history():
    print(f"Snapshot: {snapshot.snapshot_id}, Time: {snapshot.timestamp_ms}, Op: {snapshot.summary['operation']}")

# Read data as of a specific snapshot
old_snapshot_id = table.history()[1].snapshot_id
historical_scan = table.scan(snapshot_id=old_snapshot_id)
historical_df = historical_scan.to_pandas()

# Read data as of a specific timestamp (milliseconds)
as_of_ms = 1710000000000  # Unix timestamp in ms
historical_scan2 = table.scan(as_of_timestamp=as_of_ms)
```

### Schema Evolution

```python
from pyiceberg.types import FloatType

# Add a column (non-breaking)
with table.update_schema() as update:
    update.add_column("discount_pct", FloatType(), "Discount percentage applied")

# Rename a column (safe — metadata only)
with table.update_schema() as update:
    update.rename_column("status", "order_status")

# Make a nullable column required (safe direction)
with table.update_schema() as update:
    update.make_column_optional("discount_pct")

# Change type (widening only — int to long, float to double)
with table.update_schema() as update:
    update.update_column("revenue", field_type=DoubleType())
```

### Table Maintenance

```python
# Expire old snapshots (keeps last 7 days)
table.expire_snapshots().expire_older_than(
    timestamp_ms=int((datetime.now() - timedelta(days=7)).timestamp() * 1000)
).commit()

# Remove orphan files (files not referenced by any snapshot)
table.remove_orphan_files().execute()

# Compact small files into larger ones
table.rewrite_data_files().execute()

# Rewrite manifests (improve scan planning performance)
table.rewrite_manifests().execute()
```

## Spark + Iceberg

```python
from pyspark.sql import SparkSession

spark = SparkSession.builder \
    .appName("iceberg_example") \
    .config("spark.sql.extensions", "org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions") \
    .config("spark.sql.catalog.iceberg", "org.apache.iceberg.spark.SparkCatalog") \
    .config("spark.sql.catalog.iceberg.type", "rest") \
    .config("spark.sql.catalog.iceberg.uri", "http://localhost:8181") \
    .getOrCreate()

# Create table with DDL
spark.sql("""
    CREATE TABLE IF NOT EXISTS iceberg.analytics.events (
        event_id STRING NOT NULL,
        user_id STRING,
        event_type STRING,
        event_time TIMESTAMP,
        properties MAP<STRING, STRING>
    )
    USING iceberg
    PARTITIONED BY (days(event_time), bucket(8, user_id))
""")

# Write data
df = spark.createDataFrame(events_data)
df.writeTo("iceberg.analytics.events").append()

# Time travel with Spark SQL
spark.sql("""
    SELECT * FROM iceberg.analytics.events
    TIMESTAMP AS OF '2024-03-15 00:00:00'
    WHERE event_type = 'purchase'
""")

# Merge (upsert)
spark.sql("""
    MERGE INTO iceberg.analytics.users t
    USING updates s ON t.user_id = s.user_id
    WHEN MATCHED THEN UPDATE SET *
    WHEN NOT MATCHED THEN INSERT *
""")

# View snapshots
spark.sql("SELECT * FROM iceberg.analytics.events.snapshots").show()

# View files in current snapshot
spark.sql("SELECT * FROM iceberg.analytics.events.files").show()
```

## DuckDB + Iceberg

```sql
-- Install Iceberg extension
INSTALL iceberg;
LOAD iceberg;

-- Query an Iceberg table directly
SELECT * FROM iceberg_scan('s3://my-bucket/warehouse/analytics/orders/');

-- Time travel
SELECT * FROM iceberg_scan(
    's3://my-bucket/warehouse/analytics/orders/',
    snapshot_timestamp_ms = 1710000000000
);

-- Get table metadata
SELECT * FROM iceberg_metadata('s3://my-bucket/warehouse/analytics/orders/');
```

## Catalog Options

| Catalog | Use Case | Config |
|---|---|---|
| REST | Production standard | `type: rest, uri: http://...` |
| AWS Glue | AWS ecosystem | `type: glue` |
| Hive Metastore | Hadoop/Hive users | `type: hive, uri: thrift://...` |
| Nessie | Git-like data versioning | `type: rest` (Nessie REST) |
| JDBC | Simple SQL-backed | `type: jdbc` |
| SQLite (local) | Development | `type: sql` |

## GitNexus Index

This skill is indexed by GitNexus for knowledge graph traversal.
Index path: /Users/localuser/.claude/skills/iceberg/.gitnexus
Last indexed: 2026-05-24
