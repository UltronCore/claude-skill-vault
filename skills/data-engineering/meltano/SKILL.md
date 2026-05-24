---
name: meltano
description: Build ELT pipelines with Meltano — the open-source Singer-compatible ELT platform that manages taps, targets, and transformations as code. Use this skill whenever the user wants to extract data from APIs/databases, load into a warehouse, or set up a data pipeline using Singer taps/targets. Trigger for "meltano", "singer tap", "elt pipeline open source", "meltano elt", or "data extraction pipeline".
---

# Meltano: Open-Source ELT Platform

Meltano is a CLI-first ELT (Extract, Load, Transform) platform built on Singer. It manages data pipelines as code — taps (extractors), targets (loaders), and transformations — all version-controlled and reproducible.

## Installation

```bash
# Install via pip
pip install meltano

# Or with pipx (recommended)
pipx install meltano

# Initialize a new project
meltano init my-pipeline
cd my-pipeline
```

## Project Structure

```
my-pipeline/
├── meltano.yml           # project configuration
├── .env                  # secrets (gitignored)
├── .gitignore
├── requirements.txt
├── orchestrate/
│   └── dags/             # Airflow DAGs (if used)
└── transform/
    ├── dbt_project.yml   # dbt transformations
    └── models/
```

## Core Commands

```bash
# List available plugins
meltano discover extractors
meltano discover loaders

# Add plugins
meltano add extractor tap-github
meltano add loader target-postgres

# Configure plugins interactively
meltano config tap-github set --interactive

# Run a pipeline
meltano run tap-github target-postgres

# Test extraction (sample only)
meltano invoke tap-github --test

# Show current config
meltano config tap-github
```

## meltano.yml Configuration

```yaml
version: 1
default_environment: dev

environments:
  - name: dev
  - name: staging
  - name: prod

plugins:
  extractors:
    - name: tap-github
      variant: MeltanoLabs
      pip_url: git+https://github.com/MeltanoLabs/tap-github.git
      config:
        organizations:
          - my-org
        start_date: "2024-01-01T00:00:00Z"
      select:
        - "repositories.*"
        - "pull_requests.*"
        - "issues.*"

    - name: tap-postgres
      variant: meltanolabs
      pip_url: meltano-tap-postgres
      config:
        host: localhost
        port: 5432
        database: source_db
        user: readonly_user
        # password via env: TAP_POSTGRES_PASSWORD

  loaders:
    - name: target-postgres
      variant: meltanolabs
      pip_url: meltanolabs-target-postgres
      config:
        host: ${TARGET_POSTGRES_HOST}
        port: 5432
        database: warehouse
        user: loader_user
        default_target_schema: raw

    - name: target-bigquery
      variant: adswerve
      pip_url: target-bigquery
      config:
        project_id: my-gcp-project
        dataset_id: raw_data

  transformers:
    - name: dbt-postgres
      variant: dbt-labs
      pip_url: dbt-postgres
```

## Environment Variables / Secrets

```bash
# .env file (never commit this)
TAP_GITHUB_PRIVATE_TOKEN=ghp_xxxxxxxxxxxx
TAP_POSTGRES_PASSWORD=mysecretpassword
TARGET_POSTGRES_PASSWORD=myloaderpw
TARGET_POSTGRES_HOST=warehouse.company.com
```

```yaml
# Reference env vars in meltano.yml
plugins:
  extractors:
    - name: tap-github
      config:
        private_token: $TAP_GITHUB_PRIVATE_TOKEN
```

## Running Pipelines

```bash
# Basic run
meltano run tap-github target-postgres

# Specific environment
meltano --environment prod run tap-github target-bigquery

# With state (incremental)
meltano run tap-postgres target-postgres --state-id my-pipeline

# Full refresh (ignore state)
meltano run tap-postgres target-postgres --full-refresh

# Run with dbt transformation
meltano run tap-github target-postgres dbt-postgres:run

# Schedule-based run
meltano schedule add daily-github \
  --extractor tap-github \
  --loader target-postgres \
  --interval "@daily"
```

## State Management (Incremental Loads)

```bash
# View current state
meltano state get --state-id daily-github

# Set state manually
meltano state set --state-id daily-github '{"bookmarks": {"repositories": {"since": "2024-06-01T00:00:00Z"}}}'

# Clear state for full refresh
meltano state clear --state-id daily-github
```

## Common Taps and Targets

### Popular Extractors (taps)

| Tap | Source | Install |
|---|---|---|
| `tap-github` | GitHub API | `meltano add extractor tap-github` |
| `tap-postgres` | PostgreSQL | `meltano add extractor tap-postgres` |
| `tap-mysql` | MySQL | `meltano add extractor tap-mysql` |
| `tap-salesforce` | Salesforce | `meltano add extractor tap-salesforce` |
| `tap-stripe` | Stripe | `meltano add extractor tap-stripe` |
| `tap-google-analytics` | GA4 | `meltano add extractor tap-google-analytics` |
| `tap-hubspot` | HubSpot | `meltano add extractor tap-hubspot` |
| `tap-s3-csv` | S3 CSV files | `meltano add extractor tap-s3-csv` |
| `tap-rest-api-msdk` | Any REST API | `meltano add extractor tap-rest-api-msdk` |

### Popular Loaders (targets)

| Target | Destination | Install |
|---|---|---|
| `target-postgres` | PostgreSQL | `meltano add loader target-postgres` |
| `target-bigquery` | BigQuery | `meltano add loader target-bigquery` |
| `target-snowflake` | Snowflake | `meltano add loader target-snowflake` |
| `target-redshift` | Redshift | `meltano add loader target-redshift` |
| `target-duckdb` | DuckDB | `meltano add loader target-duckdb` |
| `target-jsonl` | JSONL files | `meltano add loader target-jsonl` |
| `target-csv` | CSV files | `meltano add loader target-csv` |

## Custom Singer Tap (Python SDK)

```python
# my_tap/tap.py
from singer_sdk import Tap, Stream
from singer_sdk import typing as th

class MyAPIStream(Stream):
    name = "records"
    schema = th.PropertiesList(
        th.Property("id", th.StringType, required=True),
        th.Property("name", th.StringType),
        th.Property("created_at", th.DateTimeType),
    ).to_dict()

    def get_records(self, context):
        # Your API call here
        response = requests.get(
            "https://api.example.com/records",
            headers={"Authorization": f"Bearer {self.config['api_token']}"},
            params={"since": self.get_starting_timestamp(context)},
        )
        yield from response.json()["data"]

class TapMyAPI(Tap):
    name = "tap-my-api"
    config_jsonschema = th.PropertiesList(
        th.Property("api_token", th.StringType, required=True, secret=True),
        th.Property("start_date", th.DateTimeType),
    ).to_dict()

    def discover_streams(self):
        return [MyAPIStream(self)]

if __name__ == "__main__":
    TapMyAPI.cli()
```

## Orchestration with Airflow

```bash
# Install Airflow integration
meltano add orchestrator airflow

# Initialize Airflow
meltano invoke airflow:initialize

# Start Airflow
meltano invoke airflow standalone

# Schedules auto-create DAGs from meltano.yml
```

## GitNexus Index

This skill is indexed by GitNexus for knowledge graph traversal.
Index path: /Users/localuser/.claude/skills/meltano/.gitnexus
Last indexed: 2026-05-24
