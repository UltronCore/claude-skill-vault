---
name: data-orchestration
description: Route data pipeline tasks — ETL, workflow orchestration, stream processing, transformation, ingestion
type: tool-routing
repos_absorbed: [dlt, dagster, prefect, dbt-core, bytewax, airbyte]
---

# Data Orchestration

Routes data pipeline and orchestration tasks to the right tool based on scope and data movement pattern.

## Routing Table

| Need | Tool |
|------|------|
| Load data from APIs/DBs to warehouses | dlt (data load tool) |
| Full pipeline orchestration + assets | dagster |
| Workflow orchestration (Python-native) | prefect |
| SQL transformation layer | dbt-core |
| Real-time stream processing (Python) | bytewax |
| Open-source ELT connectors | airbyte |

## dlt — Lightweight Data Loading

```python
# pip install dlt

import dlt

# Load from REST API to DuckDB
@dlt.resource
def github_events():
    import requests
    response = requests.get("https://api.github.com/events")
    yield from response.json()

pipeline = dlt.pipeline(
    pipeline_name="github",
    destination="duckdb",
    dataset_name="events"
)

load_info = pipeline.run(github_events())
print(load_info)
```

**Destinations**: DuckDB, BigQuery, Snowflake, Redshift, Postgres, Filesystem, REST API
**Sources**: REST API, SQL databases, cloud storage, custom Python generators

```python
# Auto-infer schema from REST API
import dlt
from dlt.sources.rest_api import rest_api_source

source = rest_api_source({
    "client": {"base_url": "https://api.example.com"},
    "resources": [
        {"name": "users", "endpoint": "/users"},
        {"name": "orders", "endpoint": "/orders"}
    ]
})

pipeline = dlt.pipeline(destination="bigquery", dataset_name="app_data")
pipeline.run(source)
```

## dagster — Asset-Based Pipeline Orchestration

```python
# pip install dagster dagster-webserver

from dagster import asset, define_asset_job, Definitions

@asset
def raw_orders():
    """Fetch raw orders from source system."""
    return fetch_orders_from_api()

@asset
def cleaned_orders(raw_orders):
    """Clean and validate order data."""
    df = pd.DataFrame(raw_orders)
    return df.dropna().reset_index(drop=True)

@asset
def orders_report(cleaned_orders):
    """Generate summary report."""
    return cleaned_orders.groupby("status").size().to_dict()

defs = Definitions(
    assets=[raw_orders, cleaned_orders, orders_report],
    jobs=[define_asset_job("orders_pipeline")]
)
```

```bash
# Start Dagster UI
dagster dev  # opens at localhost:3000

# Run job from CLI
dagster job execute -j orders_pipeline
```

**Dagster strengths**: Asset lineage graph, data catalog, partitioned backfills, built-in sensors/schedules, software-defined assets

## prefect — Python-Native Workflow Orchestration

```python
# pip install prefect

from prefect import flow, task
from prefect.deployments import Deployment

@task(retries=3, retry_delay_seconds=10)
def extract_data(source_url: str) -> list:
    return requests.get(source_url).json()

@task
def transform_data(data: list) -> list:
    return [item for item in data if item.get("active")]

@task
def load_data(data: list, target: str) -> None:
    db.insert_many(target, data)

@flow(name="etl-pipeline", log_prints=True)
def etl_pipeline(source_url: str, target: str):
    raw = extract_data(source_url)
    clean = transform_data(raw)
    load_data(clean, target)

if __name__ == "__main__":
    etl_pipeline("https://api.example.com/data", "users")
```

```bash
# Start Prefect server
prefect server start  # localhost:4200

# Deploy flow
prefect deploy --name prod-etl
```

## dbt-core — SQL Transformation Layer

```bash
# pip install dbt-core dbt-postgres  (or dbt-bigquery, dbt-snowflake)

# Initialize project
dbt init my_project
cd my_project

# Configure profiles.yml (~/.dbt/profiles.yml)
# my_project:
#   target: dev
#   outputs:
#     dev:
#       type: postgres
#       host: localhost
#       database: analytics
#       schema: dbt_dev
```

```sql
-- models/staging/stg_orders.sql
SELECT
    order_id,
    customer_id,
    status,
    created_at::date AS order_date
FROM {{ source('raw', 'orders') }}
WHERE status != 'cancelled'

-- models/marts/orders_summary.sql
SELECT
    order_date,
    COUNT(*) AS order_count,
    SUM(amount) AS total_revenue
FROM {{ ref('stg_orders') }}
GROUP BY 1
ORDER BY 1
```

```bash
dbt run              # run all models
dbt run --select stg_orders   # run specific model
dbt test             # run data quality tests
dbt docs generate && dbt docs serve  # data catalog UI
```

## bytewax — Real-Time Stream Processing

```python
# pip install bytewax

from bytewax.dataflow import Dataflow
from bytewax.connectors.kafka import KafkaSource
from bytewax.connectors.stdio import StdOutSink

flow = Dataflow("order-processor")

# Consume from Kafka
stream = flow.input("kafka-in", KafkaSource(
    brokers=["localhost:9092"],
    topics=["orders"]
))

# Transform
def parse_order(msg):
    import json
    data = json.loads(msg.value)
    return (data["customer_id"], data["amount"])

def aggregate_by_customer(customer_id, amounts):
    return (customer_id, sum(amounts))

stream = stream.map("parse", parse_order)
stream = stream.reduce_window("aggregate", aggregate_by_customer)
stream.output("stdout", StdOutSink())

# Run
from bytewax.run import cli_main
cli_main(flow)
```

## airbyte — Open-Source ELT Connectors

```bash
# Docker Compose (local)
git clone https://github.com/airbytehq/airbyte.git
cd airbyte
./run-ab-platform.sh
# Access at http://localhost:8000

# Or use Airbyte Cloud
```

**Airbyte API**:
```python
import airbyte as ab

# Use a pre-built source connector
source = ab.get_source(
    "source-github",
    config={"credentials": {"personal_access_token": "$GITHUB_TOKEN"}, "repositories": ["myorg/myrepo"]}
)

# Read into pandas
result = source.read()
df = result["issues"].to_pandas()
```

**Available connectors**: Postgres, MySQL, Snowflake, BigQuery, S3, GitHub, Stripe, Salesforce, Google Sheets, HubSpot, Shopify (300+ connectors)

## Decision Guide

**"Load data from an API into a warehouse"** → dlt (simplest)
**"Build a full data platform with asset catalog"** → dagster
**"Orchestrate Python functions with retries/scheduling"** → prefect
**"Transform data in a warehouse with SQL"** → dbt-core
**"Process Kafka/event streams in real-time"** → bytewax
**"Sync data between SaaS tools with pre-built connectors"** → airbyte

## Common Patterns

### dlt + dbt (popular combo)
```python
# 1. Load with dlt
pipeline = dlt.pipeline(destination="bigquery", dataset_name="raw")
pipeline.run(source)

# 2. Transform with dbt
# (run dbt after load in same orchestration job)
import subprocess
subprocess.run(["dbt", "run", "--select", "marts+"])
```

### Prefect + dbt
```python
from prefect_dbt.cli.commands import DbtCoreOperation

@flow
def dbt_flow():
    DbtCoreOperation(commands=["dbt run", "dbt test"]).run()
```

## Environment Variables

```bash
# dlt destinations
DESTINATION__BIGQUERY__CREDENTIALS_FILE=credentials.json
DESTINATION__POSTGRES__CREDENTIALS=postgresql://user:pass@host/db

# Prefect
PREFECT_API_URL=http://localhost:4200/api

# dbt profiles
DBT_PROFILES_DIR=~/.dbt/

# Airbyte
AIRBYTE_API_KEY=          # for Airbyte Cloud
```

## GitNexus Index
This skill is indexed by GitNexus for knowledge graph traversal.
Index path: /Users/localuser/claude-skill-vault/skills/orchestration/data-orchestration/.gitnexus
Last indexed: 2026-05-23
