---
name: vllm-serving
description: High-throughput and memory-efficient LLM serving with continuous batching and PagedAttention
version: 1.0.0
tags: [llm, serving, inference, gpu, production, openai-compatible]
---

# vLLM — High-Throughput LLM Serving

## Overview

vLLM is a fast and memory-efficient LLM inference and serving library. It uses PagedAttention (manages KV cache like virtual memory pages) and continuous batching (request scheduling without padding waste) to achieve 10-24x higher throughput than HuggingFace Transformers naive serving. Exposes an OpenAI-compatible API server. Used in production by Databricks, Anyscale, and others.

GitHub: https://github.com/vllm-project/vllm (42k+ stars)

## When to Use

- Production LLM serving with real concurrent users
- High-throughput batch inference jobs
- When HuggingFace pipeline throughput is insufficient
- OpenAI-compatible self-hosted API (drop-in for OpenAI SDK)
- Multi-GPU and tensor-parallel inference for large models
- Serving quantized models (GPTQ, AWQ, GGUF)

## Installation

```bash
pip install vllm

# Or with CUDA 12.1
pip install vllm --extra-index-url https://download.pytorch.org/whl/cu121

# Docker (recommended for production)
docker pull vllm/vllm-openai:latest
```

## Key Patterns / Usage

### Start OpenAI-Compatible API Server
```bash
# Start server (downloads model if needed)
python -m vllm.entrypoints.openai.api_server \
  --model mistralai/Mistral-7B-Instruct-v0.2 \
  --port 8000

# With quantization (less VRAM)
python -m vllm.entrypoints.openai.api_server \
  --model TheBloke/Mistral-7B-Instruct-v0.2-GPTQ \
  --quantization gptq \
  --port 8000

# Multi-GPU tensor parallelism
python -m vllm.entrypoints.openai.api_server \
  --model meta-llama/Llama-3-70b-instruct \
  --tensor-parallel-size 4 \
  --port 8000
```

### Client with OpenAI SDK
```python
from openai import OpenAI

client = OpenAI(base_url="http://localhost:8000/v1", api_key="none")

# Chat
response = client.chat.completions.create(
    model="mistralai/Mistral-7B-Instruct-v0.2",
    messages=[{"role": "user", "content": "Explain transformers"}],
    temperature=0.7,
    max_tokens=512,
)
print(response.choices[0].message.content)

# Streaming
stream = client.chat.completions.create(
    model="mistralai/Mistral-7B-Instruct-v0.2",
    messages=[{"role": "user", "content": "Write a poem"}],
    stream=True,
)
for chunk in stream:
    if chunk.choices[0].delta.content:
        print(chunk.choices[0].delta.content, end="")
```

### Python Offline Inference
```python
from vllm import LLM, SamplingParams

# Initialize model
llm = LLM(model="mistralai/Mistral-7B-Instruct-v0.2")

# Single generation
outputs = llm.generate(
    ["Tell me about quantum computing"],
    SamplingParams(temperature=0.8, max_tokens=200),
)
print(outputs[0].outputs[0].text)

# Batch generation (efficient)
prompts = [
    "What is ML?",
    "Explain neural networks",
    "What is backpropagation?",
]
outputs = llm.generate(prompts, SamplingParams(max_tokens=100))
for output in outputs:
    print(output.outputs[0].text)
```

### Chat Template Formatting
```python
from vllm import LLM, SamplingParams
from transformers import AutoTokenizer

model_id = "meta-llama/Meta-Llama-3-8B-Instruct"
llm = LLM(model=model_id)
tokenizer = AutoTokenizer.from_pretrained(model_id)

messages = [
    {"role": "system", "content": "You are a helpful assistant."},
    {"role": "user", "content": "What is the capital of France?"},
]

prompt = tokenizer.apply_chat_template(
    messages, tokenize=False, add_generation_prompt=True
)
outputs = llm.generate([prompt], SamplingParams(max_tokens=50))
print(outputs[0].outputs[0].text)
```

### Structured Output with Outlines
```python
from vllm import LLM, SamplingParams
from pydantic import BaseModel

class City(BaseModel):
    name: str
    country: str
    population: int

llm = LLM(model="mistralai/Mistral-7B-v0.1")
outputs = llm.generate(
    ["Give me info about Paris"],
    SamplingParams(
        max_tokens=200,
        guided_decoding={"json": City.model_json_schema()},
    ),
)
print(outputs[0].outputs[0].text)
```

### Docker Production Deployment
```bash
docker run --runtime nvidia --gpus all \
  -v ~/.cache/huggingface:/root/.cache/huggingface \
  -p 8000:8000 \
  --ipc=host \
  vllm/vllm-openai:latest \
  --model mistralai/Mistral-7B-Instruct-v0.2 \
  --max-model-len 4096
```

### Key Server Flags
```bash
python -m vllm.entrypoints.openai.api_server \
  --model <model-id> \
  --max-model-len 8192 \          # max context window
  --gpu-memory-utilization 0.90 \ # fraction of GPU VRAM
  --max-num-seqs 256 \            # max concurrent sequences
  --enable-prefix-caching \       # cache common prefixes
  --served-model-name my-model    # alias for API calls
```

## Common Pitfalls

- **CUDA OOM**: reduce `--gpu-memory-utilization` (try 0.85) or `--max-model-len`
- **Model not found**: set `HF_TOKEN` env var for gated models (Llama 3, etc.)
- **Quantization mismatch**: GPTQ needs `--quantization gptq`; AWQ needs `--quantization awq`
- **Slow first request**: model loads on first call if not pre-warmed; use `/v1/models` to trigger warmup
- **Context too long**: vLLM rejects requests exceeding `--max-model-len`; set appropriately
- **Multi-GPU fragmentation**: use `--tensor-parallel-size` equal to your GPU count for best results
- **Prefix cache**: `--enable-prefix-caching` greatly speeds up repeated system prompts

## Related Skills

- `llamafile` — simpler local inference without GPU requirements
- `sglang` — alternative high-throughput serving framework
- `litellm-proxy` — route requests to vLLM via unified API
- `outlines` — structured generation compatible with vLLM
- `ray-distributed-computing` — scale vLLM across multiple nodes

## GitNexus Index

```
tool: vllm
category: llm-serving
tier: self-hosted
interface: openai-compatible
platform: linux-gpu
stars: 42000+
```
