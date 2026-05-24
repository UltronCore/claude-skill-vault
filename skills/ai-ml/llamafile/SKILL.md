---
name: llamafile
description: Run LLMs as self-contained single-file executables with no installation required
version: 1.0.0
tags: [llm, inference, local, executable, portable]
---

# Llamafile — Portable LLM Executables

## Overview

Llamafile (by Mozilla) packages an LLM model together with a llama.cpp runtime into a single portable executable that runs on Windows, macOS, and Linux without installation. Based on the Cosmopolitan Libc project, a single `.llamafile` binary runs natively on 6+ OS/architecture combos. Ideal for distributing LLMs as self-contained tools, CI runners, or offline inference without Docker or Python environments.

GitHub: https://github.com/Mozilla-Ocho/llamafile (14k+ stars)

## When to Use

- Distributing an LLM as a single downloadable artifact
- Running inference in CI/CD pipelines without GPU or heavy dependencies
- Offline or air-gapped environments
- Rapid prototyping without Python environment setup
- Embedding a model into a CLI tool

## Installation

```bash
# Download a pre-built llamafile (example: Mistral 7B)
wget https://huggingface.co/Mozilla/Mistral-7B-Instruct-v0.2-llamafile/resolve/main/mistral-7b-instruct-v0.2.Q4_K_M.llamafile

# Make executable (macOS/Linux)
chmod +x mistral-7b-instruct-v0.2.Q4_K_M.llamafile

# Run (opens browser UI by default)
./mistral-7b-instruct-v0.2.Q4_K_M.llamafile

# Run headless as OpenAI-compatible API server
./mistral-7b-instruct-v0.2.Q4_K_M.llamafile --server --port 8080 --nobrowser

# Or run CLI inference directly
./mistral-7b-instruct-v0.2.Q4_K_M.llamafile -p "Explain quantum entanglement in one sentence"
```

## Key Patterns / Usage

### Serving as OpenAI-compatible API
```bash
./model.llamafile --server --port 8080 --nobrowser --n-gpu-layers 35

# Now query with any OpenAI-compatible client
curl http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "local-model",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'
```

### Using with Python (openai SDK)
```python
from openai import OpenAI

client = OpenAI(base_url="http://localhost:8080/v1", api_key="none")

response = client.chat.completions.create(
    model="local-model",
    messages=[{"role": "user", "content": "Write a haiku about llamafiles"}],
    temperature=0.7,
)
print(response.choices[0].message.content)
```

### Building a Custom Llamafile
```bash
# Install zipalign tool
pip install zipalign-java

# Combine llamafile runtime + GGUF model
wget https://github.com/Mozilla-Ocho/llamafile/releases/latest/download/llamafile
chmod +x llamafile
cp llamafile my-model.llamafile
./llamafile -m my-model.gguf --server  # embed model separately

# Or use llamafile-add to bundle:
./llamafile-add my-model.gguf -o bundled-model.llamafile
```

### Running with GPU Acceleration
```bash
# macOS Metal
./model.llamafile --n-gpu-layers 99

# NVIDIA CUDA (requires CUDA toolkit)
./model.llamafile --n-gpu-layers 35 --cuda

# Check hardware detection
./model.llamafile --list-devices
```

### Embedding Inference (no server)
```bash
# Generate embeddings
./model.llamafile --embedding -p "text to embed" --output-format json

# Batch processing via stdin
echo "Summarize: $(cat document.txt)" | ./model.llamafile -p -
```

### Environment Variables
```bash
# Control threads and context
LLAMAFILE_THREADS=8 ./model.llamafile --ctx-size 4096

# Disable GPU (CPU-only)
GGML_OPENCL_DEVICE=-1 ./model.llamafile
```

## Common Pitfalls

- **macOS Gatekeeper**: first run needs `xattr -c model.llamafile` or right-click → Open
- **Windows**: rename to `model.llamafile.exe` before running
- **Large files**: models are 4-8 GB; ensure disk space for both download and extraction temp
- **Context overflow**: default context is often 512 tokens; pass `--ctx-size 4096` for longer prompts
- **No streaming by default in CLI**: add `--no-penalize-nl` for streaming output
- **GPU detection**: llamafile auto-detects GPU but may fall back to CPU silently — check logs

## Related Skills

- `ollama-integration` — alternative local inference runtime
- `vllm-serving` — production-grade GPU LLM serving
- `litellm-proxy` — unified API gateway for local + cloud models
- `ollama-python-sdk` — programmatic Ollama access

## GitNexus Index

```
tool: llamafile
category: llm-inference
tier: local
interface: openai-compatible
platform: cross-platform
stars: 14000+
```
