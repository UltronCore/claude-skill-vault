---
name: feature-store-engineering
description: Build and manage ML feature stores using Feast, Tecton, or custom implementations. Covers feature definitions, offline/online store sync, point-in-time joins for training, low-latency online serving, and feature monitoring.
version: 1.0.0
tags: [feature-store, feast, ml-infrastructure, mlops, feature-engineering, online-serving, point-in-time]
---

# Feature Store Engineering

## Overview

A feature store is the data layer for ML — it computes, stores, and serves features consistently between training and production. It solves training/serving skew by ensuring the same feature logic runs offline (batch for training data) and online (real-time for model serving). This skill covers Feast (open-source), custom PostgreSQL/Redis implementations, point-in-time correct joins, and feature monitoring.

## When to Use

- Multiple ML models share the same features (DRY principle for features)
- Training/serving skew is causing model degradation in production
- Need sub-millisecond feature retrieval for real-time predictions
- Building a platform where data scientists can register and discover features
- Historical feature retrieval for model training or backtesting

## Step-by-Step Workflow

### 1. Feast Feature Store Setup
```python
# feature_repo/feature_store.yaml
project: my_ml_platform
registry: data/registry.db
provider: local  # or aws, gcp

# For production:
# registry:
#   registry_type: sql
#   path: postgresql://user:pass@host/db
# online_store:
#   type: redis
#   connection_string: redis://localhost:6379
# offline_store:
#   type: bigquery
#   dataset: feast_offline

# feature_repo/entities.py
from feast import Entity, ValueType

user = Entity(
    name="user_id",
    value_type=ValueType.INT64,
    description="Unique user identifier",
    join_key="user_id",
)

product = Entity(
    name="product_id",
    value_type=ValueType.STRING,
    description="Product SKU",
    join_key="product_id",
)
```

### 2. Feature View Definitions
```python
from feast import FeatureView, Feature, FileSource, BigQuerySource, PushSource
from feast.types import Float32, Int64, String, Bool
from datetime import timedelta

# Offline source (batch)
user_activity_source = FileSource(
    path="data/user_activity.parquet",
    timestamp_field="event_timestamp",
    created_timestamp_column="created",
)

# Online push source (real-time updates)
user_push_source = PushSource(
    name="user_push_source",
    batch_source=user_activity_source,
)

# Feature view — defines what features exist and where they come from
user_features = FeatureView(
    name="user_features",
    entities=["user_id"],
    ttl=timedelta(days=7),  # Features expire after 7 days
    schema=[
        Feature(name="total_purchases_30d", dtype=Int64),
        Feature(name="avg_order_value_30d", dtype=Float32),
        Feature(name="days_since_last_purchase", dtype=Int64),
        Feature(name="preferred_category", dtype=String),
        Feature(name="is_premium", dtype=Bool),
        Feature(name="churn_risk_score", dtype=Float32),
    ],
    source=user_push_source,
    tags={"team": "growth", "model": "recommendation"},
)

# On-demand feature view — computed at request time (no storage)
from feast import RequestSource, OnDemandFeatureView
import pandas as pd

request_source = RequestSource(
    name="order_context",
    schema=[
        Feature(name="order_total", dtype=Float32),
        Feature(name="num_items", dtype=Int64),
    ],
)

@on_demand_feature_view(
    sources=[user_features, request_source],
    schema=[Feature(name="avg_item_price", dtype=Float32)],
)
def order_features(inputs: pd.DataFrame) -> pd.DataFrame:
    df = pd.DataFrame()
    df["avg_item_price"] = inputs["order_total"] / inputs["num_items"].clip(lower=1)
    return df
```

### 3. Feature Registry and Materialization
```bash
# Apply feature definitions to registry
feast apply

# Materialize features to online store (one-time backfill)
feast materialize-incremental $(date -u +"%Y-%m-%dT%H:%M:%S")

# Or materialize specific range
feast materialize 2024-01-01T00:00:00 2024-12-31T23:59:59

# Verify materialization
feast feature-views list
feast entities list
```

```python
from feast import FeatureStore

store = FeatureStore(repo_path="feature_repo/")

# Push real-time feature updates (streaming ingestion)
import pandas as pd

store.push(
    "user_push_source",
    pd.DataFrame({
        "user_id": [12345],
        "total_purchases_30d": [15],
        "avg_order_value_30d": [67.50],
        "days_since_last_purchase": [3],
        "preferred_category": ["electronics"],
        "is_premium": [True],
        "churn_risk_score": [0.12],
        "event_timestamp": [pd.Timestamp.now()],
    }),
    to=feast.PushMode.ONLINE_AND_OFFLINE,  # Update both stores
)
```

### 4. Training Data Generation (Point-in-Time Join)
```python
from feast import FeatureStore
import pandas as pd

store = FeatureStore(repo_path="feature_repo/")

# Entity DataFrame — the events you want features for
# CRITICAL: event_timestamp must be the exact time the prediction was made
# Feast retrieves features as they existed AT that timestamp (no data leakage)
entity_df = pd.DataFrame({
    "user_id": [1001, 1002, 1003, 1001, 1002],
    "event_timestamp": pd.to_datetime([
        "2024-01-15 10:00:00",
        "2024-01-15 10:05:00",
        "2024-01-15 10:10:00",
        "2024-01-16 09:00:00",  # user 1001 appears again, different time
        "2024-01-16 14:00:00",
    ]),
    "label": [1, 0, 1, 0, 1],  # Your training labels
})

# Point-in-time correct feature retrieval for training
training_df = store.get_historical_features(
    entity_df=entity_df,
    features=[
        "user_features:total_purchases_30d",
        "user_features:avg_order_value_30d",
        "user_features:days_since_last_purchase",
        "user_features:is_premium",
        "user_features:churn_risk_score",
    ],
).to_df()

# training_df now has features as they existed at each event_timestamp
# No future data leakage — features after the timestamp are excluded
print(training_df.head())

# Save for model training
training_df.to_parquet("data/training_features.parquet")
```

### 5. Online Feature Serving (Real-Time Inference)
```python
from feast import FeatureStore
from fastapi import FastAPI
import uvicorn

store = FeatureStore(repo_path="feature_repo/")
app = FastAPI()

@app.post("/predict")
async def predict(user_id: int, order_total: float, num_items: int):
    # Retrieve features from online store (<5ms with Redis)
    feature_vector = store.get_online_features(
        features=[
            "user_features:total_purchases_30d",
            "user_features:avg_order_value_30d",
            "user_features:days_since_last_purchase",
            "user_features:is_premium",
            "user_features:churn_risk_score",
        ],
        entity_rows=[{"user_id": user_id}],
    ).to_dict()
    
    # Combine with request-time context
    features = {
        "total_purchases_30d": feature_vector["total_purchases_30d"][0],
        "avg_order_value_30d": feature_vector["avg_order_value_30d"][0],
        "days_since_last_purchase": feature_vector["days_since_last_purchase"][0],
        "is_premium": feature_vector["is_premium"][0],
        "churn_risk_score": feature_vector["churn_risk_score"][0],
        "order_total": order_total,
        "num_items": num_items,
    }
    
    # Run model inference
    prediction = model.predict([list(features.values())])
    return {"user_id": user_id, "prediction": prediction[0], "features": features}
```

### 6. Custom Feature Store (Without Feast)
```python
import redis
import psycopg2
import pandas as pd
from datetime import datetime
import json

class SimpleFeatureStore:
    """Minimal feature store: PostgreSQL offline + Redis online."""
    
    def __init__(self, pg_dsn: str, redis_url: str):
        self.pg_dsn = pg_dsn
        self.redis = redis.from_url(redis_url, decode_responses=True)
    
    def materialize(self, query: str, feature_view: str, entity_key: str, ttl_seconds: int = 86400):
        """Compute features from SQL and push to Redis."""
        conn = psycopg2.connect(self.pg_dsn)
        df = pd.read_sql(query, conn)
        
        pipe = self.redis.pipeline(transaction=False)
        for _, row in df.iterrows():
            key = f"{feature_view}:{row[entity_key]}"
            features = {k: str(v) for k, v in row.items() if k != entity_key}
            pipe.hset(key, mapping=features)
            pipe.expire(key, ttl_seconds)
        pipe.execute()
        conn.close()
        print(f"Materialized {len(df)} entities to {feature_view}")
    
    def get_online_features(self, feature_view: str, entity_ids: list[int]) -> dict:
        """Retrieve features from Redis."""
        pipe = self.redis.pipeline(transaction=False)
        for entity_id in entity_ids:
            pipe.hgetall(f"{feature_view}:{entity_id}")
        results = pipe.execute()
        return {eid: feats for eid, feats in zip(entity_ids, results)}
    
    def get_historical_features(self, entity_df: pd.DataFrame, feature_sql: str) -> pd.DataFrame:
        """Point-in-time join from PostgreSQL."""
        # entity_df must have entity_id and event_timestamp columns
        conn = psycopg2.connect(self.pg_dsn)
        entity_df.to_sql("_temp_entities", conn, if_exists="replace", index=False)
        result = pd.read_sql(feature_sql, conn)  # SQL does the point-in-time join
        conn.close()
        return result

# Usage
store = SimpleFeatureStore(
    pg_dsn="postgresql://user:pass@localhost/mldb",
    redis_url="redis://localhost:6379",
)

# Materialize user features (run on schedule or trigger)
store.materialize(
    query="""
    SELECT user_id,
           COUNT(*) FILTER (WHERE created_at > NOW() - INTERVAL '30 days') AS purchases_30d,
           AVG(order_value) FILTER (WHERE created_at > NOW() - INTERVAL '30 days') AS avg_order_30d
    FROM orders GROUP BY user_id
    """,
    feature_view="user_features",
    entity_key="user_id",
    ttl_seconds=3600,  # 1 hour TTL
)

# Serve features
features = store.get_online_features("user_features", [1001, 1002, 1003])
```

## Key Commands Reference

```bash
# Feast CLI
pip install feast[redis,postgres]

feast init my_feature_repo
cd my_feature_repo

feast apply              # Register feature definitions
feast feature-views list # List all feature views
feast entities list      # List all entities

# Materialize batch to online store
feast materialize-incremental $(date -u +"%Y-%m-%dT%H:%M:%S")

# Feast UI (visual exploration)
feast ui

# Check materialization status
feast materialize-status

# Validate feature data
feast validate my_dataset --feature-service my_service

# Registry operations
feast registry-dump         # Inspect registry contents
```

## Common Patterns

### Pattern 1: Feature Pipeline with dbt + Feast
```yaml
# dbt model: models/features/user_activity_features.sql
# Computes features in the warehouse, Feast reads the resulting table

SELECT
    user_id,
    COUNT(*) FILTER (WHERE event_date >= CURRENT_DATE - 30) AS events_30d,
    COUNT(DISTINCT session_id) AS sessions_30d,
    MAX(event_date) AS last_active_date,
    CURRENT_TIMESTAMP AS event_timestamp,
    CURRENT_TIMESTAMP AS created
FROM {{ ref('stg_events') }}
GROUP BY user_id
```

```python
# feature_repo/features.py — Feast reads the dbt table
user_activity_source = BigQuerySource(
    table="my_project.dbt_features.user_activity_features",
    timestamp_field="event_timestamp",
)
```

### Pattern 2: Feature Monitoring
```python
from feast import FeatureStore
import pandas as pd
from scipy import stats

def detect_feature_drift(store, feature_view, entity_ids, baseline_df):
    """Alert if online features drift significantly from baseline."""
    online = store.get_online_features(
        features=[f"{feature_view}:total_purchases_30d"],
        entity_rows=[{"user_id": uid} for uid in entity_ids],
    ).to_df()
    
    ks_stat, p_value = stats.ks_2samp(
        baseline_df["total_purchases_30d"].dropna(),
        online["user_features__total_purchases_30d"].dropna(),
    )
    
    if p_value < 0.05:
        alert(f"Feature drift detected in {feature_view}: KS={ks_stat:.3f}, p={p_value:.4f}")
    
    return {"ks_statistic": ks_stat, "p_value": p_value, "drifted": p_value < 0.05}
```

### Pattern 3: Feature Freshness Check
```python
def check_feature_freshness(store, feature_view: str, max_age_hours: int = 24):
    """Verify features were recently materialized before serving."""
    from feast.feast_object import FeastObject
    import arrow
    
    meta = store.get_feature_view(feature_view)
    last_updated = meta.materialization_intervals[-1].end_time if meta.materialization_intervals else None
    
    if last_updated is None:
        raise RuntimeError(f"{feature_view} has never been materialized")
    
    age_hours = (datetime.utcnow() - last_updated).total_seconds() / 3600
    if age_hours > max_age_hours:
        raise RuntimeError(f"{feature_view} is stale: {age_hours:.1f}h old (max: {max_age_hours}h)")
    
    return True
```

## Pitfalls to Avoid

1. **Training/serving skew from inconsistent feature logic**: The cardinal sin of feature stores. If you compute `avg_order_value` differently in your training SQL vs your real-time code, your model degrades silently. Always route both training (historical) and serving (online) through the same feature view definition — that's the entire point of a feature store.

2. **Missing entity rows in the online store**: `get_online_features()` returns `None` for entities never materialized. Always handle nulls in your serving code — fill with defaults or fallback features, never fail the prediction request. Check `store.get_online_features(...).to_dict()` and handle the `None` case explicitly.

3. **Over-materializing expensive aggregations**: Materializing window functions (30d, 90d, 1y) over billions of events every hour is extremely expensive. Use incremental aggregation: maintain running totals in a streaming layer (Kafka + Flink), push deltas to the online store, and only recompute full windows nightly in the batch layer.

## Related Skills

- `mlflow-experiment-tracking` — Track experiments that use features from the store
- `kafka-event-streaming` — Stream feature updates to the online store
- `dbt-analytics` — Compute offline features with dbt, serve via Feast
- `ray-distributed-computing` — Distributed feature computation with Ray Data

## GitNexus Index

```json
{
  "skill": "feature-store-engineering",
  "category": "data-engineering",
  "triggers": ["feature store", "feast", "feature engineering ml", "training serving skew", "online features", "point-in-time join", "feature materialization"],
  "outputs": ["feature view", "entity definition", "materialization script", "online serving endpoint", "training dataset"],
  "complexity": "high",
  "tools": ["feast", "redis", "postgresql", "bigquery", "kafka", "dbt"]
}
```
