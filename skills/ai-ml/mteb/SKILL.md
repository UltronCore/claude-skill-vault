---
name: mteb
description: Massive Text Embedding Benchmark for evaluating and comparing embedding models across tasks
version: 1.0.0
tags: [embeddings, benchmark, evaluation, nlp, sentence-transformers, retrieval]
---

# MTEB — Massive Text Embedding Benchmark

## Overview

MTEB (Massive Text Embedding Benchmark) is the standard benchmark suite for evaluating text embedding models across 8 task categories and 56+ datasets. It covers classification, clustering, pair classification, reranking, retrieval, STS (semantic textual similarity), summarization, and bitext mining. MTEB is the go-to leaderboard for selecting the right embedding model for your use case — before you commit to a model in production, run MTEB to understand trade-offs.

GitHub: https://github.com/embeddings-benchmark/mteb (2k+ stars)
Leaderboard: https://huggingface.co/spaces/mteb/leaderboard

## When to Use

- Selecting the best embedding model for a specific task (retrieval, STS, classification)
- Benchmarking a custom fine-tuned embedding model against SOTA baselines
- Comparing performance across languages for multilingual embedding models
- Reproducing published MTEB leaderboard results locally
- Running a subset of tasks for faster iteration during model development

## Installation

```bash
pip install mteb

# Sentence-transformers for most models
pip install sentence-transformers

# Optional: for specific model backends
pip install torch transformers
```

## Key Patterns / Usage

### Run a Single Task on a Model
```python
import mteb
from sentence_transformers import SentenceTransformer

# Load your embedding model
model = SentenceTransformer("BAAI/bge-small-en-v1.5")

# Select a specific task
tasks = mteb.get_tasks(tasks=["STS12"])

# Run evaluation
evaluation = mteb.MTEB(tasks=tasks)
results = evaluation.run(model, output_folder="results/bge-small")

# Results saved to JSON and printed
print(results)
```

### Run Full English Benchmark Suite
```python
import mteb
from sentence_transformers import SentenceTransformer

model = SentenceTransformer("intfloat/e5-large-v2")

# Get all English tasks
tasks = mteb.get_tasks(languages=["eng"])

evaluation = mteb.MTEB(tasks=tasks)
results = evaluation.run(
    model,
    output_folder="results/e5-large",
    overwrite_results=False,  # Skip already-computed tasks
)
```

### Run Specific Task Categories
```python
import mteb

# Available categories: Classification, Clustering, PairClassification,
# Reranking, Retrieval, STS, Summarization, BitextMining

# Retrieval tasks only (most important for RAG)
retrieval_tasks = mteb.get_tasks(task_types=["Retrieval"])

# STS tasks for similarity use cases
sts_tasks = mteb.get_tasks(task_types=["STS"])

# Multiple categories
tasks = mteb.get_tasks(task_types=["Retrieval", "Reranking", "STS"])

model = SentenceTransformer("sentence-transformers/all-MiniLM-L6-v2")
evaluation = mteb.MTEB(tasks=tasks)
results = evaluation.run(model, output_folder="results/minilm")
```

### Compare Two Models on Retrieval
```python
import mteb
import json
from pathlib import Path

retrieval_tasks = mteb.get_tasks(
    task_types=["Retrieval"],
    languages=["eng"],
)

models_to_compare = [
    "BAAI/bge-small-en-v1.5",
    "sentence-transformers/all-MiniLM-L6-v2",
]

for model_name in models_to_compare:
    from sentence_transformers import SentenceTransformer
    model = SentenceTransformer(model_name)
    
    evaluation = mteb.MTEB(tasks=retrieval_tasks)
    results = evaluation.run(
        model,
        output_folder=f"results/{model_name.replace('/', '_')}",
    )

# Load and compare results
def load_avg_score(results_dir: str, metric: str = "ndcg_at_10") -> float:
    scores = []
    for result_file in Path(results_dir).glob("**/*.json"):
        data = json.loads(result_file.read_text())
        if metric in data.get("scores", {}).get("test", [{}])[0]:
            scores.append(data["scores"]["test"][0][metric])
    return sum(scores) / len(scores) if scores else 0.0

for model_name in models_to_compare:
    safe_name = model_name.replace("/", "_")
    avg = load_avg_score(f"results/{safe_name}")
    print(f"{model_name}: avg NDCG@10 = {avg:.4f}")
```

### Using a Custom/Fine-tuned Model
```python
import mteb
from mteb import DenseTextEncoder

# Wrap any model that has encode() → np.ndarray
class MyCustomEmbedder:
    def __init__(self, model_path: str):
        from sentence_transformers import SentenceTransformer
        self.model = SentenceTransformer(model_path)
    
    def encode(self, sentences, batch_size=32, **kwargs):
        return self.model.encode(sentences, batch_size=batch_size, **kwargs)

my_model = MyCustomEmbedder("/path/to/my-fine-tuned-model")

tasks = mteb.get_tasks(tasks=["MSMARCO", "NFCorpus", "SciFact"])
evaluation = mteb.MTEB(tasks=tasks)
results = evaluation.run(my_model, output_folder="results/my-model")
```

### Quick STS Sanity Check (Fast)
```python
import mteb
from sentence_transformers import SentenceTransformer

# Fast single-dataset check before running full benchmark
model = SentenceTransformer("BAAI/bge-base-en-v1.5")

# STSBenchmark is fast and widely reported
tasks = mteb.get_tasks(tasks=["STSBenchmarkSTS"])
evaluation = mteb.MTEB(tasks=tasks)
results = evaluation.run(model, output_folder="results/quick-check")

# Check the score
for task_result in results:
    print(f"Task: {task_result.task_name}")
    print(f"Spearman: {task_result.scores['test'][0]['spearman_cosine']:.4f}")
```

### List Available Tasks
```python
import mteb

# See all available tasks
all_tasks = mteb.get_tasks()
print(f"Total tasks: {len(all_tasks)}")

# Filter by category and language
en_retrieval = mteb.get_tasks(task_types=["Retrieval"], languages=["eng"])
print(f"English retrieval tasks: {len(en_retrieval)}")
for task in en_retrieval:
    print(f"  - {task.metadata.name}")
```

## Common Pitfalls

- **GPU memory**: full benchmark needs significant GPU RAM; run task subsets for development, full suite for final evaluation
- **Time cost**: running all 56+ tasks takes hours; select the category relevant to your use case
- **Metric varies by task**: retrieval uses NDCG@10, STS uses Spearman, classification uses accuracy — compare within the same task type
- **Model max sequence length**: tasks with long documents (BeIR datasets) will truncate if your model has short context window
- **Batch size tuning**: larger batch sizes speed up evaluation significantly on GPU; default may be conservative
- **Results caching**: use `overwrite_results=False` to skip already-completed tasks and resume interrupted runs
- **BEIR vs MTEB**: BEIR datasets are a subset of MTEB retrieval tasks; MTEB is the superset

## Related Skills

- `embedding-pipeline` — building production embedding pipelines
- `train-sentence-transformers` — fine-tuning sentence-transformers models
- `peft-fine-tuning` — parameter-efficient fine-tuning for embeddings
- `semantic-search` — applying embeddings in search systems
- `ragas` — evaluating RAG systems (uses embeddings)

## GitNexus Index

```
tool: mteb
category: llm-evaluation
tier: library
interface: python-sdk
platform: cross-platform
stars: 2000+
```
