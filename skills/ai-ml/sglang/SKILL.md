---
name: sglang
description: Fast LLM inference runtime with RadixAttention and structured generation support
version: 1.0.0
tags: [llm, serving, inference, gpu, sglang, structured-generation]
---

# SGLang — Fast LLM Inference Runtime

## Overview

SGLang (Structured Generation Language) is a fast serving framework for large language models and vision language models. It features RadixAttention for efficient KV cache reuse across requests, continuous batching, speculative decoding, and native support for structured outputs (JSON, regex). Benchmarks show 3-10x throughput improvement over naive HuggingFace serving. Developed by researchers at UC Berkeley and LMSYS.

GitHub: https://github.com/sgl-project/sglang (12k+ stars)

## When to Use

- High-throughput LLM serving with complex structured outputs
- Workloads with long shared prefixes (system prompts, few-shot examples)
- Multi-modal (vision-language) model serving
- When structured generation (JSON/regex) throughput matters
- Alternative to vLLM for specific model architectures

## Installation

```bash
pip install sglang[all]

# With FlashInfer (recommended for better performance)
pip install sglang[all] flashinfer-python \
  --extra-index-url https://flashinfer.ai/whl/cu124/torch2.4/
```

## Key Patterns / Usage

### Launch API Server
```bash
# Basic server
python -m sglang.launch_server \
  --model-path meta-llama/Meta-Llama-3-8B-Instruct \
  --port 30000

# With tensor parallelism for large models
python -m sglang.launch_server \
  --model-path meta-llama/Meta-Llama-3-70B-Instruct \
  --port 30000 \
  --tp-size 4

# With structured generation backend
python -m sglang.launch_server \
  --model-path mistralai/Mistral-7B-Instruct-v0.2 \
  --port 30000 \
  --enable-flashinfer-sampling
```

### OpenAI-Compatible Client
```python
import openai

client = openai.Client(
    base_url="http://localhost:30000/v1",
    api_key="none",
)

response = client.chat.completions.create(
    model="meta-llama/Meta-Llama-3-8B-Instruct",
    messages=[{"role": "user", "content": "Explain transformer architecture"}],
    temperature=0.7,
    max_tokens=300,
)
print(response.choices[0].message.content)
```

### JSON Structured Output
```python
import openai
import json

client = openai.Client(base_url="http://localhost:30000/v1", api_key="none")

schema = {
    "type": "object",
    "properties": {
        "name": {"type": "string"},
        "age": {"type": "integer"},
        "city": {"type": "string"},
    },
    "required": ["name", "age", "city"],
}

response = client.chat.completions.create(
    model="meta-llama/Meta-Llama-3-8B-Instruct",
    messages=[{"role": "user", "content": "Tell me about Alice, 30, from NYC"}],
    response_format={
        "type": "json_schema",
        "json_schema": {"name": "person", "schema": schema},
    },
)
data = json.loads(response.choices[0].message.content)
print(data)
```

### Regex Constrained Generation
```python
response = client.chat.completions.create(
    model="meta-llama/Meta-Llama-3-8B-Instruct",
    messages=[{"role": "user", "content": "What is today's date?"}],
    extra_body={
        "regex": r"\d{4}-\d{2}-\d{2}",
    },
)
print(response.choices[0].message.content)  # e.g. "2026-05-24"
```

### SGLang Python API (Advanced)
```python
import sglang as sgl

@sgl.function
def classify_sentiment(s, text):
    s += sgl.system("Classify sentiment as positive, negative, or neutral.")
    s += sgl.user(text)
    s += sgl.assistant(sgl.gen("sentiment", choices=["positive", "negative", "neutral"]))

# Run single
state = classify_sentiment.run(text="I love this product!")
print(state["sentiment"])

# Run batch (parallel)
texts = [
    "I love this!",
    "This is terrible.",
    "It was okay.",
]
states = classify_sentiment.run_batch([{"text": t} for t in texts])
for state in states:
    print(state["sentiment"])
```

### Vision-Language Model Serving
```bash
python -m sglang.launch_server \
  --model-path Qwen/Qwen2-VL-7B-Instruct \
  --port 30000
```

```python
import base64
from pathlib import Path

# Encode image
image_data = base64.b64encode(Path("image.png").read_bytes()).decode()

response = client.chat.completions.create(
    model="Qwen/Qwen2-VL-7B-Instruct",
    messages=[{
        "role": "user",
        "content": [
            {"type": "image_url", "image_url": {"url": f"data:image/png;base64,{image_data}"}},
            {"type": "text", "text": "Describe this image in detail."},
        ],
    }],
)
print(response.choices[0].message.content)
```

### Speculative Decoding (Speed Boost)
```bash
python -m sglang.launch_server \
  --model-path meta-llama/Meta-Llama-3-8B-Instruct \
  --speculative-draft-model-path meta-llama/Meta-Llama-3-8B-Instruct \
  --speculative-num-draft-tokens 4 \
  --port 30000
```

## Common Pitfalls

- **RadixAttention requires matching prefixes**: system prompts must be identical for cache hits
- **Port 30000 default**: differs from vLLM's 8000; update your client URLs
- **FlashInfer optional but recommended**: significant speedup especially for structured generation
- **Model compatibility**: not all HuggingFace models are supported; check SGLang's model list
- **Memory**: RadixAttention reserves a cache pool — reduce `--mem-fraction-static` if OOM
- **Structured generation startup**: first request with JSON schema is slower (FSM compilation)

## Related Skills

- `vllm-serving` — alternative high-throughput serving (broader model support)
- `outlines` — structured generation library (used internally by SGLang)
- `litellm-proxy` — route traffic to SGLang through a unified gateway
- `guidance` — alternative structured generation paradigm

## GitNexus Index

```
tool: sglang
category: llm-serving
tier: self-hosted
interface: openai-compatible
platform: linux-gpu
stars: 12000+
```
