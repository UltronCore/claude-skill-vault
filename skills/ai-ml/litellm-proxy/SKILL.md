---
name: litellm-proxy
description: Deploy LiteLLM as a unified OpenAI-compatible API gateway for 100+ LLM providers
version: 1.0.0
tags: [llm, proxy, gateway, api, openai-compatible, load-balancing]
---

# LiteLLM Proxy — Unified LLM API Gateway

## Overview

LiteLLM Proxy is a standalone OpenAI-compatible API server that routes requests to 100+ LLM providers (OpenAI, Anthropic, Bedrock, Azure, Ollama, Groq, etc.) with unified credentials, load balancing, rate limiting, cost tracking, and caching. Run it as a Docker container or Python process — teams point their existing OpenAI SDK code at it and swap models without code changes.

GitHub: https://github.com/BerriAI/litellm (15k+ stars)

## When to Use

- Multi-provider LLM routing with a single API key for your team
- Cost tracking and budget enforcement across LLM providers
- A/B testing between models without changing application code
- Load balancing across multiple API keys or provider accounts
- Adding caching, logging, or guardrails in front of any LLM
- Migrating from OpenAI to another provider transparently

## Installation

```bash
# Install LiteLLM
pip install litellm[proxy]

# Or via Docker
docker pull ghcr.io/berriai/litellm:main-latest
```

## Key Patterns / Usage

### Quick Start — Config File
```yaml
# litellm_config.yaml
model_list:
  - model_name: gpt-4o
    litellm_params:
      model: openai/gpt-4o
      api_key: os.environ/OPENAI_API_KEY

  - model_name: claude-3-5-sonnet
    litellm_params:
      model: anthropic/claude-3-5-sonnet-20241022
      api_key: os.environ/ANTHROPIC_API_KEY

  - model_name: local-llama
    litellm_params:
      model: ollama/llama3.2
      api_base: http://localhost:11434

general_settings:
  master_key: sk-my-master-key
  database_url: os.environ/DATABASE_URL  # optional, for persistence
```

```bash
# Start the proxy
litellm --config litellm_config.yaml --port 4000

# Or Docker
docker run -v $(pwd)/litellm_config.yaml:/app/config.yaml \
  -e OPENAI_API_KEY=$OPENAI_API_KEY \
  -p 4000:4000 ghcr.io/berriai/litellm:main-latest \
  --config /app/config.yaml
```

### Client Usage (OpenAI SDK)
```python
from openai import OpenAI

# Point at LiteLLM proxy
client = OpenAI(
    base_url="http://localhost:4000",
    api_key="sk-my-master-key",
)

# Use any model name from your config
response = client.chat.completions.create(
    model="claude-3-5-sonnet",  # routes to Anthropic
    messages=[{"role": "user", "content": "Hello!"}],
)
print(response.choices[0].message.content)
```

### Load Balancing + Fallbacks
```yaml
model_list:
  - model_name: gpt-4o
    litellm_params:
      model: openai/gpt-4o
      api_key: os.environ/OPENAI_API_KEY_1

  - model_name: gpt-4o
    litellm_params:
      model: openai/gpt-4o
      api_key: os.environ/OPENAI_API_KEY_2  # second key = load balanced

router_settings:
  routing_strategy: least-busy
  fallbacks: [{"gpt-4o": ["claude-3-5-sonnet"]}]
  context_window_fallbacks: [{"gpt-4o": ["gpt-4o-mini"]}]
  num_retries: 3
  timeout: 30
```

### Rate Limiting and Budgets
```yaml
general_settings:
  master_key: sk-master

litellm_settings:
  max_budget: 100  # $100 total budget

# Per-key budgets via API
# POST /key/generate
# {"max_budget": 10, "models": ["gpt-4o"], "duration": "30d"}
```

```python
import httpx

# Generate a virtual key with budget
resp = httpx.post(
    "http://localhost:4000/key/generate",
    headers={"Authorization": "Bearer sk-master"},
    json={"max_budget": 5.0, "models": ["gpt-4o-mini"], "duration": "7d"},
)
virtual_key = resp.json()["key"]
print(f"Team key: {virtual_key}")
```

### Caching
```yaml
litellm_settings:
  cache: true
  cache_params:
    type: redis
    host: localhost
    port: 6379
    ttl: 600  # seconds

  # Or in-memory
  cache_params:
    type: local
```

### Logging and Observability
```yaml
litellm_settings:
  success_callback: ["langfuse", "helicone"]
  failure_callback: ["sentry"]

  langfuse_public_key: os.environ/LANGFUSE_PUBLIC_KEY
  langfuse_secret_key: os.environ/LANGFUSE_SECRET_KEY
```

### Guardrails
```yaml
litellm_settings:
  guardrails:
    - guardrail_name: "pii-guard"
      litellm_params:
        guardrail: presidio
        mode: pre_call  # mask PII before sending to LLM
```

## Common Pitfalls

- **Master key required**: always set `master_key` in config; without it anyone can hit your proxy
- **Model name mismatch**: the `model_name` in config is what clients use, not the provider's actual model name
- **Environment variables**: use `os.environ/VAR_NAME` syntax in YAML config (not `$VAR_NAME`)
- **Docker networking**: when Ollama runs on host, use `host.docker.internal` not `localhost`
- **Cost tracking needs DB**: spend tracking requires a PostgreSQL `database_url` in general_settings
- **Streaming proxying**: streaming works but ensure your client handles SSE properly

## Related Skills

- `openrouter-litellm` — using LiteLLM Python library (not proxy) with OpenRouter
- `ollama-integration` — running local models behind the proxy
- `llm-routing-and-fallback` — routing and fallback strategies
- `api-rate-limiting` — rate limiting patterns
- `llm-observability` — observability for LLM applications

## GitNexus Index

```
tool: litellm-proxy
category: llm-gateway
tier: self-hosted
interface: openai-compatible
platform: cross-platform
stars: 15000+
```
