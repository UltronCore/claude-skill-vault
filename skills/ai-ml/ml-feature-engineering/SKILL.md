---
name: ml-feature-engineering
description: Design and implement ML feature engineering pipelines — numerical and categorical encoding, text/embedding features, temporal features, feature selection with mutual information and SHAP, scikit-learn pipelines, and feature store serving for training/inference consistency.
version: 1.0.0
tags: [machine-learning, feature-engineering, scikit-learn, pandas, feature-store, embeddings, preprocessing, python]
---

# ML Feature Engineering

## Overview

Feature engineering is the process of transforming raw data into representations that machine learning models can learn from effectively. It accounts for the majority of the performance difference between a mediocre and a high-performing model. The critical challenge is training/serving skew — the same transformations applied at training time must be applied identically at inference time, using parameters (mean, std, vocabularies) computed from training data only, never from test or production data. Scikit-learn Pipelines enforce this contract by design.

## When to Use

- Building ML models that need more than raw features (tabular data, text, time-series)
- Debugging why a deployed model performs worse than offline evaluation (training/serving skew)
- Selecting which features actually matter before scaling compute on training
- Adding temporal/interaction features to improve model performance on structured data
- Setting up a feature store to share features across multiple models and teams
- Preparing features from raw events for real-time inference with low latency

## Step-by-Step Workflow

### 1. Numerical and Categorical Feature Preprocessing

```python
# src/ml/preprocessing_pipeline.py
import pandas as pd
import numpy as np
from sklearn.pipeline import Pipeline
from sklearn.compose import ColumnTransformer
from sklearn.preprocessing import (
    StandardScaler, MinMaxScaler, RobustScaler,
    OneHotEncoder, OrdinalEncoder, TargetEncoder,
)
from sklearn.impute import SimpleImputer, KNNImputer
from sklearn.base import BaseEstimator, TransformerMixin

# Define feature groups
NUMERIC_FEATURES = ["age", "income", "session_duration_sec", "days_since_signup"]
CATEGORICAL_FEATURES = ["country", "device_type", "plan"]
HIGH_CARDINALITY_FEATURES = ["product_id", "user_segment"]  # Use target encoding

# Numerical pipeline: impute → scale
numeric_pipeline = Pipeline([
    ("imputer", SimpleImputer(strategy="median")),  # median is robust to outliers
    ("scaler", RobustScaler()),    # robust to outliers vs StandardScaler
])

# Low-cardinality categorical: impute → one-hot encode
categorical_pipeline = Pipeline([
    ("imputer", SimpleImputer(strategy="most_frequent")),
    ("encoder", OneHotEncoder(
        handle_unknown="ignore",    # Unknown categories at inference → all zeros
        sparse_output=False,        # Dense array (easier to work with)
        drop="first",               # Drop first category to avoid multicollinearity
    )),
])

# High-cardinality categorical: target encoding (leakage-safe via cross-fitting)
target_pipeline = Pipeline([
    ("imputer", SimpleImputer(strategy="most_frequent")),
    ("encoder", TargetEncoder(
        target_type="binary",
        smooth="auto",              # Bayesian smoothing for rare categories
    )),
])

# Combine into one ColumnTransformer
preprocessor = ColumnTransformer([
    ("numeric", numeric_pipeline, NUMERIC_FEATURES),
    ("categorical", categorical_pipeline, CATEGORICAL_FEATURES),
    ("target_enc", target_pipeline, HIGH_CARDINALITY_FEATURES),
], remainder="drop")


# Full model pipeline — fit on train, transform train and test
from sklearn.ensemble import GradientBoostingClassifier
full_pipeline = Pipeline([
    ("preprocessor", preprocessor),
    ("model", GradientBoostingClassifier(n_estimators=200, max_depth=4)),
])

# This single fit() call: fits preprocessor on X_train, then trains model
full_pipeline.fit(X_train, y_train)

# Inference: identical transformations, no data leakage possible
predictions = full_pipeline.predict(X_test)
```

### 2. Custom Feature Transformers

```python
# src/ml/custom_transformers.py
import pandas as pd
import numpy as np
from sklearn.base import BaseEstimator, TransformerMixin

class TemporalFeatureExtractor(BaseEstimator, TransformerMixin):
    """Extract temporal features from datetime columns."""

    def __init__(self, date_column: str):
        self.date_column = date_column

    def fit(self, X, y=None):
        return self  # No fitting needed for deterministic extraction

    def transform(self, X: pd.DataFrame) -> pd.DataFrame:
        X = X.copy()
        dt = pd.to_datetime(X[self.date_column])

        X["hour_of_day"] = dt.dt.hour
        X["day_of_week"] = dt.dt.dayofweek          # 0=Monday, 6=Sunday
        X["is_weekend"] = dt.dt.dayofweek.isin([5, 6]).astype(int)
        X["month"] = dt.dt.month
        X["quarter"] = dt.dt.quarter
        X["days_since_epoch"] = (dt - pd.Timestamp("1970-01-01")).dt.days

        # Cyclical encoding: prevents the model treating hour 23 as far from hour 0
        X["hour_sin"] = np.sin(2 * np.pi * X["hour_of_day"] / 24)
        X["hour_cos"] = np.cos(2 * np.pi * X["hour_of_day"] / 24)
        X["dow_sin"] = np.sin(2 * np.pi * X["day_of_week"] / 7)
        X["dow_cos"] = np.cos(2 * np.pi * X["day_of_week"] / 7)

        return X.drop(columns=[self.date_column])


class LogTransformer(BaseEstimator, TransformerMixin):
    """Log1p transform for right-skewed features (revenue, counts)."""

    def __init__(self, columns: list[str]):
        self.columns = columns

    def fit(self, X, y=None):
        return self

    def transform(self, X: pd.DataFrame) -> pd.DataFrame:
        X = X.copy()
        for col in self.columns:
            X[f"{col}_log"] = np.log1p(X[col].clip(lower=0))
        return X


class RatioFeatureCreator(BaseEstimator, TransformerMixin):
    """Create ratio features from pairs of columns."""

    def __init__(self, pairs: list[tuple[str, str]], epsilon: float = 1e-8):
        self.pairs = pairs
        self.epsilon = epsilon

    def fit(self, X, y=None):
        return self

    def transform(self, X: pd.DataFrame) -> pd.DataFrame:
        X = X.copy()
        for num_col, denom_col in self.pairs:
            X[f"{num_col}_per_{denom_col}"] = (
                X[num_col] / (X[denom_col] + self.epsilon)
            )
        return X
```

### 3. Feature Selection

```python
# src/ml/feature_selection.py
import pandas as pd
import numpy as np
from sklearn.feature_selection import (
    SelectKBest, mutual_info_classif, mutual_info_regression,
    RFECV, VarianceThreshold,
)
import shap

def select_features_mutual_info(
    X_train: pd.DataFrame,
    y_train: pd.Series,
    task: str = "classification",  # or "regression"
    top_k: int = 20,
) -> list[str]:
    """
    Select top K features by mutual information.
    Non-parametric: works for nonlinear relationships.
    """
    mi_func = mutual_info_classif if task == "classification" else mutual_info_regression
    mi_scores = mi_func(X_train, y_train, random_state=42)

    feature_scores = pd.Series(mi_scores, index=X_train.columns)
    return feature_scores.nlargest(top_k).index.tolist()


def select_features_shap(
    model,
    X_train: pd.DataFrame,
    threshold: float = 0.01,  # Keep features with mean |SHAP| > 1% of max
) -> list[str]:
    """
    Select features by SHAP importance — accounts for feature interactions.
    Use after training a tree-based model (XGBoost, LightGBM, RandomForest).
    """
    explainer = shap.TreeExplainer(model)
    shap_values = explainer.shap_values(X_train)

    if isinstance(shap_values, list):
        shap_values = np.abs(shap_values).mean(axis=0)  # Multi-class: average

    mean_shap = pd.Series(
        np.abs(shap_values).mean(axis=0),
        index=X_train.columns,
    ).sort_values(ascending=False)

    cutoff = mean_shap.max() * threshold
    selected = mean_shap[mean_shap > cutoff].index.tolist()

    print(f"Selected {len(selected)}/{len(X_train.columns)} features")
    print(mean_shap.head(10).to_string())
    return selected


def remove_low_variance(X: pd.DataFrame, threshold: float = 0.01) -> pd.DataFrame:
    """Drop features with near-zero variance (carry no information)."""
    selector = VarianceThreshold(threshold=threshold)
    selector.fit(X)
    kept = X.columns[selector.get_support()].tolist()
    dropped = set(X.columns) - set(kept)
    if dropped:
        print(f"Dropped low-variance features: {dropped}")
    return X[kept]
```

## Key Commands Reference

```bash
# Install core feature engineering packages
pip install scikit-learn pandas numpy shap category-encoders feature-engine

# Feature engineering for NLP
pip install sentence-transformers spacy
python -m spacy download en_core_web_sm

# Inspect pipeline feature names after fit
pipeline.named_steps['preprocessor'].get_feature_names_out()

# Persist pipeline (preserves fitted scalers, vocabularies, etc.)
import joblib
joblib.dump(full_pipeline, "models/pipeline_v1.pkl")
pipeline = joblib.load("models/pipeline_v1.pkl")

# Feature correlation heatmap
import seaborn as sns
import matplotlib.pyplot as plt
corr = X_train.corr()
sns.heatmap(corr, center=0, cmap="RdBu_r", annot=False)
plt.savefig("feature_correlation.png", dpi=150)

# SHAP summary plot
shap.summary_plot(shap_values, X_train, plot_type="bar")
```

## Common Patterns

### Pattern 1: Text and Embedding Features

```python
# src/ml/text_features.py
from sklearn.base import BaseEstimator, TransformerMixin
from sentence_transformers import SentenceTransformer
import numpy as np

class SentenceEmbeddingTransformer(BaseEstimator, TransformerMixin):
    """
    Convert text column to sentence embeddings.
    Use within a ColumnTransformer for text features.
    """

    def __init__(self, model_name: str = "all-MiniLM-L6-v2", batch_size: int = 64):
        self.model_name = model_name
        self.batch_size = batch_size

    def fit(self, X, y=None):
        self.model_ = SentenceTransformer(self.model_name)
        return self

    def transform(self, X) -> np.ndarray:
        texts = X.tolist() if hasattr(X, "tolist") else list(X)
        return self.model_.encode(
            texts,
            batch_size=self.batch_size,
            show_progress_bar=True,
            normalize_embeddings=True,    # Unit norm for cosine similarity
        )


# Combine structured + text features
from sklearn.compose import ColumnTransformer
combined_preprocessor = ColumnTransformer([
    ("structured", preprocessor, NUMERIC_FEATURES + CATEGORICAL_FEATURES),
    ("text_embedding", SentenceEmbeddingTransformer(), "description_column"),
])
```

### Pattern 2: Lagged and Rolling Window Features (Time Series)

```python
def create_time_series_features(
    df: pd.DataFrame,
    target_col: str,
    group_col: str,           # e.g., user_id, store_id
    lags: list[int] = [1, 7, 14, 28],
    rolling_windows: list[int] = [7, 30],
) -> pd.DataFrame:
    """
    Create lag and rolling statistics as features.
    Sort by time before calling. Never use future data.
    """
    df = df.sort_values([group_col, "timestamp"])

    for lag in lags:
        df[f"{target_col}_lag_{lag}"] = (
            df.groupby(group_col)[target_col].shift(lag)
        )

    for window in rolling_windows:
        rolled = df.groupby(group_col)[target_col].shift(1).rolling(window)
        df[f"{target_col}_rolling_mean_{window}d"] = rolled.mean().values
        df[f"{target_col}_rolling_std_{window}d"] = rolled.std().values
        df[f"{target_col}_rolling_max_{window}d"] = rolled.max().values

    return df
```

### Pattern 3: Online Feature Serving with Redis

```python
# src/ml/feature_store_client.py
# Pre-compute features offline, serve in real-time from Redis
import redis
import json
import numpy as np

class OnlineFeatureStore:
    """
    Serve pre-computed features for real-time inference.
    Features computed offline (Spark/pandas) and stored in Redis.
    """

    def __init__(self, redis_url: str = "redis://localhost:6379"):
        self.client = redis.from_url(redis_url, decode_responses=True)

    def write_user_features(self, user_id: str, features: dict, ttl: int = 86400):
        key = f"features:user:{user_id}"
        self.client.set(key, json.dumps(features), ex=ttl)

    def get_user_features(self, user_id: str) -> dict | None:
        key = f"features:user:{user_id}"
        data = self.client.get(key)
        return json.loads(data) if data else None

    def get_batch_features(self, user_ids: list[str]) -> dict[str, dict]:
        pipe = self.client.pipeline()
        for uid in user_ids:
            pipe.get(f"features:user:{uid}")
        results = pipe.execute()
        return {
            uid: json.loads(val) if val else {}
            for uid, val in zip(user_ids, results)
        }
```

## Pitfalls to Avoid

1. **Data leakage via target encoding computed on the full dataset**: If you compute target-encoding statistics (mean target per category) using both train and test data, your model learns from the test labels — causing optimistic offline metrics that collapse in production. Always use scikit-learn's `TargetEncoder` inside a `Pipeline`, which automatically applies cross-fitting during `fit()` to prevent leakage. For time-series data, additionally ensure encodings only use data prior to the current timestamp.

2. **Fitting scalers and encoders on test data**: Calling `scaler.fit_transform(X_test)` recomputes the mean and standard deviation on test data. At inference time, you must use the mean/std from training data — otherwise values won't be on the same scale. Use `Pipeline` to ensure `fit()` only touches training data and `transform()` applies the training-time parameters to any new data.

3. **Creating features from the future in time-series tasks**: Lag features must use `shift(1)` or more — using `shift(0)` includes the current row's value, which is the target you're predicting. Rolling windows must also be applied after shifting. Always plot a few rows of your feature matrix and verify that no row contains information from timestamps after the row's own timestamp.

## Related Skills

- `feature-store-engineering` — Building and operating feature stores (Feast, Hopsworks)
- `data-pipeline-engineer` — Data pipeline construction for feature computation
- `mlops-engineer` — Model and pipeline deployment
- `embedding-pipeline` — Generating and managing embedding features at scale
- `data-versioning-dvc` — Versioning feature datasets with DVC

## GitNexus Index

```json
{
  "skill": "ml-feature-engineering",
  "category": "ml",
  "triggers": ["feature engineering", "ML preprocessing", "sklearn pipeline", "feature selection", "SHAP importance", "target encoding", "one-hot encoding", "temporal features", "lag features", "training serving skew", "feature store serving"],
  "outputs": ["ColumnTransformer", "Pipeline", "TemporalFeatureExtractor", "LogTransformer", "SentenceEmbeddingTransformer", "select_features_shap()", "create_time_series_features()", "OnlineFeatureStore"],
  "complexity": "high",
  "tools": ["python", "scikit-learn", "pandas", "numpy", "shap", "category-encoders", "sentence-transformers", "redis"]
}
```
