---
name: data-quality-validation
description: Implement data quality checks using Great Expectations, dbt tests, Pandera, Pydantic, and SQL constraints. Covers schema validation, statistical tests, anomaly detection, and alerting.
version: 1.0.0
tags: [data-quality, great-expectations, pandera, dbt-tests, validation, data-engineering]
---

# Data Quality Validation

## Overview

This skill covers implementing comprehensive data quality checks across the data lifecycle: schema validation at ingestion, business rule checks in transformation layers, statistical anomaly detection, and automated alerting. It covers multiple tooling tiers: Pydantic/Pandera for Python, dbt tests for SQL transforms, Great Expectations for full pipeline validation, and SQL constraints for database-level enforcement.

## When to Use

- Incoming data from external sources (APIs, files, third parties) needs validation before processing
- ETL/ELT pipelines need checks between transformation layers
- Detecting data drift: schema changes, distribution shifts, volume anomalies
- Meeting SLAs or compliance requirements that demand data quality guarantees
- Investigating why dashboards show wrong numbers

## Step-by-Step Workflow

### 1. Pydantic Schema Validation (Python Ingestion)
```python
from pydantic import BaseModel, Field, validator, field_validator
from datetime import datetime
from typing import Optional
from enum import Enum

class OrderStatus(str, Enum):
    PENDING = "pending"
    CONFIRMED = "confirmed"
    SHIPPED = "shipped"
    DELIVERED = "delivered"
    CANCELLED = "cancelled"

class OrderRow(BaseModel):
    order_id: str = Field(min_length=1, max_length=50)
    customer_id: str = Field(min_length=1)
    status: OrderStatus
    amount: float = Field(gt=0, le=1_000_000)  # > 0 and <= $1M
    currency: str = Field(pattern=r'^[A-Z]{3}$')  # ISO 4217
    created_at: datetime
    shipped_at: Optional[datetime] = None

    @field_validator('shipped_at')
    @classmethod
    def shipped_after_created(cls, v, info):
        if v and info.data.get('created_at') and v < info.data['created_at']:
            raise ValueError('shipped_at must be after created_at')
        return v

def validate_orders(raw_records: list[dict]) -> tuple[list[OrderRow], list[dict]]:
    """Returns (valid_records, error_records)."""
    valid, errors = [], []
    for record in raw_records:
        try:
            valid.append(OrderRow(**record))
        except Exception as e:
            errors.append({"record": record, "error": str(e)})
    return valid, errors

valid, errors = validate_orders(raw_data)
print(f"Valid: {len(valid)}, Errors: {len(errors)}")
if errors:
    send_to_dead_letter_queue(errors)
```

### 2. Pandera for DataFrame Validation
```python
import pandera as pa
from pandera import Column, Check, DataFrameSchema
import pandas as pd

# Define schema
order_schema = DataFrameSchema({
    "order_id": Column(str, Check.str_length(min_value=1, max_value=50)),
    "amount": Column(float, [
        Check.gt(0),
        Check.lt(1_000_000),
        Check(lambda s: s.isna().sum() == 0, error="No nulls allowed in amount"),
    ]),
    "status": Column(str, Check.isin(["pending", "confirmed", "shipped", "delivered", "cancelled"])),
    "created_at": Column("datetime64[ns]"),
    "customer_id": Column(str, nullable=False),
}, checks=[
    # Cross-column checks
    Check(lambda df: (df["shipped_at"].isna() | (df["shipped_at"] >= df["created_at"])).all(),
          error="shipped_at must be >= created_at"),
])

def validate_dataframe(df: pd.DataFrame) -> pd.DataFrame:
    try:
        return order_schema.validate(df, lazy=True)  # lazy=True: collect all errors
    except pa.errors.SchemaErrors as exc:
        print(f"Schema validation failed:\n{exc.failure_cases}")
        raise

# Coerce types automatically
strict_schema = order_schema.coerce_dtypes()
clean_df = strict_schema.validate(raw_df)
```

### 3. Great Expectations Pipeline
```python
import great_expectations as gx

# Initialize context
context = gx.get_context()

# Create datasource
datasource = context.sources.add_pandas_filesystem(
    name="orders_datasource",
    base_directory="data/",
)
asset = datasource.add_csv_asset(name="orders", batching_regex=r"orders_(?P<date>\d{8})\.csv")

# Define expectations suite
suite = context.add_expectation_suite("orders_suite")

# Add expectations
validator = context.get_validator(batch_request=..., expectation_suite_name="orders_suite")

validator.expect_table_row_count_to_be_between(min_value=1000, max_value=10_000_000)
validator.expect_column_to_exist("order_id")
validator.expect_column_values_to_not_be_null("order_id")
validator.expect_column_values_to_be_unique("order_id")
validator.expect_column_values_to_match_regex("order_id", r"^ORD-\d{6,}$")
validator.expect_column_values_to_be_between("amount", min_value=0, max_value=1_000_000)
validator.expect_column_values_to_be_in_set("currency", ["USD", "EUR", "GBP", "CAD"])
validator.expect_column_mean_to_be_between("amount", min_value=50, max_value=500)  # Statistical
validator.expect_column_quantile_values_to_be_between(
    "amount",
    quantile_ranges={"quantiles": [0.25, 0.75], "value_ranges": [[10, 100], [200, 1000]]},
)

validator.save_expectation_suite()

# Run checkpoint (in production pipeline)
checkpoint = context.add_checkpoint(
    name="daily_orders_check",
    validations=[{"batch_request": ..., "expectation_suite_name": "orders_suite"}],
    action_list=[
        {"name": "store_validation_result", "action": {"class_name": "StoreValidationResultAction"}},
        {"name": "send_slack_notification", "action": {
            "class_name": "SlackNotificationAction",
            "slack_webhook": "${SLACK_WEBHOOK}",
            "notify_on": "failure",
        }},
    ],
)
result = checkpoint.run()
print(f"Validation passed: {result.success}")
```

### 4. dbt Tests (SQL-Level Validation)
```yaml
# models/staging/_schema.yml
version: 2

models:
  - name: stg_orders
    columns:
      - name: order_id
        tests:
          - unique
          - not_null
          - dbt_utils.not_constant
      - name: amount
        tests:
          - not_null
          - dbt_utils.accepted_range:
              min_value: 0
              max_value: 1000000
      - name: status
        tests:
          - accepted_values:
              values: ['pending', 'confirmed', 'shipped', 'delivered', 'cancelled']
      - name: created_at
        tests:
          - not_null
          - dbt_expectations.expect_column_values_to_be_between:
              min_value: "'2020-01-01'"
              max_value: "current_date"

    # Table-level tests
    tests:
      - dbt_utils.unique_combination_of_columns:
          combination_of_columns: [order_id, created_at]
      - dbt_expectations.expect_table_row_count_to_be_between:
          min_value: 100
          max_value: 10000000
```

### 5. Anomaly Detection with Statistical Tests
```python
import numpy as np
from scipy import stats
from datetime import datetime, timedelta

def detect_volume_anomaly(
    daily_counts: list[tuple[str, int]],
    z_score_threshold: float = 3.0
) -> list[str]:
    """Flag days where volume is anomalous (>3 std devs from mean)."""
    dates = [d for d, _ in daily_counts]
    counts = np.array([c for _, c in daily_counts])
    
    mean, std = counts.mean(), counts.std()
    z_scores = np.abs((counts - mean) / std)
    
    anomalies = [dates[i] for i, z in enumerate(z_scores) if z > z_score_threshold]
    return anomalies

def detect_distribution_shift(
    baseline_sample: list[float],
    current_sample: list[float],
    p_value_threshold: float = 0.05,
) -> bool:
    """Returns True if distribution has significantly shifted (Kolmogorov-Smirnov test)."""
    statistic, p_value = stats.ks_2samp(baseline_sample, current_sample)
    return p_value < p_value_threshold

# Check for schema drift
def check_schema_drift(
    expected_columns: set[str],
    actual_columns: set[str],
) -> dict:
    return {
        "added": actual_columns - expected_columns,
        "removed": expected_columns - actual_columns,
        "is_drift": actual_columns != expected_columns,
    }
```

### 6. SQL Constraint Enforcement
```sql
-- Database-level guarantees (fail on insert, not silently)
CREATE TABLE orders (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    order_number TEXT NOT NULL UNIQUE,
    customer_id UUID NOT NULL REFERENCES customers(id),
    status TEXT NOT NULL CHECK (status IN ('pending', 'confirmed', 'shipped', 'delivered', 'cancelled')),
    amount DECIMAL(10,2) NOT NULL CHECK (amount > 0 AND amount <= 1000000),
    currency CHAR(3) NOT NULL CHECK (currency ~ '^[A-Z]{3}$'),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    shipped_at TIMESTAMPTZ,
    CONSTRAINT shipped_after_created CHECK (shipped_at IS NULL OR shipped_at >= created_at)
);

-- Monitor quality in SQL
SELECT
    COUNT(*) as total_orders,
    SUM(CASE WHEN customer_id IS NULL THEN 1 ELSE 0 END) as null_customers,
    SUM(CASE WHEN amount <= 0 THEN 1 ELSE 0 END) as invalid_amounts,
    MIN(amount) as min_amount,
    MAX(amount) as max_amount,
    AVG(amount) as avg_amount,
    COUNT(DISTINCT status) as distinct_statuses,
    MAX(created_at) as latest_order,
    MIN(created_at) as earliest_order
FROM orders
WHERE created_at >= CURRENT_DATE - INTERVAL '1 day';
```

## Key Commands Reference

```bash
# Great Expectations
great_expectations init
great_expectations suite new
great_expectations checkpoint run my_checkpoint

# Pandera
pip install pandera[hypotheses,pyspark,fastapi]
pandera validate --schema schema.py --data data.csv

# dbt tests
dbt test
dbt test --select source:orders  # Test only sources
dbt test --store-failures        # Store failing rows in DB

# Profile data quickly
pip install ydata-profiling
python -c "
import pandas as pd
from ydata_profiling import ProfileReport
df = pd.read_csv('orders.csv')
ProfileReport(df, title='Orders Profile').to_file('report.html')
"
```

## Common Patterns

### Pattern 1: Data Quality Score
```python
def compute_quality_score(df: pd.DataFrame, rules: list[dict]) -> float:
    """Returns 0.0-1.0 quality score based on weighted rules."""
    total_weight, passed_weight = 0, 0
    
    for rule in rules:
        weight = rule.get("weight", 1)
        total_weight += weight
        try:
            if rule["check"](df):
                passed_weight += weight
            else:
                print(f"FAILED: {rule['name']}")
        except Exception as e:
            print(f"ERROR in {rule['name']}: {e}")
    
    return passed_weight / total_weight if total_weight > 0 else 0

rules = [
    {"name": "No null order_ids", "weight": 10, "check": lambda df: df["order_id"].notna().all()},
    {"name": "Amount > 0", "weight": 8, "check": lambda df: (df["amount"] > 0).all()},
    {"name": "Valid status", "weight": 5, "check": lambda df: df["status"].isin(VALID_STATUSES).all()},
]
score = compute_quality_score(df, rules)
```

### Pattern 2: Alerting Integration
```python
def alert_on_failure(check_name: str, details: str, severity: str = "warning"):
    if severity == "critical":
        # Page on-call
        pagerduty.trigger_incident(summary=f"Data quality CRITICAL: {check_name}", body=details)
    else:
        slack.post_message("#data-quality-alerts",
            f":warning: Data quality {severity}: *{check_name}*\n{details}")
```

### Pattern 3: Incremental Quality Checks
```sql
-- Only check new data since last run (efficient for large tables)
INSERT INTO data_quality_log (check_name, run_at, passed, failed_count, sample_failures)
SELECT
    'null_order_ids' as check_name,
    NOW() as run_at,
    COUNT(*) FILTER (WHERE order_id IS NULL) = 0 as passed,
    COUNT(*) FILTER (WHERE order_id IS NULL) as failed_count,
    jsonb_agg(id ORDER BY created_at DESC) FILTER (WHERE order_id IS NULL) as sample_failures
FROM orders
WHERE created_at > (SELECT COALESCE(MAX(run_at), '1970-01-01') FROM data_quality_log WHERE check_name = 'null_order_ids');
```

## Pitfalls to Avoid

1. **Validating in production only**: Data quality checks should run at every pipeline stage — not just at the end. Catching a malformed record at ingestion is 100x cheaper than finding corrupted data in a production dashboard six months later.

2. **Hard failures without quarantine**: Failing the entire pipeline on one bad record blocks all good data. Implement a quarantine/dead-letter pattern: valid records continue, invalid records go to a review queue with full error context. Alert on quarantine volume, not individual records.

3. **Not tracking quality metrics over time**: A one-time validation check tells you if today's data is good. Tracking quality scores in a timeseries table lets you spot gradual degradation — a column slowly accumulating 0.1% nulls per day that becomes 10% in three months without triggering any single-run threshold.

## Related Skills

- `dbt-analytics` — dbt test framework for SQL transforms
- `kafka-event-streaming` — Validating events at stream ingestion
- `elasticsearch-search` — Logging quality failures for analysis
- `mlflow-experiment-tracking` — Tracking data quality metrics as ML experiment metadata

## GitNexus Index

```json
{
  "skill": "data-quality-validation",
  "category": "data-engineering",
  "triggers": ["data quality", "great expectations", "pandera", "data validation", "schema validation", "data drift", "anomaly detection data"],
  "outputs": ["validation schema", "quality checks", "dq report", "alert config"],
  "complexity": "medium",
  "tools": ["great-expectations", "pandera", "pydantic", "dbt-tests", "postgresql"]
}
```
