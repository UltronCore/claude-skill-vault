---
name: ray-distributed-computing
description: Build and scale distributed Python applications with Ray. Covers remote functions, actors, object store, Ray Data for parallel data processing, Ray Serve for model serving, and Ray Train for distributed ML training.
version: 1.0.0
tags: [ray, distributed-computing, parallel-processing, ml-serving, ray-serve, ray-train, python]
---

# Ray Distributed Computing

## Overview

Ray is a distributed execution framework that scales Python code from a laptop to a cluster with minimal changes. It provides remote functions for task parallelism, actors for stateful distributed objects, Ray Data for large-scale data processing, Ray Serve for model serving, and Ray Train for distributed ML training. Ray replaces Celery, Dask, and custom multiprocessing for most Python parallel workloads.

## When to Use

- Parallelizing CPU-bound Python work across cores or machines (data processing, simulations)
- Serving ML models with high throughput and autoscaling
- Distributed hyperparameter tuning across GPU nodes
- Building stateful distributed services (game servers, streaming pipelines)
- Replacing Celery/Dask for Python-native parallel workflows

## Step-by-Step Workflow

### 1. Ray Core — Remote Functions and Actors
```python
import ray
import time
from typing import List

# Initialize Ray (auto-detects local cores, or connect to cluster)
ray.init()  # Local
# ray.init(address="ray://head-node:10001")  # Remote cluster

# Remote function — executes in parallel across workers
@ray.remote
def process_record(record: dict) -> dict:
    """CPU-bound processing that runs in separate process."""
    time.sleep(0.1)  # Simulate work
    return {
        "id": record["id"],
        "result": record["value"] ** 2,
        "processed": True,
    }

# Fan-out: submit all tasks immediately, collect results later
records = [{"id": i, "value": i} for i in range(1000)]
futures = [process_record.remote(r) for r in records]

# Block and collect — or use ray.wait() for streaming results
results = ray.get(futures)  # Blocks until all complete
print(f"Processed {len(results)} records")

# Streaming results as they complete
ready, remaining = ray.wait(futures, num_returns=10, timeout=5.0)
batch = ray.get(ready)


# Actor — stateful object running in its own process
@ray.remote
class Counter:
    def __init__(self, name: str):
        self.name = name
        self.count = 0
        self.history: List[int] = []
    
    def increment(self, amount: int = 1) -> int:
        self.count += amount
        self.history.append(self.count)
        return self.count
    
    def get_stats(self) -> dict:
        return {
            "name": self.name,
            "count": self.count,
            "history_len": len(self.history),
        }

# Create actor — runs in its own process, persists across calls
counter = Counter.remote("events")
ray.get(counter.increment.remote(5))
ray.get(counter.increment.remote(3))
stats = ray.get(counter.get_stats.remote())
print(stats)  # {"name": "events", "count": 8, "history_len": 2}

# Named actor — find from anywhere in the cluster
counter2 = Counter.options(name="global-counter", lifetime="detached").remote("global")
found = ray.get_actor("global-counter")
```

### 2. Ray Data — Parallel Data Processing
```python
import ray
import ray.data

# Create dataset from various sources
ds = ray.data.read_parquet("s3://my-bucket/data/*.parquet")
ds = ray.data.read_csv("/data/records.csv")
ds = ray.data.from_pandas(df)
ds = ray.data.range(1_000_000)  # Synthetic dataset

# Map — apply function to each row (parallelized automatically)
def normalize_record(row: dict) -> dict:
    row["score"] = (row["score"] - 50) / 50.0
    row["category"] = row["category"].lower().strip()
    return row

normalized = ds.map(normalize_record)

# Map batches — more efficient for vectorized operations
import pandas as pd

def embed_batch(batch: pd.DataFrame) -> pd.DataFrame:
    # batch operations (numpy, sklearn, etc.)
    batch["embedding"] = batch["text"].apply(lambda t: [hash(t) % 100])
    return batch

with_embeddings = ds.map_batches(embed_batch, batch_size=256)

# Filter, select, aggregate
filtered = (
    ds
    .filter(lambda row: row["score"] > 0.5)
    .select_columns(["id", "score", "category"])
    .groupby("category")
    .count()
)

# Write results
normalized.write_parquet("/output/normalized/")
normalized.write_csv("/output/results.csv")

# GPU-accelerated batch inference
@ray.remote(num_gpus=1)
class ModelActor:
    def __init__(self, model_path: str):
        import torch
        self.model = torch.load(model_path)
        self.model.eval()
    
    def predict(self, batch: list) -> list:
        import torch
        with torch.no_grad():
            inputs = torch.tensor(batch)
            return self.model(inputs).tolist()

# Scale inference across multiple GPUs
ds.map_batches(
    ModelActor,
    batch_size=64,
    num_gpus=1,
    concurrency=4,  # 4 parallel GPU workers
)
```

### 3. Ray Serve — Model Serving
```python
from ray import serve
from ray.serve.handle import DeploymentHandle
import requests
from fastapi import FastAPI

app = FastAPI()

# Basic deployment
@serve.deployment(
    num_replicas=2,
    ray_actor_options={"num_cpus": 1},
    autoscaling_config={
        "min_replicas": 1,
        "max_replicas": 10,
        "target_num_ongoing_requests_per_replica": 5,
    },
)
@serve.ingress(app)
class TextClassifier:
    def __init__(self):
        from transformers import pipeline
        self.classifier = pipeline("text-classification", model="distilbert-base-uncased")
    
    @app.post("/classify")
    async def classify(self, text: str) -> dict:
        result = self.classifier(text)[0]
        return {"label": result["label"], "score": result["score"]}

# Deployment composition (pipeline)
@serve.deployment(num_replicas=1, ray_actor_options={"num_gpus": 1})
class EmbeddingModel:
    def __init__(self):
        from sentence_transformers import SentenceTransformer
        self.model = SentenceTransformer("BAAI/bge-small-en-v1.5")
    
    async def embed(self, texts: list[str]) -> list:
        return self.model.encode(texts).tolist()

@serve.deployment(num_replicas=2)
class SearchService:
    def __init__(self, embedder: DeploymentHandle):
        self.embedder = embedder
    
    async def search(self, query: str) -> dict:
        embedding = await self.embedder.embed.remote([query])
        # ... query vector DB with embedding
        return {"query": query, "results": []}

# Deploy the pipeline
serve.run(
    SearchService.bind(EmbeddingModel.bind()),
    name="search-service",
    route_prefix="/search",
)

# Test
response = requests.post("http://localhost:8000/search/search", params={"query": "hello"})
```

### 4. Ray Train — Distributed ML Training
```python
from ray import train
from ray.train.torch import TorchTrainer
from ray.train import ScalingConfig, RunConfig, CheckpointConfig
import torch
import torch.nn as nn

def train_fn(config: dict):
    """Runs on each worker — Ray handles distribution."""
    # Get distributed training context
    model = nn.Linear(10, 1)
    
    # Wrap model for distributed training
    model = train.torch.prepare_model(model)
    
    optimizer = torch.optim.Adam(model.parameters(), lr=config["lr"])
    
    # Training loop
    for epoch in range(config["epochs"]):
        # Prepare dataloader — Ray handles sharding across workers
        dataloader = train.torch.prepare_data_loader(
            torch.utils.data.DataLoader(
                your_dataset, batch_size=config["batch_size"]
            )
        )
        
        total_loss = 0
        for batch in dataloader:
            inputs, labels = batch
            outputs = model(inputs)
            loss = nn.MSELoss()(outputs, labels)
            
            optimizer.zero_grad()
            loss.backward()
            optimizer.step()
            total_loss += loss.item()
        
        # Report metrics — visible in Ray dashboard and Tune
        train.report({"loss": total_loss / len(dataloader), "epoch": epoch})

# Configure and run distributed training
trainer = TorchTrainer(
    train_loop_per_worker=train_fn,
    train_loop_config={"lr": 1e-3, "epochs": 10, "batch_size": 32},
    scaling_config=ScalingConfig(
        num_workers=4,
        use_gpu=True,
        resources_per_worker={"CPU": 2, "GPU": 1},
    ),
    run_config=RunConfig(
        name="my-training-run",
        storage_path="s3://my-bucket/ray-results/",
        checkpoint_config=CheckpointConfig(num_to_keep=3),
    ),
)

result = trainer.fit()
print(f"Best checkpoint: {result.checkpoint}")
```

### 5. Cluster Setup and Autoscaling
```yaml
# cluster.yaml — AWS autoscaling cluster
cluster_name: my-ray-cluster

max_workers: 10

provider:
  type: aws
  region: us-west-2
  availability_zone: us-west-2a,us-west-2b

head_node_type:
  node_config:
    InstanceType: m5.2xlarge
  resources: {"CPU": 8}

worker_node_types:
  - node_type: cpu-workers
    node_config:
      InstanceType: m5.4xlarge
    resources: {"CPU": 16}
    min_workers: 0
    max_workers: 8
  - node_type: gpu-workers
    node_config:
      InstanceType: g4dn.xlarge
    resources: {"CPU": 4, "GPU": 1}
    min_workers: 0
    max_workers: 4

head_setup_commands:
  - pip install ray[all] torch transformers

worker_setup_commands:
  - pip install ray[all] torch transformers
```

## Key Commands Reference

```bash
# Install
pip install "ray[default,data,serve,train,tune]"

# Start local cluster with dashboard
ray start --head --dashboard-host=0.0.0.0
ray dashboard  # Open at http://localhost:8265

# Start cluster from config
ray up cluster.yaml
ray down cluster.yaml

# Connect to remote cluster
ray attach cluster.yaml  # SSH into head node
ray submit cluster.yaml my_script.py  # Run script on cluster

# Monitor running jobs
ray job list
ray job logs <job-id>
ray job stop <job-id>

# Check cluster resources
ray status  # Running tasks, nodes, resources

# Ray Serve management
serve deploy config.yaml
serve status
serve delete my-deployment

# Kill cluster
ray stop
```

## Common Patterns

### Pattern 1: Task Graph with Dependencies
```python
@ray.remote
def fetch_data(source: str) -> list:
    return []  # fetch from source

@ray.remote
def process(data: list) -> dict:
    return {"records": len(data)}

@ray.remote
def aggregate(results: list) -> dict:
    total = sum(r["records"] for r in results)
    return {"total": total}

# Build dependency graph — Ray schedules automatically
sources = ["db", "api", "files"]
data_futures = [fetch_data.remote(s) for s in sources]
processed_futures = [process.remote(d) for d in data_futures]
# aggregate receives futures — Ray waits for dependencies
final = ray.get(aggregate.remote(processed_futures))
```

### Pattern 2: Hyperparameter Tuning with Ray Tune
```python
from ray import tune
from ray.tune.search.optuna import OptunaSearch
from ray.tune.schedulers import ASHAScheduler

def objective(config):
    # Train model with config["lr"], config["hidden_size"], etc.
    accuracy = train_model(config)
    tune.report(accuracy=accuracy)

tuner = tune.Tuner(
    objective,
    param_space={
        "lr": tune.loguniform(1e-5, 1e-1),
        "hidden_size": tune.choice([64, 128, 256, 512]),
        "dropout": tune.uniform(0.1, 0.5),
    },
    tune_config=tune.TuneConfig(
        metric="accuracy",
        mode="max",
        num_samples=50,
        search_alg=OptunaSearch(),
        scheduler=ASHAScheduler(max_t=100, grace_period=10),
    ),
    run_config=train.RunConfig(name="hparam-search"),
)

results = tuner.fit()
best = results.get_best_result("accuracy", "max")
print(f"Best config: {best.config}, accuracy: {best.metrics['accuracy']:.4f}")
```

### Pattern 3: Workflow Orchestration
```python
from ray import workflow

@workflow.step
def ingest(source: str) -> list:
    return fetch_records(source)

@workflow.step
def validate(records: list) -> list:
    return [r for r in records if is_valid(r)]

@workflow.step
def enrich(records: list) -> list:
    return [add_metadata(r) for r in records]

@workflow.step
def load(records: list) -> int:
    return write_to_db(records)

# Durable workflow — survives cluster restarts
workflow_id = "etl-2024-01-15"
result = load.bind(
    enrich.bind(
        validate.bind(
            ingest.bind("s3://source/data.csv")
        )
    )
).run(workflow_id=workflow_id)

# Resume from checkpoint if interrupted
# workflow.resume(workflow_id)
```

## Pitfalls to Avoid

1. **Submitting too many tiny tasks**: Each `remote()` call has ~1ms overhead. For microsecond-scale work, batch into chunks of 100-1000 items before submitting. Use `ray.data` instead of manual task submission for data pipelines — it handles batching automatically.

2. **Serializing large objects per task**: Passing a 1GB DataFrame as a function argument serializes it for every call. Use `ray.put()` to store objects in the Ray object store once, then pass the `ObjectRef` to many tasks: `ref = ray.put(large_df); [fn.remote(ref) for _ in range(100)]`.

3. **Actors that become bottlenecks**: A single actor processes requests sequentially by default. Use `max_concurrency` for async actors (`@ray.remote(max_concurrency=10)`), or use multiple actor instances behind a router. Watch the Ray dashboard for actors with long task queues.

## Related Skills

- `kafka-event-streaming` — Stream processing feeding Ray pipelines
- `mlflow-experiment-tracking` — Track Ray Train experiments in MLflow
- `redis-patterns` — Shared state between Ray actors
- `kubernetes-architect` — Deploying Ray clusters on Kubernetes (KubeRay)

## GitNexus Index

```json
{
  "skill": "ray-distributed-computing",
  "category": "data-engineering",
  "triggers": ["ray", "distributed python", "ray serve", "ray train", "ray data", "parallel processing python", "ray cluster"],
  "outputs": ["remote function", "actor class", "ray serve deployment", "ray train config", "cluster yaml"],
  "complexity": "high",
  "tools": ["ray", "ray-serve", "ray-train", "ray-tune", "ray-data", "python"]
}
```
