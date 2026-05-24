---
name: dbt-analytics
description: Build, test, and document analytics transformations with dbt (data build tool). Covers model design, incremental models, testing, documentation, and deployment with dbt Cloud or dbt Core.
version: 1.0.0
tags: [dbt, analytics, data-warehouse, sql, transformation, data-engineering]
---

# dbt Analytics Engineering

## Overview

This skill covers building production-grade dbt projects from scratch: project structure, model layering (staging/intermediate/mart), incremental materialization, testing strategies, and documentation. It applies to any SQL data warehouse (BigQuery, Snowflake, Redshift, DuckDB, Postgres) and targets analytics engineers building reliable, testable data transformations.

## When to Use

- Building analytics models in a data warehouse that need version control and testing
- Migrating ad-hoc SQL scripts to a maintainable dbt project
- Adding data quality tests to existing warehouse tables
- Implementing incremental loading for large fact tables
- Creating self-documenting data models with lineage

## Step-by-Step Workflow

### 1. Project Setup
```bash
pip install dbt-core dbt-bigquery  # or dbt-snowflake, dbt-redshift, dbt-duckdb

dbt init my_analytics
cd my_analytics
# Configure profiles.yml (~/.dbt/profiles.yml)
```

```yaml
# ~/.dbt/profiles.yml
my_analytics:
  target: dev
  outputs:
    dev:
      type: bigquery
      method: oauth
      project: my-gcp-project
      dataset: dbt_dev_yourname
      threads: 4
      timeout_seconds: 300
    prod:
      type: bigquery
      method: service-account
      project: my-gcp-project
      dataset: analytics
      keyfile: /path/to/service-account.json
      threads: 8
```

### 2. Project Structure (Layered Architecture)
```
models/
├── staging/           # 1:1 with source tables, light transforms only
│   ├── _sources.yml   # Source definitions
│   ├── stg_orders.sql
│   └── stg_customers.sql
├── intermediate/      # Business logic, joins, not exposed to BI
│   └── int_order_items_with_products.sql
└── marts/             # Business-facing, BI-ready
    ├── core/
    │   ├── dim_customers.sql
    │   └── fct_orders.sql
    └── finance/
        └── fct_revenue_daily.sql
```

### 3. Model Types

**Staging model (stg_orders.sql)**:
```sql
-- models/staging/stg_orders.sql
{{ config(materialized='view') }}

with source as (
    select * from {{ source('raw', 'orders') }}
),

renamed as (
    select
        id                          as order_id,
        user_id                     as customer_id,
        status,
        cast(total_amount as numeric) / 100 as total_usd,
        cast(created_at as timestamp)       as created_at,
        cast(updated_at as timestamp)       as updated_at
    from source
    where id is not null
)

select * from renamed
```

**Fact table (fct_orders.sql)**:
```sql
-- models/marts/core/fct_orders.sql
{{ config(
    materialized='incremental',
    unique_key='order_id',
    incremental_strategy='merge',
    cluster_by=['created_date']
) }}

with orders as (
    select * from {{ ref('stg_orders') }}
    {% if is_incremental() %}
    where updated_at > (select max(updated_at) from {{ this }})
    {% endif %}
),

customers as (select * from {{ ref('dim_customers') }}),

final as (
    select
        o.order_id,
        o.customer_id,
        c.customer_name,
        c.customer_segment,
        o.status,
        o.total_usd,
        date(o.created_at) as created_date,
        o.created_at,
        o.updated_at
    from orders o
    left join customers c using (customer_id)
)

select * from final
```

### 4. Testing
```yaml
# models/marts/core/_schema.yml
version: 2

models:
  - name: fct_orders
    description: "One row per order, final state"
    columns:
      - name: order_id
        description: "Unique order identifier"
        tests:
          - unique
          - not_null
      - name: customer_id
        tests:
          - not_null
          - relationships:
              to: ref('dim_customers')
              field: customer_id
      - name: status
        tests:
          - accepted_values:
              values: ['pending', 'processing', 'shipped', 'delivered', 'cancelled']
      - name: total_usd
        tests:
          - not_null
          - dbt_utils.accepted_range:
              min_value: 0
              max_value: 100000
```

```bash
# Run tests
dbt test
dbt test --select fct_orders  # Single model
dbt test --select tag:critical  # By tag
```

### 5. Macros and Packages
```sql
-- macros/cents_to_dollars.sql
{% macro cents_to_dollars(column_name) %}
    ({{ column_name }} / 100.0)::numeric(10,2)
{% endmacro %}

-- Usage in model:
select {{ cents_to_dollars('amount_cents') }} as amount_usd
```

```yaml
# packages.yml
packages:
  - package: dbt-labs/dbt_utils
    version: 1.1.1
  - package: calogica/dbt_expectations
    version: 0.10.1
```

```bash
dbt deps  # Install packages
```

### 6. Running in Production
```bash
# Full refresh (rebuild from scratch)
dbt run --full-refresh --target prod

# Selective run
dbt run --select "marts.core+"  # model and all downstream
dbt run --select "+dim_customers"  # model and all upstream

# Slim CI (only changed models)
dbt run --select "state:modified+"

# Generate and serve docs
dbt docs generate
dbt docs serve --port 8080
```

## Key Commands Reference

```bash
dbt debug          # Validate connection and project
dbt compile        # Compile SQL without running
dbt run            # Execute models
dbt test           # Run tests
dbt snapshot       # Run snapshot models (slowly changing dimensions)
dbt seed           # Load CSV files as tables
dbt source freshness  # Check source freshness
dbt list           # List models, tests, sources
dbt build          # run + test + snapshot + seed in one

# Show compiled SQL for a model
dbt compile --select fct_orders --inline

# Open lineage DAG
dbt docs generate && dbt docs serve
```

## Common Patterns

### Pattern 1: Slowly Changing Dimension (SCD Type 2 with Snapshots)
```yaml
# snapshots/customer_snapshot.sql
{% snapshot customer_snapshot %}
{{
    config(
        target_schema='snapshots',
        unique_key='customer_id',
        strategy='timestamp',
        updated_at='updated_at',
    )
}}
select * from {{ source('raw', 'customers') }}
{% endsnapshot %}
```

### Pattern 2: Generic Test as Macro
```sql
-- tests/generic/is_positive.sql
{% test is_positive(model, column_name) %}
select {{ column_name }}
from {{ model }}
where {{ column_name }} < 0
{% endtest %}
```

### Pattern 3: Environment-Specific Logic
```sql
-- Use smaller dataset in dev
select * from {{ source('raw', 'events') }}
{% if target.name == 'dev' %}
where event_date >= current_date - interval '7 days'
{% endif %}
```

## Pitfalls to Avoid

1. **Skipping the staging layer**: Putting business logic directly in mart models makes it impossible to reuse source transformations. Always stage first (rename, cast, light cleaning) before any joins or business logic. This pays off the moment you need the same source in two marts.

2. **Full refresh on incremental models in production**: `dbt run --full-refresh` on a 10-billion-row fact table is catastrophic. Test incremental logic with `is_incremental()` in dev against a small dataset. Always validate that the `unique_key` truly identifies rows before deploying incremental models.

3. **Circular references**: dbt models using `ref()` build a DAG — circular references fail at compile time. If two models need each other's data, extract the shared logic into an intermediate model that both reference.

## Related Skills

- `clickhouse-analytics` — ClickHouse as a dbt target for high-performance analytics
- `data-quality-validation` — Layered data quality beyond dbt tests
- `kafka-event-streaming` — Streaming source data into the warehouse before dbt
- `airflow-dag-patterns` — Orchestrating dbt runs with Airflow

## GitNexus Index

```json
{
  "skill": "dbt-analytics",
  "category": "data-engineering",
  "triggers": ["dbt", "data build tool", "analytics engineering", "sql transformation", "data warehouse transformation", "dbt model"],
  "outputs": ["dbt models", "schema tests", "documentation", "lineage DAG"],
  "complexity": "medium",
  "tools": ["dbt-core", "dbt-cloud", "bigquery", "snowflake", "redshift", "duckdb"]
}
```
