---
name: modal-gpu
description: Serverless GPU compute for ML workloads — run training, inference, and batch jobs on Modal
version: 1.0.0
tags: [gpu, serverless, ml, inference, training, cloud, python]
---

# Modal — Serverless GPU Compute for ML

## Overview

Modal is a serverless cloud platform purpose-built for ML and data workloads. You write Python functions decorated with `@app.function()` and Modal handles containerization, GPU provisioning, autoscaling, and cold starts. Pay per second of compute with no idle costs. Excellent for inference endpoints, training jobs, batch processing, and scheduled ML pipelines. Supports A10G, A100, H100 GPUs with sub-second cold starts on pre-warmed containers.

GitHub: https://github.com/modal-labs/modal-client (5k+ stars)
Docs: https://modal.com/docs

## When to Use

- Running GPU inference without managing Kubernetes or EC2
- Fine-tuning models on H100s with pay-per-use billing
- Batch embedding or inference jobs that need to scale to zero
- Deploying ML model endpoints that autoscale automatically
- Running expensive ML experiments without paying for idle GPU time

## Installation

```bash
pip install modal

# Authenticate
modal setup
# Or: modal token new
```

## Key Patterns / Usage

### Basic GPU Function
```python
import modal

app = modal.App("gpu-hello-world")

@app.function(gpu="A10G")
def run_on_gpu():
    import torch
    device = torch.device("cuda")
    x = torch.randn(1000, 1000, device=device)
    result = (x @ x.T).sum().item()
    return f"GPU compute result: {result:.2f}, GPU: {torch.cuda.get_device_name(0)}"

@app.local_entrypoint()
def main():
    result = run_on_gpu.remote()
    print(result)
```

### Inference Endpoint with Model Caching
```python
import modal

app = modal.App("llm-inference")

# Build a custom image with model weights cached at build time
image = (
    modal.Image.debian_slim(python_version="3.11")
    .pip_install("transformers", "torch", "accelerate")
    .run_function(
        lambda: __import__("transformers").pipeline(
            "text-generation",
            model="microsoft/phi-2",
            device_map="auto",
        )
    )
)

@app.cls(
    gpu="A10G",
    image=image,
    container_idle_timeout=300,  # Keep warm for 5 minutes
)
class LLMInference:
    @modal.enter()
    def load_model(self):
        from transformers import pipeline
        self.pipe = pipeline(
            "text-generation",
            model="microsoft/phi-2",
            device_map="auto",
        )
    
    @modal.method()
    def generate(self, prompt: str, max_new_tokens: int = 200) -> str:
        result = self.pipe(prompt, max_new_tokens=max_new_tokens)
        return result[0]["generated_text"]

@app.local_entrypoint()
def main():
    model = LLMInference()
    response = model.generate.remote("Explain transformers in one paragraph:")
    print(response)
```

### Serve a FastAPI Endpoint
```python
import modal
from fastapi import FastAPI

app = modal.App("embedding-api")
web_app = FastAPI()

image = modal.Image.debian_slim().pip_install("sentence-transformers", "fastapi")

@app.cls(
    gpu="A10G",
    image=image,
    container_idle_timeout=600,
)
@modal.asgi_app()
class EmbeddingService:
    @modal.enter()
    def load_model(self):
        from sentence_transformers import SentenceTransformer
        self.model = SentenceTransformer("BAAI/bge-small-en-v1.5")
    
    def fastapi_app(self):
        from fastapi import FastAPI
        from pydantic import BaseModel
        
        app = FastAPI()
        
        class EmbedRequest(BaseModel):
            texts: list[str]
        
        @app.post("/embed")
        async def embed(req: EmbedRequest):
            embeddings = self.model.encode(req.texts).tolist()
            return {"embeddings": embeddings}
        
        return app

# Deploy: modal deploy embedding_service.py
# Then call: https://your-app--embedding-api.modal.run/embed
```

### Batch Processing with Map
```python
import modal

app = modal.App("batch-embeddings")

image = modal.Image.debian_slim().pip_install("sentence-transformers")

@app.function(gpu="A10G", image=image)
def embed_batch(texts: list[str]) -> list[list[float]]:
    from sentence_transformers import SentenceTransformer
    model = SentenceTransformer("BAAI/bge-base-en-v1.5")
    return model.encode(texts).tolist()

@app.local_entrypoint()
def main():
    # Load 10,000 texts
    all_texts = [f"Document {i}" for i in range(10_000)]
    
    # Split into batches of 256
    batch_size = 256
    batches = [all_texts[i:i+batch_size] for i in range(0, len(all_texts), batch_size)]
    
    # Run all batches in parallel on separate GPU instances
    all_embeddings = []
    for batch_result in embed_batch.map(batches, order_outputs=True):
        all_embeddings.extend(batch_result)
    
    print(f"Embedded {len(all_embeddings)} documents")
```

### Fine-Tuning Job with Volume for Checkpoints
```python
import modal

app = modal.App("finetune-job")

# Persistent volume for storing checkpoints
volume = modal.Volume.from_name("finetune-checkpoints", create_if_missing=True)

image = (
    modal.Image.debian_slim()
    .pip_install("transformers", "torch", "peft", "datasets", "accelerate")
)

@app.function(
    gpu="H100",
    image=image,
    volumes={"/checkpoints": volume},
    timeout=3600,  # 1-hour timeout
)
def finetune():
    from transformers import AutoModelForCausalLM, AutoTokenizer, TrainingArguments, Trainer
    from peft import LoraConfig, get_peft_model
    from datasets import load_dataset
    
    model_name = "meta-llama/Llama-3.2-1B"
    
    tokenizer = AutoTokenizer.from_pretrained(model_name)
    model = AutoModelForCausalLM.from_pretrained(model_name, device_map="auto")
    
    config = LoraConfig(r=16, lora_alpha=32, target_modules=["q_proj", "v_proj"])
    model = get_peft_model(model, config)
    
    dataset = load_dataset("tatsu-lab/alpaca", split="train[:1000]")
    
    args = TrainingArguments(
        output_dir="/checkpoints/lora-llama",
        num_train_epochs=1,
        per_device_train_batch_size=4,
        gradient_accumulation_steps=4,
        save_steps=100,
    )
    
    trainer = Trainer(model=model, args=args, train_dataset=dataset)
    trainer.train()
    
    print("Training complete. Checkpoints saved to /checkpoints/")

@app.local_entrypoint()
def main():
    finetune.remote()
```

### Scheduled Batch Job (Cron)
```python
import modal

app = modal.App("daily-embeddings")

image = modal.Image.debian_slim().pip_install("sentence-transformers", "requests")

@app.function(
    gpu="A10G",
    image=image,
    schedule=modal.Cron("0 2 * * *"),  # Run at 2am daily
)
def daily_embed_new_documents():
    import requests
    from sentence_transformers import SentenceTransformer
    
    model = SentenceTransformer("BAAI/bge-base-en-v1.5")
    
    # Fetch new documents from your API
    docs = requests.get("https://api.yourapp.com/new-docs").json()
    embeddings = model.encode([d["text"] for d in docs])
    
    # Save back to your vector store
    # ...
    print(f"Embedded {len(docs)} new documents")
```

## Common Pitfalls

- **Cold starts**: first invocation takes 10-30s for container startup; use `container_idle_timeout` and `keep_warm` for latency-sensitive endpoints
- **Image build time**: large model downloads in `run_function()` are cached — but first build is slow; pre-build images separately
- **Secret management**: use `modal.Secret.from_name()` for API keys, not environment variables in code
- **GPU memory limits**: A10G has 24GB, A100 80GB, H100 80GB; size batches accordingly
- **Timeout defaults**: functions default to 300s; set `timeout=` explicitly for long training jobs
- **Volume flushing**: changes to volumes from inside a function are only guaranteed after the function returns
- **Cost monitoring**: GPU time is billed per second; long-running idle containers cost real money even at idle

## Related Skills

- `vllm-serving` — deploy vLLM on Modal for high-throughput LLM inference
- `peft-fine-tuning` — LoRA/QLoRA patterns that run well on Modal
- `unsloth` — fast fine-tuning library optimized for Modal's H100s
- `ray-distributed-computing` — alternative for multi-node distributed training
- `serverless-patterns` — general serverless architecture patterns

## GitNexus Index

```
tool: modal-gpu
category: ml-infrastructure
tier: platform
interface: python-sdk
platform: cloud
stars: 5000+
```
