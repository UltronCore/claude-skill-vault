---
name: ollama-python-sdk
description: Programmatic local LLM usage via the official Ollama Python SDK
version: 1.0.0
tags: [llm, ollama, local, python, sdk, inference]
---

# Ollama Python SDK — Programmatic Local LLM Usage

## Overview

The official Ollama Python library (`ollama`) provides a clean, typed interface to the Ollama REST API, enabling programmatic access to locally running LLMs. Supports synchronous and async clients, streaming, embeddings, model management, and multimodal inputs. Essential for building Python applications that use local LLMs without GPU cloud costs.

GitHub: https://github.com/ollama/ollama-python (5k+ stars)

## When to Use

- Building Python apps backed by local LLMs
- Streaming chat interfaces in Python
- Generating embeddings locally for RAG pipelines
- Managing Ollama models programmatically (pull, delete, list)
- Multimodal (vision) tasks with local models like LLaVA
- Async Python apps (FastAPI, async pipelines)

## Installation

```bash
pip install ollama

# Ollama server must be running
ollama serve  # or start Ollama.app on macOS
```

## Key Patterns / Usage

### Basic Chat Completion
```python
import ollama

response = ollama.chat(
    model="llama3.2",
    messages=[
        {"role": "user", "content": "Why is the sky blue?"}
    ]
)
print(response.message.content)
```

### Streaming Response
```python
import ollama

stream = ollama.chat(
    model="llama3.2",
    messages=[{"role": "user", "content": "Write a short story"}],
    stream=True,
)

for chunk in stream:
    print(chunk.message.content, end="", flush=True)
print()
```

### Async Client
```python
import asyncio
import ollama

async def main():
    client = ollama.AsyncClient()
    response = await client.chat(
        model="llama3.2",
        messages=[{"role": "user", "content": "Hello!"}],
    )
    print(response.message.content)

    # Async streaming
    async for chunk in await client.chat(
        model="llama3.2",
        messages=[{"role": "user", "content": "Count to 5"}],
        stream=True,
    ):
        print(chunk.message.content, end="", flush=True)

asyncio.run(main())
```

### Generate Embeddings
```python
import ollama

response = ollama.embeddings(
    model="nomic-embed-text",
    prompt="The quick brown fox",
)
embedding_vector = response.embedding
print(f"Embedding dim: {len(embedding_vector)}")

# Batch embeddings
texts = ["Hello world", "Foo bar", "AI is cool"]
embeddings = [
    ollama.embeddings(model="nomic-embed-text", prompt=t).embedding
    for t in texts
]
```

### Model Management
```python
import ollama

# Pull a model
ollama.pull("llama3.2")

# List local models
models = ollama.list()
for model in models.models:
    print(model.model, model.size)

# Delete a model
ollama.delete("llama3.2")

# Copy model
ollama.copy("llama3.2", "my-llama3")

# Show model info
info = ollama.show("llama3.2")
print(info.modelfile)
```

### Multimodal (Vision) Input
```python
import ollama
import base64
from pathlib import Path

# Pass image as file path (SDK handles encoding)
response = ollama.chat(
    model="llava",
    messages=[{
        "role": "user",
        "content": "Describe this image",
        "images": ["/path/to/image.png"],
    }],
)
print(response.message.content)
```

### Custom Client with Options
```python
from ollama import Client

client = Client(host="http://192.168.1.100:11434")

response = client.chat(
    model="llama3.2",
    messages=[{"role": "user", "content": "Hello"}],
    options={
        "temperature": 0.7,
        "top_p": 0.9,
        "num_ctx": 4096,
        "num_predict": 512,
    },
)
```

### Structured Output with Tools
```python
import ollama
import json

tools = [{
    "type": "function",
    "function": {
        "name": "get_weather",
        "description": "Get current weather",
        "parameters": {
            "type": "object",
            "properties": {"location": {"type": "string"}},
            "required": ["location"],
        },
    },
}]

response = ollama.chat(
    model="llama3.2",
    messages=[{"role": "user", "content": "What's the weather in Paris?"}],
    tools=tools,
)

if response.message.tool_calls:
    for tool_call in response.message.tool_calls:
        print(f"Tool: {tool_call.function.name}")
        print(f"Args: {tool_call.function.arguments}")
```

## Common Pitfalls

- **Ollama not running**: ensure `ollama serve` is running or Ollama app is open before SDK calls
- **Model not pulled**: call `ollama.pull("model-name")` before first use
- **Large context**: default context window varies by model; pass `num_ctx` in options
- **Slow first response**: first inference "loads" the model into memory — subsequent calls are faster
- **Async mixing**: don't mix sync `ollama` calls inside `async` functions; use `AsyncClient`
- **Embedding model**: chat models cannot generate embeddings — use `nomic-embed-text` or `mxbai-embed-large`

## Related Skills

- `ollama-integration` — broader Ollama setup and configuration
- `llamafile` — alternative portable local inference
- `vllm-serving` — production GPU serving
- `rag-pipeline` — using embeddings in RAG systems
- `litellm-proxy` — unified proxy supporting Ollama as a backend

## GitNexus Index

```
tool: ollama-python-sdk
category: llm-client
tier: local
interface: python-sdk
platform: cross-platform
stars: 5000+
```
