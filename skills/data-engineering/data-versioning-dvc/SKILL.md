---
name: data-versioning-dvc
description: Version datasets, models, and ML pipelines with DVC (Data Version Control). Covers remote storage backends, pipeline stages with dvc.yaml, experiment tracking, metrics comparison, and integrating DVC with Git and CI/CD workflows.
version: 1.0.0
tags: [dvc, data-versioning, mlops, datasets, pipelines, experiment-tracking, git, s3, gcs, machine-learning]
---

# Data Versioning with DVC

## Overview

DVC (Data Version Control) extends Git to handle large files, datasets, and ML models that don't belong in source control. It stores metadata pointers in Git while pushing actual data to remote storage (S3, GCS, Azure Blob, SSH). DVC also defines reproducible ML pipelines as DAGs — `dvc repro` reruns only changed stages, making experiments fully reproducible and trackable alongside code commits.

## When to Use

- ML datasets grow beyond GitHub's 100MB file limit or LFS costs
- Multiple team members need to work with the same dataset versions without manual file sharing
- Reproducing an experiment from 6 months ago requires knowing exactly which data version was used
- Running AB experiments on different dataset preprocessing strategies
- Automating the full pipeline (data → features → train → evaluate) in CI/CD
- Comparing metrics across experiment branches before merging to main

## Step-by-Step Workflow

### 1. Initial DVC Setup

```bash
# Install DVC with extras for your storage backend
pip install "dvc[s3]"       # AWS S3
pip install "dvc[gcs]"      # Google Cloud Storage
pip install "dvc[azure]"    # Azure Blob
pip install "dvc[ssh]"      # SSH server
pip install "dvc[all]"      # All backends

# Initialize in existing Git repo
cd my-ml-project
git init  # If not already a git repo
dvc init  # Creates .dvc/ directory
git add .dvc .dvcignore
git commit -m "Initialize DVC"

# Configure remote storage
dvc remote add -d myremote s3://my-ml-bucket/dvc
dvc remote modify myremote region us-east-1
git add .dvc/config
git commit -m "Add DVC remote storage"

# For local remote (dev/testing)
dvc remote add -d localremote /tmp/dvc-storage
```

### 2. Tracking Datasets and Models

```bash
# Track a large dataset with DVC
dvc add data/raw/train.csv
# Creates: data/raw/train.csv.dvc (tracked by Git)
#          data/raw/.gitignore (auto-generated, ignores train.csv)

git add data/raw/train.csv.dvc data/raw/.gitignore
git commit -m "Add training dataset"

# Push data to remote
dvc push  # Uploads to S3/GCS/etc

# On another machine — pull the data
git clone https://github.com/org/ml-project
cd ml-project
pip install dvc[s3]
dvc pull  # Downloads data tracked in .dvc files

# Switching dataset versions
git checkout v1.0.0
dvc checkout  # Updates data/ to match this Git commit's .dvc files

# Track a model file
dvc add models/classifier.pkl
git add models/classifier.pkl.dvc
git commit -m "Save trained model v1"
```

### 3. ML Pipelines with dvc.yaml

```yaml
# dvc.yaml — define reproducible pipeline stages
stages:
  download:
    cmd: python src/download.py --output data/raw
    deps:
      - src/download.py
    outs:
      - data/raw

  preprocess:
    cmd: python src/preprocess.py --input data/raw --output data/processed
    deps:
      - src/preprocess.py
      - data/raw          # Depends on download stage output
    params:
      - params.yaml:
          - preprocess.test_size
          - preprocess.random_seed
    outs:
      - data/processed

  featurize:
    cmd: python src/featurize.py --input data/processed --output data/features
    deps:
      - src/featurize.py
      - data/processed
    params:
      - params.yaml:
          - featurize.max_features
    outs:
      - data/features

  train:
    cmd: python src/train.py --features data/features --model models/model.pkl
    deps:
      - src/train.py
      - data/features
    params:
      - params.yaml:
          - train.n_estimators
          - train.max_depth
          - train.learning_rate
    outs:
      - models/model.pkl
    metrics:
      - metrics/train_metrics.json:
          cache: false    # Don't cache — always regenerate

  evaluate:
    cmd: python src/evaluate.py --model models/model.pkl --data data/processed
    deps:
      - src/evaluate.py
      - models/model.pkl
      - data/processed
    metrics:
      - metrics/eval_metrics.json:
          cache: false
    plots:
      - plots/confusion_matrix.json:
          cache: false
      - plots/roc_curve.json:
          cache: false
```

```yaml
# params.yaml — experiment hyperparameters
preprocess:
  test_size: 0.2
  random_seed: 42

featurize:
  max_features: 5000

train:
  n_estimators: 100
  max_depth: 5
  learning_rate: 0.1
```

```python
# src/train.py — read params from DVC
import json, pickle
import pandas as pd
from sklearn.ensemble import GradientBoostingClassifier
import dvc.api

# Read params tracked by DVC
params = dvc.api.params_show()

X_train = pd.read_parquet("data/features/X_train.parquet")
y_train = pd.read_parquet("data/features/y_train.parquet").squeeze()

model = GradientBoostingClassifier(
    n_estimators=params["train"]["n_estimators"],
    max_depth=params["train"]["max_depth"],
    learning_rate=params["train"]["learning_rate"],
    random_state=params["preprocess"]["random_seed"],
)
model.fit(X_train, y_train)

with open("models/model.pkl", "wb") as f:
    pickle.dump(model, f)

# Save training metrics
metrics = {"train_accuracy": model.score(X_train, y_train)}
with open("metrics/train_metrics.json", "w") as f:
    json.dump(metrics, f)
```

### 4. Experiment Tracking

```bash
# Run the pipeline (only reruns changed stages)
dvc repro

# Run an experiment with different params (without committing)
dvc exp run --set-param train.n_estimators=200 --set-param train.max_depth=8

# Save experiment with a name
dvc exp save -n experiment-v2

# Compare experiments
dvc exp show
# Shows table: experiment name, metrics, params

# Compare specific metrics
dvc metrics show
dvc metrics diff HEAD main  # Diff metrics between branches

# List all experiments
dvc exp list
dvc exp list --all-branches

# Apply a specific experiment to current workspace
dvc exp apply experiment-v2

# Clean up experiments you don't want
dvc exp gc  # Remove experiments not saved to Git
```

```python
# Programmatic experiment comparison
import subprocess, json

def compare_experiments() -> list[dict]:
    """Get all experiments with their metrics as a list."""
    result = subprocess.run(
        ["dvc", "exp", "show", "--json"],
        capture_output=True, text=True, check=True
    )
    data = json.loads(result.stdout)

    experiments = []
    for commit, exps in data.items():
        for exp_name, exp_data in exps.items():
            if "data" not in exp_data:
                continue
            exp = {
                "name": exp_name,
                "commit": commit[:7],
                **exp_data["data"].get("metrics", {}),
                **exp_data["data"].get("params", {}),
            }
            experiments.append(exp)
    return experiments
```

### 5. CI/CD Integration

```yaml
# .github/workflows/ml-pipeline.yml
name: ML Pipeline
on:
  push:
    branches: [main, experiment/*]
  pull_request:
    branches: [main]

jobs:
  pipeline:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Python
        uses: actions/setup-python@v5
        with:
          python-version: "3.12"

      - name: Install dependencies
        run: pip install dvc[s3] -r requirements.txt

      - name: Configure AWS credentials for DVC
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1

      - name: Pull DVC data
        run: dvc pull --run-cache

      - name: Reproduce pipeline
        run: dvc repro

      - name: Push updated artifacts
        run: dvc push

      - name: Comment metrics on PR
        if: github.event_name == 'pull_request'
        run: |
          dvc metrics diff main --md >> $GITHUB_STEP_SUMMARY
          echo "## Plots" >> $GITHUB_STEP_SUMMARY
          dvc plots diff main --targets plots/ --html >> plots_diff.html
```

## Key Commands Reference

```bash
# Core workflow
dvc init                        # Initialize DVC in git repo
dvc add path/to/file            # Start tracking a file
dvc push                        # Upload tracked files to remote
dvc pull                        # Download tracked files from remote
dvc checkout                    # Sync workspace to current .dvc files
dvc status                      # Show changed tracked files
dvc gc --workspace              # Remove cached files not in workspace

# Pipelines
dvc repro                       # Run/resume pipeline
dvc repro -f                    # Force rerun all stages
dvc repro --dry                 # Show what would run
dvc dag                         # Show pipeline DAG
dvc dag --md                    # DAG in Markdown (for GitHub)

# Experiments
dvc exp run                     # Run experiment with current params
dvc exp run --set-param a=b     # Override a param for this run
dvc exp show                    # Table of all experiments
dvc exp diff exp1 exp2          # Compare two experiments
dvc exp apply exp-name          # Apply experiment to workspace
dvc exp branch exp-name branch  # Create git branch from experiment

# Metrics and plots
dvc metrics show                # Show metrics for current revision
dvc metrics diff                # Compare to previous commit
dvc plots show plots/*.json     # Visualize plots
dvc plots diff --targets plots/ # Plot comparison

# Remote management
dvc remote list                 # Show configured remotes
dvc remote modify myremote url s3://new-bucket/dvc
dvc remote default myremote
```

## Common Patterns

### Pattern 1: Dataset Registry (Share Data Across Projects)

```bash
# In a dedicated data registry repo
dvc add datasets/imagenet/train/
git tag -a "imagenet-2023-v1" -m "ImageNet 2023 training set"
git push --tags
dvc push

# In another project — import without cloning full repo
dvc import https://github.com/org/data-registry \
  datasets/imagenet/train/ \
  -o data/imagenet/  # Tracks the import as a dependency

# Update to latest version of imported data
dvc update data/imagenet.dvc
```

### Pattern 2: Python API for Accessing Remote Data

```python
# Access DVC-tracked files without cloning the full repo
import dvc.api

# Read a remote file directly into memory
with dvc.api.open(
    path="data/processed/features.parquet",
    repo="https://github.com/org/ml-project",
    rev="v2.0.0",  # Git tag or commit
    mode="rb"
) as f:
    import pandas as pd
    df = pd.read_parquet(f)

# Get the URL of a DVC-tracked file in remote storage
url = dvc.api.get_url(
    path="models/model.pkl",
    repo="https://github.com/org/ml-project",
    rev="main"
)
print(f"Model is at: {url}")
```

### Pattern 3: Automated Experiment Grid Search

```python
import subprocess, itertools, json

def grid_search_experiments(param_grid: dict) -> list[dict]:
    """Run DVC experiment for each param combination."""
    keys = list(param_grid.keys())
    values = list(param_grid.values())
    results = []

    for combo in itertools.product(*values):
        params = dict(zip(keys, combo))
        set_params = [f"--set-param {k}={v}" for k, v in params.items()]
        name = "_".join(f"{k}{v}" for k, v in params.items())

        cmd = ["dvc", "exp", "run", "--name", name] + [
            part for sp in set_params for part in sp.split()
        ]
        subprocess.run(cmd, check=True)

        metrics_raw = subprocess.run(
            ["dvc", "metrics", "show", "--json"],
            capture_output=True, text=True
        ).stdout
        metrics = json.loads(metrics_raw)
        results.append({"params": params, "metrics": metrics, "name": name})

    return sorted(results, key=lambda r: r["metrics"].get("accuracy", 0), reverse=True)

# Usage
best = grid_search_experiments({
    "train.n_estimators": [100, 200, 300],
    "train.max_depth": [3, 5, 8],
})
print(f"Best experiment: {best[0]['name']}")
```

## Pitfalls to Avoid

1. **Adding large files directly to Git instead of DVC**: Once a large file is committed to Git history, it's difficult to remove — it grows the repo forever and slows clones. Establish a pre-commit hook or CI check that fails if files over 10MB are staged without a `.dvc` counterpart. DVC's `.dvcignore` file helps prevent accidental Git adds.

2. **Not committing `.dvc` files after `dvc push`**: `dvc add` creates a `.dvc` file that must be committed to Git for others to know the dataset version. A common mistake is pushing data to remote storage but forgetting `git add *.dvc && git commit` — the next person to `dvc pull` gets an old version. Make this a habit: always commit after add/push.

3. **Using `dvc push` without `--run-cache`**: DVC caches stage outputs locally but doesn't push them to remote by default — only explicitly tracked files. Use `dvc push --run-cache` to also push stage output caches so CI and teammates can skip rerunning unchanged stages with `dvc repro --pull`.

## Related Skills

- `mlops-engineer` — MLOps practices, model registry, and deployment
- `mlflow-experiment-tracking` — Complementary experiment tracking (metrics, artifacts)
- `data-pipeline-engineer` — Broader data pipeline patterns
- `github-actions-ci-workflow` — CI/CD workflows that run DVC pipelines
- `llm-fine-tuning-pipeline` — Fine-tuning workflows that DVC can version

## GitNexus Index

```json
{
  "skill": "data-versioning-dvc",
  "category": "data-engineering",
  "triggers": ["DVC", "data versioning", "dataset versioning", "dvc repro", "dvc pipeline", "ml experiment tracking", "dvc push pull", "dvc.yaml", "data version control", "reproducible ml"],
  "outputs": ["dvc.yaml pipeline", "params.yaml", "dvc exp run", "dvc remote add", "grid_search_experiments", "compare_experiments", "dvc.api.open"],
  "complexity": "medium",
  "tools": ["dvc", "git", "s3", "gcs", "python", "sklearn", "github-actions"]
}
```
