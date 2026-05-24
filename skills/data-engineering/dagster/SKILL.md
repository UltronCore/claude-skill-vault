---
name: dagster
description: Build data pipelines and orchestrate data assets with Dagster — an asset-centric data orchestration platform with built-in lineage, observability, and scheduling. Use this skill whenever the user mentions Dagster, wants to orchestrate data pipelines as software-defined assets, or needs a modern alternative to Airflow with better testing and observability. Trigger for "dagster", "software defined assets", "data asset orchestration", "dagster pipeline", or "dagster dbt".
---

# Dagster: Data Orchestration Platform

Dagster is an asset-centric orchestration platform. Instead of thinking about tasks and dependencies, you define data assets — and Dagster figures out how to produce them. This gives you automatic lineage, observability, and incremental computation.

## Installation

```bash
pip install dagster dagster-webserver

# With common integrations
pip install dagster-dbt dagster-duckdb dagster-pandas dagster-aws dagster-gcp
```

## Core Concepts

### Software-Defined Assets (SDAs)

```python
# assets.py
from dagster import asset, AssetExecutionContext
import pandas as pd
import duckdb

# Each @asset is a data artifact you want to produce
@asset
def raw_orders(context: AssetExecutionContext) -> pd.DataFrame:
    """Raw orders data from source database."""
    df = pd.read_csv("data/orders.csv")
    context.log.info(f"Loaded {len(df)} orders")
    return df

@asset
def cleaned_orders(raw_orders: pd.DataFrame) -> pd.DataFrame:
    """Cleaned and validated orders data."""
    df = raw_orders.copy()
    df = df.dropna(subset=['customer_id', 'order_date'])
    df['order_date'] = pd.to_datetime(df['order_date'])
    df['revenue'] = df['quantity'] * df['unit_price']
    return df

@asset
def monthly_revenue(cleaned_orders: pd.DataFrame) -> pd.DataFrame:
    """Monthly revenue aggregation."""
    return (
        cleaned_orders
        .groupby(cleaned_orders['order_date'].dt.to_period('M'))
        ['revenue']
        .sum()
        .reset_index()
        .rename(columns={'order_date': 'month'})
    )
```

### Defining a Job and Repository

```python
# definitions.py
from dagster import Definitions, define_asset_job, ScheduleDefinition, AssetSelection

from .assets import raw_orders, cleaned_orders, monthly_revenue

# Job to materialize assets
orders_job = define_asset_job(
    name="orders_pipeline",
    selection=AssetSelection.assets(raw_orders, cleaned_orders, monthly_revenue),
)

# Schedule
daily_schedule = ScheduleDefinition(
    job=orders_job,
    cron_schedule="0 6 * * *",  # 6 AM daily
)

# Definitions is the entry point
defs = Definitions(
    assets=[raw_orders, cleaned_orders, monthly_revenue],
    jobs=[orders_job],
    schedules=[daily_schedule],
)
```

### Resources (Dependency Injection)

```python
from dagster import asset, Definitions, ConfigurableResource
import duckdb

class DuckDBResource(ConfigurableResource):
    database_path: str

    def query(self, sql: str) -> list:
        con = duckdb.connect(self.database_path)
        return con.execute(sql).fetchall()

    def execute(self, sql: str) -> None:
        con = duckdb.connect(self.database_path)
        con.execute(sql)

@asset
def user_stats(context, duckdb: DuckDBResource):
    rows = duckdb.query("SELECT COUNT(*) as total, AVG(age) FROM users")
    return {"total": rows[0][0], "avg_age": rows[0][1]}

defs = Definitions(
    assets=[user_stats],
    resources={
        "duckdb": DuckDBResource(database_path="analytics.db"),
    },
)
```

### Asset Checks (Data Quality)

```python
from dagster import asset, asset_check, AssetCheckResult

@asset
def orders(context) -> pd.DataFrame:
    return pd.read_csv("orders.csv")

@asset_check(asset=orders)
def orders_not_empty(orders: pd.DataFrame) -> AssetCheckResult:
    return AssetCheckResult(
        passed=len(orders) > 0,
        description=f"Orders has {len(orders)} rows",
    )

@asset_check(asset=orders)
def no_null_customer_ids(orders: pd.DataFrame) -> AssetCheckResult:
    null_count = orders['customer_id'].isna().sum()
    return AssetCheckResult(
        passed=null_count == 0,
        description=f"{null_count} null customer IDs found",
        severity=AssetCheckSeverity.WARN if null_count > 0 else AssetCheckSeverity.ERROR,
    )
```

### Partitioned Assets

```python
from dagster import asset, DailyPartitionsDefinition, AssetExecutionContext

daily_partitions = DailyPartitionsDefinition(start_date="2024-01-01")

@asset(partitions_def=daily_partitions)
def daily_events(context: AssetExecutionContext) -> pd.DataFrame:
    partition_date = context.partition_key  # e.g., "2024-03-15"
    
    df = pd.read_parquet(f"s3://bucket/events/date={partition_date}/")
    context.log.info(f"Loaded {len(df)} events for {partition_date}")
    return df

@asset(partitions_def=daily_partitions)
def daily_metrics(daily_events: pd.DataFrame) -> dict:
    return {
        "event_count": len(daily_events),
        "unique_users": daily_events['user_id'].nunique(),
        "revenue": daily_events['revenue'].sum(),
    }
```

### dbt Integration

```python
from dagster_dbt import DbtCliResource, dbt_assets, DbtProject

my_project = DbtProject(project_dir="./dbt_project")

@dbt_assets(manifest=my_project.manifest_path)
def my_dbt_assets(context: AssetExecutionContext, dbt: DbtCliResource):
    yield from dbt.cli(["build"], context=context).stream()

defs = Definitions(
    assets=[my_dbt_assets],
    resources={
        "dbt": DbtCliResource(project_dir=my_project),
    },
)
```

### Sensors (Event-Triggered Pipelines)

```python
from dagster import sensor, RunRequest, SensorEvaluationContext
import os

@sensor(job=orders_job, minimum_interval_seconds=30)
def new_file_sensor(context: SensorEvaluationContext):
    """Trigger pipeline when a new file appears in the data directory."""
    files = os.listdir("data/incoming/")
    
    for filename in files:
        if filename.endswith('.csv'):
            yield RunRequest(
                run_key=filename,
                run_config={
                    "ops": {"raw_orders": {"config": {"filename": filename}}}
                },
            )
```

## Running Dagster

```bash
# Start the UI (Dagit)
dagster dev -f definitions.py
# Open http://localhost:3000

# Run a job from CLI
dagster job execute -f definitions.py -j orders_pipeline

# Materialize specific assets
dagster asset materialize -f definitions.py --select monthly_revenue

# Run with partitions
dagster asset materialize -f definitions.py \
  --select daily_events \
  --partition 2024-03-15
```

## Testing

```python
from dagster import materialize, build_asset_context
from .assets import cleaned_orders, monthly_revenue
import pandas as pd

def test_cleaned_orders():
    raw = pd.DataFrame({
        'customer_id': ['c1', None, 'c3'],
        'order_date': ['2024-01-01', '2024-01-02', '2024-01-03'],
        'quantity': [2, 1, 3],
        'unit_price': [10.0, 20.0, 5.0],
    })
    
    result = cleaned_orders(raw)
    
    assert len(result) == 2  # null customer_id dropped
    assert 'revenue' in result.columns
    assert result['revenue'].tolist() == [20.0, 15.0]

def test_pipeline_end_to_end():
    result = materialize([raw_orders, cleaned_orders, monthly_revenue])
    assert result.success
```

## Key Benefits Over Airflow

- Asset lineage is built-in — Dagster knows which assets depend on which
- Partial re-runs — only re-materialize what changed
- UI shows asset health, not just task runs
- Much better testing story — assets are just Python functions
- Type-aware — knows what each asset produces
- Partitions are first-class — easy backfills

## GitNexus Index

This skill is indexed by GitNexus for knowledge graph traversal.
Index path: /Users/localuser/.claude/skills/dagster/.gitnexus
Last indexed: 2026-05-24
