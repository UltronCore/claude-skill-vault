---
name: dlt
description: Load data into any destination with dlt (data load tool) — a Python library for building self-maintaining, scalable data ingestion pipelines. Use this skill whenever the user wants to load data from APIs, files, or databases into DuckDB, BigQuery, Snowflake, Postgres, or other warehouses using Python. Trigger for "dlt pipeline", "data load tool", "dlt python", "python data ingestion", or "dlt destination".
---

# dlt: Python Data Ingestion Library

dlt (data load tool) is a Python library for building production-ready data pipelines. Define a source, define a destination, run it. dlt handles schema inference, incremental loading, schema evolution, and normalization automatically.

## Installation

```bash
pip install dlt

# With specific destinations
pip install 'dlt[duckdb]'      # DuckDB
pip install 'dlt[bigquery]'    # BigQuery
pip install 'dlt[snowflake]'   # Snowflake
pip install 'dlt[postgres]'    # PostgreSQL
pip install 'dlt[filesystem]'  # S3, GCS, Azure Blob
pip install 'dlt[redshift]'    # Redshift
```

## Core Concepts

### Simple Pipeline

```python
import dlt

# Define a source (any Python iterable)
@dlt.resource
def github_issues(repo: str):
    import requests
    url = f"https://api.github.com/repos/{repo}/issues"
    headers = {"Authorization": f"token {dlt.secrets['github_token']}"}
    
    page = 1
    while True:
        response = requests.get(url, headers=headers, params={"page": page, "per_page": 100})
        issues = response.json()
        if not issues:
            break
        yield issues
        page += 1

# Create and run pipeline
pipeline = dlt.pipeline(
    pipeline_name="github_pipeline",
    destination="duckdb",          # or bigquery, snowflake, postgres, etc.
    dataset_name="github_data",
)

load_info = pipeline.run(github_issues("dlt-hub/dlt"))
print(load_info)
```

### Incremental Loading

```python
import dlt
from dlt.sources.helpers import requests

@dlt.resource(
    write_disposition="append",  # merge, replace, or append
    primary_key="id",
)
def orders(
    updated_at=dlt.sources.incremental(
        "updated_at",                          # cursor field
        initial_value="2024-01-01T00:00:00Z", # first run start
    )
):
    """Only fetch orders updated since last run."""
    params = {
        "updated_since": updated_at.last_value,  # dlt tracks this
        "per_page": 100,
    }
    
    for page in requests.paginate("https://api.example.com/orders", params=params):
        yield page

pipeline = dlt.pipeline("orders_pipeline", destination="postgres", dataset_name="raw")
pipeline.run(orders())
```

### Merge (Upsert)

```python
import dlt

@dlt.resource(
    write_disposition="merge",
    primary_key="id",
    merge_key="updated_at",  # records with newer timestamp replace old ones
)
def users():
    yield [
        {"id": 1, "name": "Alice", "email": "alice@example.com", "updated_at": "2024-06-01"},
        {"id": 2, "name": "Bob", "email": "bob@example.com", "updated_at": "2024-06-01"},
    ]

pipeline = dlt.pipeline("users_pipeline", destination="duckdb", dataset_name="raw")
pipeline.run(users())
```

### Sources (Multiple Resources)

```python
import dlt
from dlt.sources.helpers import requests

@dlt.source
def shopify(shop_url: str = dlt.config.value, api_key: str = dlt.secrets.value):
    """Shopify data source with multiple resources."""
    base_url = f"https://{shop_url}/admin/api/2024-01"
    headers = {"X-Shopify-Access-Token": api_key}

    @dlt.resource(write_disposition="replace")
    def products():
        for page in requests.paginate(f"{base_url}/products.json", headers=headers):
            yield page["products"]

    @dlt.resource(primary_key="id", write_disposition="append")
    def orders(created_at_min=dlt.sources.incremental("created_at")):
        params = {"created_at_min": created_at_min.last_value, "limit": 250}
        for page in requests.paginate(f"{base_url}/orders.json", headers=headers, params=params):
            yield page["orders"]

    @dlt.resource(write_disposition="replace")
    def customers():
        for page in requests.paginate(f"{base_url}/customers.json", headers=headers):
            yield page["customers"]

    return products, orders, customers

# Run all resources
pipeline = dlt.pipeline("shopify_pipeline", destination="bigquery", dataset_name="shopify_raw")
pipeline.run(shopify())

# Or run specific resources
pipeline.run(shopify().with_resources("orders", "products"))
```

### Transformers (Resource-to-Resource)

```python
import dlt

@dlt.resource
def repos(org: str):
    """List repos for an org."""
    import requests
    response = requests.get(f"https://api.github.com/orgs/{org}/repos")
    yield from response.json()

@dlt.transformer(data_from=repos)
def repo_issues(repo):
    """For each repo, fetch its issues."""
    import requests
    issues = requests.get(f"https://api.github.com/repos/{repo['full_name']}/issues")
    yield from issues.json()

pipeline = dlt.pipeline("github", destination="duckdb", dataset_name="github")

# repos pipes into repo_issues automatically
pipeline.run([repos("dlt-hub"), repo_issues])
```

### File-Based Pipelines

```python
import dlt

# Load from CSV files
@dlt.resource
def csv_files():
    import glob
    import csv
    for filepath in glob.glob("data/*.csv"):
        with open(filepath) as f:
            reader = csv.DictReader(f)
            yield from reader

# Load from JSON files  
@dlt.resource
def json_files():
    import glob
    import json
    for filepath in glob.glob("data/*.json"):
        with open(filepath) as f:
            data = json.load(f)
            yield data if isinstance(data, list) else [data]

pipeline = dlt.pipeline("file_pipeline", destination="duckdb", dataset_name="raw")
pipeline.run([csv_files(), json_files()])
```

### Configuration and Secrets

```python
# .dlt/secrets.toml (never commit this)
# [sources.shopify]
# api_key = "shpat_xxxxxxxxxxxx"
# [destination.bigquery]
# credentials = "path/to/service_account.json"

# .dlt/config.toml
# [sources.shopify]
# shop_url = "my-store.myshopify.com"

# Access in code
@dlt.source
def my_source(
    api_key: str = dlt.secrets.value,  # required from secrets.toml
    base_url: str = dlt.config.value,  # from config.toml
    timeout: int = 30,                 # has default
):
    pass
```

### Schema and Type Hints

```python
import dlt
from typing import Iterator, Optional
from datetime import datetime

# Define explicit types with dataclasses or TypedDicts
from typing import TypedDict

class Order(TypedDict):
    id: str
    customer_id: str
    total: float
    status: str
    created_at: datetime
    notes: Optional[str]

@dlt.resource(columns=Order)  # enforces schema
def typed_orders() -> Iterator[Order]:
    yield {
        "id": "ord_123",
        "customer_id": "cust_456",
        "total": 99.99,
        "status": "shipped",
        "created_at": datetime.now(),
        "notes": None,
    }
```

### Running in Production

```python
# Run with logging
import logging
logging.basicConfig(level=logging.INFO)

pipeline = dlt.pipeline(
    pipeline_name="production_pipeline",
    destination="snowflake",
    dataset_name="raw",
    dev_mode=False,  # True for testing (drops and recreates schema)
)

try:
    load_info = pipeline.run(my_source())
    
    # Check for load errors
    for package in load_info.load_packages:
        for job in package.failed_jobs:
            print(f"Failed job: {job.job_file_path}, error: {job.error_type}")
    
    print(pipeline.last_trace.last_normalize_info)
    print(pipeline.last_trace.last_load_info)
    
except Exception as e:
    print(f"Pipeline failed: {e}")
    raise
```

## Supported Destinations

| Destination | Package |
|---|---|
| DuckDB | `dlt[duckdb]` |
| BigQuery | `dlt[bigquery]` |
| Snowflake | `dlt[snowflake]` |
| Redshift | `dlt[redshift]` |
| PostgreSQL | `dlt[postgres]` |
| Databricks | `dlt[databricks]` |
| ClickHouse | `dlt[clickhouse]` |
| S3/GCS/Azure | `dlt[filesystem]` |
| Delta Lake | `dlt[deltalake]` |
| Weaviate | `dlt[weaviate]` |
| Qdrant | `dlt[qdrant]` |

## Built-in Sources

```bash
# Install verified sources
pip install 'dlt[sources]'

# Available: github, slack, stripe, hubspot, salesforce,
# google_analytics, facebook_ads, notion, airtable, jira,
# shopify, zendesk, and many more
```

## GitNexus Index

This skill is indexed by GitNexus for knowledge graph traversal.
Index path: /Users/localuser/.claude/skills/dlt/.gitnexus
Last indexed: 2026-05-24
