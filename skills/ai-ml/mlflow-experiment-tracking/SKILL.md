---
name: mlflow-experiment-tracking
description: Track ML experiments, manage model versions, and deploy models using MLflow. Covers experiment logging, model registry, artifact management, and serving patterns.
version: 1.0.0
tags: [mlflow, mlops, experiment-tracking, model-registry, ml-deployment, machine-learning]
---

# MLflow Experiment Tracking

## Overview

This skill covers MLflow for the complete ML experiment lifecycle: tracking runs with parameters and metrics, comparing experiments, managing model versions in the registry, and deploying models via MLflow serving. It integrates with PyTorch, scikit-learn, XGBoost, HuggingFace, and any custom Python model through the pyfunc interface.

## When to Use

- Needing to compare multiple model runs (hyperparameters, architectures, datasets)
- Setting up a model registry with staging/production promotion workflows
- Reproducing a previous model run from six months ago
- Deploying a model as a REST API or batch scorer
- Organizing team ML work so experiments are searchable and auditable

## Step-by-Step Workflow

### 1. Setup MLflow Tracking Server
```bash
# Local (file-based, development)
mlflow ui --port 5000

# Production: PostgreSQL backend + S3 artifact store
pip install mlflow psycopg2-binary boto3

mlflow server \
  --backend-store-uri postgresql://user:pass@localhost/mlflow \
  --default-artifact-root s3://my-mlflow-bucket/artifacts \
  --host 0.0.0.0 \
  --port 5000

# Docker Compose for local team setup
# See: https://github.com/mlflow/mlflow/tree/master/examples/docker
```

### 2. Track an Experiment Run
```python
import mlflow
import mlflow.sklearn
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score, f1_score

mlflow.set_tracking_uri("http://localhost:5000")
mlflow.set_experiment("customer-churn-prediction")

with mlflow.start_run(run_name="rf-baseline-v1"):
    # Log parameters
    params = {
        "n_estimators": 100,
        "max_depth": 10,
        "min_samples_split": 5,
        "random_state": 42,
    }
    mlflow.log_params(params)
    
    # Log dataset info
    mlflow.log_param("dataset_version", "2024-01-15")
    mlflow.log_param("train_size", len(X_train))
    
    # Train model
    model = RandomForestClassifier(**{k: v for k, v in params.items()})
    model.fit(X_train, y_train)
    
    # Log metrics
    y_pred = model.predict(X_test)
    mlflow.log_metrics({
        "accuracy": accuracy_score(y_test, y_pred),
        "f1_score": f1_score(y_test, y_pred),
        "train_accuracy": accuracy_score(y_train, model.predict(X_train)),
    })
    
    # Log model with signature
    from mlflow.models.signature import infer_signature
    signature = infer_signature(X_train, model.predict(X_train))
    mlflow.sklearn.log_model(
        model, 
        "random-forest-model",
        signature=signature,
        registered_model_name="ChurnPredictor",
        input_example=X_train[:5],
    )
    
    # Log artifacts
    import matplotlib.pyplot as plt
    from sklearn.inspection import permutation_importance
    fig, ax = plt.subplots(figsize=(10, 6))
    # ... feature importance plot ...
    mlflow.log_figure(fig, "feature_importance.png")
    mlflow.log_artifact("data/feature_config.yaml")
    
    print(f"Run ID: {mlflow.active_run().info.run_id}")
```

### 3. Hyperparameter Tuning with Optuna + MLflow
```python
import optuna

def objective(trial):
    params = {
        "n_estimators": trial.suggest_int("n_estimators", 50, 300),
        "max_depth": trial.suggest_int("max_depth", 3, 15),
        "learning_rate": trial.suggest_float("learning_rate", 1e-4, 0.3, log=True),
    }
    
    with mlflow.start_run(nested=True):
        mlflow.log_params(params)
        model = XGBClassifier(**params)
        model.fit(X_train, y_train, eval_set=[(X_val, y_val)], verbose=False)
        score = f1_score(y_val, model.predict(X_val))
        mlflow.log_metric("val_f1", score)
        return score

with mlflow.start_run(run_name="optuna-hyperparam-search"):
    study = optuna.create_study(direction="maximize")
    study.optimize(objective, n_trials=50, n_jobs=4)
    
    mlflow.log_params(study.best_params)
    mlflow.log_metric("best_val_f1", study.best_value)
```

### 4. Model Registry Workflow
```python
from mlflow.tracking import MlflowClient

client = MlflowClient()

# Transition model version to staging
client.transition_model_version_stage(
    name="ChurnPredictor",
    version="3",
    stage="Staging",
    archive_existing_versions=False,
)

# Add description and tags
client.update_model_version(
    name="ChurnPredictor",
    version="3",
    description="RF with balanced class weights, trained on Q1 2024 data",
)
client.set_model_version_tag("ChurnPredictor", "3", "validated_by", "data-science-team")

# Promote to Production
client.transition_model_version_stage(
    name="ChurnPredictor",
    version="3",
    stage="Production",
    archive_existing_versions=True,  # Archives previous Production version
)
```

### 5. Load and Serve a Model
```python
# Load from registry
import mlflow.pyfunc

model = mlflow.pyfunc.load_model("models:/ChurnPredictor/Production")
predictions = model.predict(X_new)

# Or by run ID
model = mlflow.sklearn.load_model(f"runs:/{run_id}/random-forest-model")
```

```bash
# Serve as REST API
mlflow models serve \
  --model-uri models:/ChurnPredictor/Production \
  --port 8080 \
  --no-conda

# Test the endpoint
curl -X POST http://localhost:8080/invocations \
  -H "Content-Type: application/json" \
  -d '{"dataframe_records": [{"feature1": 0.5, "feature2": 1.2}]}'

# Build Docker image for deployment
mlflow models build-docker \
  --model-uri models:/ChurnPredictor/Production \
  --name churn-predictor:v3
```

## Key Commands Reference

```bash
# List experiments
mlflow experiments list

# Search runs
mlflow runs list --experiment-id 1 --filter "metrics.accuracy > 0.9"

# Download artifacts
mlflow artifacts download --run-id <run-id> --artifact-path model/

# Compare runs in UI
mlflow ui  # Go to Experiments → select runs → Compare

# Delete old runs
mlflow gc --backend-store-uri postgresql://...  # Garbage collect deleted runs

# Export/import runs
mlflow experiments export --experiment-id 1 --output-dir ./export
mlflow experiments import --input-dir ./export
```

## Common Patterns

### Pattern 1: Custom pyfunc Model (Preprocessing + Model Pipeline)
```python
class ChurnModel(mlflow.pyfunc.PythonModel):
    def load_context(self, context):
        import pickle
        with open(context.artifacts["preprocessor"], "rb") as f:
            self.preprocessor = pickle.load(f)
        self.model = mlflow.sklearn.load_model(context.artifacts["model"])
    
    def predict(self, context, model_input):
        processed = self.preprocessor.transform(model_input)
        return self.model.predict_proba(processed)[:, 1]

# Log with artifacts
artifacts = {
    "preprocessor": "/tmp/preprocessor.pkl",
    "model": f"runs:/{run_id}/model"
}
mlflow.pyfunc.log_model("churn_pipeline", python_model=ChurnModel(), artifacts=artifacts)
```

### Pattern 2: Callback for Deep Learning (PyTorch)
```python
from mlflow.pytorch import autolog

mlflow.pytorch.autolog(log_every_n_epoch=5, log_models=True)

with mlflow.start_run():
    trainer.fit(model, train_dataloader, val_dataloader)
    # Params, metrics, and model logged automatically
```

### Pattern 3: A/B Model Comparison Query
```python
runs = client.search_runs(
    experiment_ids=["1"],
    filter_string="metrics.val_f1 > 0.85 and params.model_type = 'xgboost'",
    order_by=["metrics.val_f1 DESC"],
    max_results=10
)
for run in runs:
    print(f"{run.info.run_id}: {run.data.metrics['val_f1']:.4f}")
```

## Pitfalls to Avoid

1. **Logging inside tight loops**: Calling `mlflow.log_metric()` on every batch of training creates thousands of HTTP requests. Batch metric logging: accumulate metrics in a dict and log every N steps with `mlflow.log_metrics(metrics_dict, step=epoch)`.

2. **Not setting a run name**: Default run names are random adjective-noun combos. Always set `run_name` or use tags: `mlflow.set_tag("model_type", "xgboost")`. Without this, searching 500 runs three months later is painful.

3. **Storing large artifacts as metrics**: Log only scalar metrics to the tracking backend. Confusion matrices, model weights, and dataset samples go as artifacts via `log_artifact` or `log_figure`. Large artifact stores should use S3/GCS, not the local filesystem.

## Related Skills

- `mlops-engineer` — Full MLOps pipeline design
- `ray-distributed-computing` — Distributed hyperparameter search with Ray Tune + MLflow
- `huggingface-llm-trainer` — HuggingFace training with MLflow callbacks
- `data-quality-validation` — Validating training data before experiments

## GitNexus Index

```json
{
  "skill": "mlflow-experiment-tracking",
  "category": "ai-ml",
  "triggers": ["mlflow", "experiment tracking", "model registry", "ml tracking", "model versioning", "mlops tracking"],
  "outputs": ["experiment runs", "model artifacts", "registry entry", "serving endpoint"],
  "complexity": "medium",
  "tools": ["mlflow", "optuna", "sklearn", "pytorch", "xgboost"]
}
```
