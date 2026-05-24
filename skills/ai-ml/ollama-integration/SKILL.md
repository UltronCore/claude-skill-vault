---
name: ollama-integration
description: >
  Local LLM deployment and integration using Ollama. Pull models, run inference, stream responses, use the REST API or ollama Python/JS library. Triggers on: ollama, Ollama, local LLM, llama.cpp, local model, ollama pull, ollama run.
---

# Ollama Integration

## When to Use
- Setting up or using a local LLM with Ollama
- Calling Ollama from Python or JavaScript/TypeScript
- Streaming responses from a local model
- Selecting the right local model for a task
- Deploying Ollama in Docker or as a service
- Writing custom Modelfiles

## Core Rules
1. Always check if Ollama is running (`curl http://localhost:11434`) before making API calls.
2. Use `/api/chat` for multi-turn conversations; use `/api/generate` for single-prompt completion.
3. Always set `stream: false` explicitly if you do NOT want streaming — the default is streaming.
4. Use the OpenAI-compatible endpoint (`/v1/chat/completions`) when swapping Ollama into existing OpenAI code.
5. Pull a model before using it; if a model is missing, the API returns a 404-style error.
6. For production, set `OLLAMA_HOST=0.0.0.0` and handle CORS via a reverse proxy — never expose port 11434 to the public internet.
7. Modelfiles must start with `FROM <base>` and support `SYSTEM`, `TEMPLATE`, `PARAMETER`, and `MESSAGE` directives.
8. Prefer `ollama/ollama` Docker image for containerized setups; mount a named volume for model persistence.
9. Use `num_ctx` parameter to control context window — default is often 2048, increase for document tasks.
10. Embedding models (e.g., `nomic-embed-text`) use `/api/embeddings`, not `/api/chat`.

## CLI Reference

```bash
# Install (macOS)
brew install ollama

# Service management
ollama serve                        # Start server (default port 11434)
OLLAMA_HOST=0.0.0.0 ollama serve    # Bind to all interfaces

# Model management
ollama pull llama3.2                # Pull latest llama3.2
ollama pull llama3.2:3b             # Pull specific variant
ollama pull nomic-embed-text        # Pull embedding model
ollama list                         # List installed models
ollama rm llama3.2                  # Remove a model
ollama show llama3.2                # Show model info/Modelfile

# Run interactively
ollama run llama3.2
ollama run llama3.2 "Explain quantum entanglement in one sentence"

# Inspect running processes
ollama ps                           # Show loaded models
```

## Model Selection Guide

| Task | Recommended Model | Notes |
|------|------------------|-------|
| General chat | `llama3.2:3b` | Fast, good quality |
| Code generation | `qwen2.5-coder:7b` | Best local coding model |
| Long documents | `llama3.1:8b` | 128k context |
| Embeddings | `nomic-embed-text` | 768-dim, fast |
| Reasoning | `deepseek-r1:7b` | Chain-of-thought |
| Vision | `llava:7b` | Image + text |
| Small/fast | `phi3.5:mini` | 3.8B, very quick |
| Large/capable | `llama3.1:70b` | Needs 40GB+ RAM |

## REST API

### /api/generate (single completion)

```python
import requests

response = requests.post("http://localhost:11434/api/generate", json={
    "model": "llama3.2",
    "prompt": "Why is the sky blue?",
    "stream": False,
    "options": {
        "temperature": 0.7,
        "num_ctx": 4096,
        "top_p": 0.9,
    }
})
print(response.json()["response"])
```

### /api/chat (multi-turn)

```python
import requests

response = requests.post("http://localhost:11434/api/chat", json={
    "model": "llama3.2",
    "stream": False,
    "messages": [
        {"role": "system", "content": "You are a helpful assistant."},
        {"role": "user", "content": "What is 2+2?"},
    ]
})
print(response.json()["message"]["content"])
```

### /api/embeddings

```python
import requests

response = requests.post("http://localhost:11434/api/embeddings", json={
    "model": "nomic-embed-text",
    "prompt": "The quick brown fox jumps over the lazy dog"
})
embedding = response.json()["embedding"]  # List[float], 768 dims
```

## Python Library

```python
import ollama

# Simple generation
response = ollama.generate(model="llama3.2", prompt="Hello!")
print(response["response"])

# Chat
response = ollama.chat(
    model="llama3.2",
    messages=[
        {"role": "user", "content": "Write a haiku about Python."}
    ]
)
print(response["message"]["content"])

# Streaming chat
for chunk in ollama.chat(
    model="llama3.2",
    messages=[{"role": "user", "content": "Tell me a story."}],
    stream=True,
):
    print(chunk["message"]["content"], end="", flush=True)

# Embeddings
response = ollama.embeddings(model="nomic-embed-text", prompt="Hello world")
vector = response["embedding"]

# List models
models = ollama.list()
for m in models["models"]:
    print(m["name"], m["size"])

# Pull a model programmatically
ollama.pull("phi3.5:mini")
```

## JavaScript / TypeScript Library

```typescript
import ollama from "ollama";

// Chat (non-streaming)
const response = await ollama.chat({
  model: "llama3.2",
  messages: [{ role: "user", content: "Why is the sky blue?" }],
});
console.log(response.message.content);

// Streaming chat
const stream = await ollama.chat({
  model: "llama3.2",
  messages: [{ role: "user", content: "Write a poem." }],
  stream: true,
});
for await (const chunk of stream) {
  process.stdout.write(chunk.message.content);
}

// Embeddings
const embedRes = await ollama.embeddings({
  model: "nomic-embed-text",
  prompt: "Hello world",
});
const vector: number[] = embedRes.embedding;

// Generate (raw completion)
const genRes = await ollama.generate({
  model: "llama3.2",
  prompt: "def fibonacci(",
  options: { temperature: 0, stop: ["\n\n"] },
});
console.log(genRes.response);
```

## OpenAI-Compatible Endpoint

Ollama exposes `http://localhost:11434/v1` as an OpenAI-compatible API. Drop it into any OpenAI SDK:

```python
from openai import OpenAI

client = OpenAI(
    base_url="http://localhost:11434/v1",
    api_key="ollama",  # Required by client but ignored by Ollama
)

response = client.chat.completions.create(
    model="llama3.2",
    messages=[{"role": "user", "content": "Hello!"}],
)
print(response.choices[0].message.content)
```

```typescript
import OpenAI from "openai";

const client = new OpenAI({
  baseURL: "http://localhost:11434/v1",
  apiKey: "ollama",
});

const response = await client.chat.completions.create({
  model: "llama3.2",
  messages: [{ role: "user", content: "Hello!" }],
});
console.log(response.choices[0].message.content);
```

## Custom Modelfiles

```dockerfile
# Modelfile: create a custom persona
FROM llama3.2

SYSTEM """
You are a senior iOS developer specializing in SwiftUI and Combine.
Always prefer Swift concurrency (async/await) over callbacks.
"""

PARAMETER temperature 0.3
PARAMETER num_ctx 8192
PARAMETER stop "<|eot_id|>"

# Build and use:
# ollama create swift-dev -f Modelfile
# ollama run swift-dev
```

```dockerfile
# Modelfile: code completion model with low temperature
FROM qwen2.5-coder:7b

PARAMETER temperature 0.1
PARAMETER top_p 0.9
PARAMETER num_ctx 16384
PARAMETER repeat_penalty 1.1
```

## Docker Deployment

```yaml
# docker-compose.yml
services:
  ollama:
    image: ollama/ollama:latest
    ports:
      - "11434:11434"
    volumes:
      - ollama_data:/root/.ollama
    environment:
      - OLLAMA_HOST=0.0.0.0
    # GPU support (NVIDIA):
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]

volumes:
  ollama_data:
```

```bash
# Pull model after container starts
docker exec -it <container_id> ollama pull llama3.2

# Or use an entrypoint script
docker exec -it <container_id> bash -c "ollama pull llama3.2 && ollama pull nomic-embed-text"
```

## Streaming with Error Handling (Python)

```python
import requests
import json

def stream_ollama(prompt: str, model: str = "llama3.2") -> str:
    """Stream response from Ollama, return full text."""
    full_response = ""
    try:
        with requests.post(
            "http://localhost:11434/api/generate",
            json={"model": model, "prompt": prompt, "stream": True},
            stream=True,
            timeout=60,
        ) as resp:
            resp.raise_for_status()
            for line in resp.iter_lines():
                if line:
                    data = json.loads(line)
                    token = data.get("response", "")
                    full_response += token
                    print(token, end="", flush=True)
                    if data.get("done"):
                        break
    except requests.exceptions.ConnectionError:
        raise RuntimeError("Ollama is not running. Start with: ollama serve")
    print()  # newline after stream
    return full_response
```

## Health Check & Model Availability

```python
import requests

def is_ollama_available(model: str = None) -> bool:
    try:
        r = requests.get("http://localhost:11434/api/tags", timeout=2)
        if r.status_code != 200:
            return False
        if model:
            models = [m["name"] for m in r.json().get("models", [])]
            return any(m.startswith(model.split(":")[0]) for m in models)
        return True
    except requests.exceptions.ConnectionError:
        return False

# Usage
if not is_ollama_available("llama3.2"):
    print("Run: ollama pull llama3.2")
```

## Environment Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `OLLAMA_HOST` | `127.0.0.1:11434` | Bind address |
| `OLLAMA_MODELS` | `~/.ollama/models` | Model storage path |
| `OLLAMA_NUM_PARALLEL` | `1` | Concurrent requests |
| `OLLAMA_MAX_LOADED_MODELS` | `1` | Models in VRAM |
| `OLLAMA_KEEP_ALIVE` | `5m` | How long to keep model loaded |
| `OLLAMA_DEBUG` | `0` | Enable debug logging |

## GitNexus Index
This skill is indexed by GitNexus for knowledge graph traversal.
Index path: /Users/localuser/claude-skill-vault/skills/ai-ml/ollama-integration/.gitnexus
Last indexed: 2026-05-23
