---
name: openrouter-litellm
description: >
  Multi-provider LLM routing with OpenRouter and LiteLLM for unified API access and fallbacks. Triggers on: OpenRouter, LiteLLM, litellm, openrouter, OPENROUTER_API_KEY, model routing, LLM fallback.
---

# OpenRouter & LiteLLM

## When to Use
- Accessing many LLM providers through one API (OpenRouter)
- Dropping OpenRouter/LiteLLM into existing OpenAI SDK code
- Setting up automatic fallbacks when a model is down or rate-limited
- Tracking per-model costs across providers
- Using free-tier models for prototyping
- Running a local LiteLLM proxy for your team

## Core Rules
1. OpenRouter is OpenAI-API-compatible — use the OpenAI SDK, just change `base_url` and `api_key`.
2. OpenRouter model names follow `provider/model-name` format (e.g., `anthropic/claude-opus-4-5`).
3. LiteLLM uses `provider/model` prefix notation in code (e.g., `anthropic/claude-opus-4-5`).
4. Always set `HTTP-Referer` and `X-Title` headers on OpenRouter — helps with rate limits and debugging.
5. For fallbacks with LiteLLM, define a fallback list ordered by preference (best model first).
6. Free-tier OpenRouter models have strict rate limits — use them only for development/testing.
7. LiteLLM proxy lets you set `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, etc. server-side so clients only need one key.
8. Use `litellm.completion()` for simple scripts; use the LiteLLM proxy for production multi-user setups.
9. OpenRouter charges in credits — set a monthly budget cap in the dashboard to avoid surprises.
10. For cost tracking, use LiteLLM's built-in logging; for OpenRouter, check the `/api/v1/generation` endpoint.

## OpenRouter Setup

```bash
# Install
pip install openai  # OpenRouter uses the OpenAI SDK

# Set API key
export OPENROUTER_API_KEY="sk-or-v1-..."
```

## OpenRouter with OpenAI SDK (Python)

```python
from openai import OpenAI

client = OpenAI(
    base_url="https://openrouter.ai/api/v1",
    api_key="sk-or-v1-...",  # Or use os.environ["OPENROUTER_API_KEY"]
)

response = client.chat.completions.create(
    model="anthropic/claude-opus-4-5",
    messages=[{"role": "user", "content": "What is the capital of France?"}],
    extra_headers={
        "HTTP-Referer": "https://yourapp.com",  # Required for rate limiting
        "X-Title": "My App Name",
    },
)
print(response.choices[0].message.content)
```

## OpenRouter with OpenAI SDK (TypeScript)

```typescript
import OpenAI from "openai";

const client = new OpenAI({
  baseURL: "https://openrouter.ai/api/v1",
  apiKey: process.env.OPENROUTER_API_KEY,
  defaultHeaders: {
    "HTTP-Referer": "https://yourapp.com",
    "X-Title": "My App Name",
  },
});

async function chat(userMessage: string, model = "anthropic/claude-opus-4-5") {
  const response = await client.chat.completions.create({
    model,
    messages: [{ role: "user", content: userMessage }],
  });
  return response.choices[0].message.content;
}

// Streaming
async function streamChat(userMessage: string) {
  const stream = await client.chat.completions.create({
    model: "anthropic/claude-opus-4-5",
    messages: [{ role: "user", content: userMessage }],
    stream: true,
  });

  for await (const chunk of stream) {
    process.stdout.write(chunk.choices[0]?.delta?.content ?? "");
  }
}
```

## OpenRouter Model List

```python
import requests, os

def list_openrouter_models(free_only: bool = False) -> list[dict]:
    """Fetch available models from OpenRouter."""
    response = requests.get(
        "https://openrouter.ai/api/v1/models",
        headers={"Authorization": f"Bearer {os.environ['OPENROUTER_API_KEY']}"},
    )
    models = response.json()["data"]
    if free_only:
        models = [m for m in models if ":free" in m["id"] or m.get("pricing", {}).get("prompt") == "0"]
    return sorted(models, key=lambda m: m["id"])

# Print free models
for m in list_openrouter_models(free_only=True):
    print(f"{m['id']} — context: {m.get('context_length', '?')} tokens")
```

## Popular OpenRouter Models

| Model ID | Provider | Notes |
|----------|----------|-------|
| `anthropic/claude-opus-4-5` | Anthropic | Best reasoning |
| `anthropic/claude-sonnet-4-5` | Anthropic | Balanced |
| `anthropic/claude-haiku-4-5` | Anthropic | Fast/cheap |
| `openai/gpt-4o` | OpenAI | Multimodal |
| `openai/gpt-4o-mini` | OpenAI | Cheap |
| `google/gemini-2.5-pro` | Google | Long context |
| `meta-llama/llama-3.3-70b-instruct` | Meta | Open source |
| `mistralai/mistral-7b-instruct` | Mistral | Small/fast |
| `meta-llama/llama-3.1-8b-instruct:free` | Meta | Free tier |
| `google/gemma-3-9b-it:free` | Google | Free tier |

## LiteLLM Setup

```bash
pip install litellm

# For the proxy server
pip install 'litellm[proxy]'

# Required API keys (set what you need)
export ANTHROPIC_API_KEY="sk-ant-..."
export OPENAI_API_KEY="sk-..."
export OPENROUTER_API_KEY="sk-or-..."
export COHERE_API_KEY="..."
```

## LiteLLM Basic Usage (Python)

```python
import litellm
import os

# litellm uses provider/model prefix
# Provider prefixes: openai/, anthropic/, ollama/, openrouter/, cohere/, etc.

# Claude via Anthropic
response = litellm.completion(
    model="anthropic/claude-opus-4-5",
    messages=[{"role": "user", "content": "Hello!"}],
    api_key=os.environ["ANTHROPIC_API_KEY"],
)
print(response.choices[0].message.content)

# GPT-4 via OpenAI
response = litellm.completion(
    model="openai/gpt-4o",
    messages=[{"role": "user", "content": "Hello!"}],
)
print(response.choices[0].message.content)

# Local Ollama model
response = litellm.completion(
    model="ollama/llama3.2",
    messages=[{"role": "user", "content": "Hello!"}],
    api_base="http://localhost:11434",
)
print(response.choices[0].message.content)

# Via OpenRouter
response = litellm.completion(
    model="openrouter/anthropic/claude-opus-4-5",
    messages=[{"role": "user", "content": "Hello!"}],
    api_key=os.environ["OPENROUTER_API_KEY"],
)
```

## LiteLLM Fallback Routing

```python
import litellm

litellm.set_verbose = False  # Set True for debugging

def chat_with_fallback(message: str) -> str:
    """Try models in order, fall back on errors."""
    response = litellm.completion(
        model="anthropic/claude-opus-4-5",
        messages=[{"role": "user", "content": message}],
        fallbacks=[
            "anthropic/claude-sonnet-4-5",    # First fallback
            "openai/gpt-4o",                   # Second fallback
            "openai/gpt-4o-mini",              # Last resort
        ],
        num_retries=2,
        timeout=30,
    )
    return response.choices[0].message.content

# With context window fallback (automatically downgrades when context is too large)
response = litellm.completion(
    model="anthropic/claude-haiku-4-5",
    messages=long_messages,
    context_window_fallback_dict={
        "anthropic/claude-haiku-4-5": "anthropic/claude-sonnet-4-5",
        "anthropic/claude-sonnet-4-5": "anthropic/claude-opus-4-5",
    },
)
```

## LiteLLM Router (Production)

```python
from litellm import Router

router = Router(
    model_list=[
        {
            "model_name": "claude",  # Alias used in your code
            "litellm_params": {
                "model": "anthropic/claude-opus-4-5",
                "api_key": os.environ["ANTHROPIC_API_KEY"],
            },
        },
        {
            "model_name": "claude",
            "litellm_params": {
                "model": "openrouter/anthropic/claude-opus-4-5",
                "api_key": os.environ["OPENROUTER_API_KEY"],
            },
        },
        {
            "model_name": "cheap",
            "litellm_params": {
                "model": "anthropic/claude-haiku-4-5",
                "api_key": os.environ["ANTHROPIC_API_KEY"],
            },
        },
    ],
    routing_strategy="least-busy",  # Options: simple-shuffle, least-busy, latency-based
    fallbacks=[{"claude": ["cheap"]}],  # If "claude" fails, try "cheap"
    num_retries=3,
    timeout=60,
    retry_after=5,
)

# Use the alias in your code
response = router.completion(
    model="claude",
    messages=[{"role": "user", "content": "Hello!"}],
)
```

## LiteLLM Proxy Server

```yaml
# litellm_config.yaml
model_list:
  - model_name: claude-opus
    litellm_params:
      model: anthropic/claude-opus-4-5
      api_key: os.environ/ANTHROPIC_API_KEY

  - model_name: gpt-4o
    litellm_params:
      model: openai/gpt-4o
      api_key: os.environ/OPENAI_API_KEY

  - model_name: local-llama
    litellm_params:
      model: ollama/llama3.2
      api_base: http://localhost:11434

litellm_settings:
  success_callback: ["langfuse"]  # Optional observability
  failure_callback: ["langfuse"]
  num_retries: 3
  request_timeout: 60
  fallbacks:
    - {"claude-opus": ["gpt-4o"]}

general_settings:
  master_key: "sk-my-master-key"  # Clients use this key
```

```bash
# Start the proxy
litellm --config litellm_config.yaml --port 8000

# Now clients connect to localhost:8000 with any OpenAI SDK
```

## Connecting to LiteLLM Proxy (Any Language)

```python
from openai import OpenAI

# Drop-in replacement for OpenAI client
client = OpenAI(
    base_url="http://localhost:8000",
    api_key="sk-my-master-key",
)

response = client.chat.completions.create(
    model="claude-opus",  # Uses the alias from litellm_config.yaml
    messages=[{"role": "user", "content": "Hello!"}],
)
```

```typescript
import OpenAI from "openai";

const client = new OpenAI({
  baseURL: "http://localhost:8000",
  apiKey: "sk-my-master-key",
});

const response = await client.chat.completions.create({
  model: "claude-opus",
  messages: [{ role: "user", content: "Hello!" }],
});
```

## Cost Tracking with LiteLLM

```python
import litellm

litellm.success_callback = ["langfuse"]  # Or "lunary", "helicone", etc.

# Get cost after a call
response = litellm.completion(
    model="anthropic/claude-opus-4-5",
    messages=[{"role": "user", "content": "Hello!"}],
)
cost = litellm.completion_cost(completion_response=response)
print(f"Cost: ${cost:.6f}")

# Track cumulative cost
from litellm import Budget

budget = Budget(max_budget=1.0)  # $1 USD limit
litellm.set_verbose = False

try:
    response = litellm.completion(
        model="anthropic/claude-opus-4-5",
        messages=[{"role": "user", "content": "Tell me a story."}],
    )
except litellm.BudgetExceededError as e:
    print(f"Budget exceeded: {e}")
```

## Rate Limit Handling

```python
import litellm
import time

def completion_with_retry(
    model: str,
    messages: list[dict],
    max_retries: int = 3,
    initial_delay: float = 1.0,
) -> str:
    for attempt in range(max_retries):
        try:
            response = litellm.completion(
                model=model,
                messages=messages,
                num_retries=0,  # Handle manually
            )
            return response.choices[0].message.content
        except litellm.RateLimitError as e:
            if attempt == max_retries - 1:
                raise
            wait = initial_delay * (2 ** attempt)  # Exponential backoff
            print(f"Rate limited. Waiting {wait}s...")
            time.sleep(wait)
        except litellm.APIConnectionError:
            if attempt == max_retries - 1:
                raise
            time.sleep(initial_delay)
    raise RuntimeError("All retries failed")
```

## OpenRouter Cost Check

```python
import requests, os

def get_generation_cost(generation_id: str) -> dict:
    """Get cost for a specific OpenRouter generation."""
    response = requests.get(
        f"https://openrouter.ai/api/v1/generation?id={generation_id}",
        headers={"Authorization": f"Bearer {os.environ['OPENROUTER_API_KEY']}"},
    )
    return response.json()

# The generation ID is in the response header or response body
response = client.chat.completions.create(
    model="anthropic/claude-opus-4-5",
    messages=[{"role": "user", "content": "Hello!"}],
)
# response.id contains the generation ID on OpenRouter
cost_info = get_generation_cost(response.id)
print(f"Cost: ${cost_info['data']['total_cost']}")
```

## Model Selection Helper

```python
def select_model(
    task: str,
    prefer_free: bool = False,
    provider: str = "openrouter",
) -> str:
    """Select an appropriate model for the task."""
    if prefer_free:
        free_models = {
            "chat": "openrouter/meta-llama/llama-3.1-8b-instruct:free",
            "code": "openrouter/google/gemma-3-9b-it:free",
            "default": "openrouter/meta-llama/llama-3.1-8b-instruct:free",
        }
        return free_models.get(task, free_models["default"])

    paid_models = {
        "chat": "anthropic/claude-sonnet-4-5",
        "code": "anthropic/claude-opus-4-5",
        "fast": "anthropic/claude-haiku-4-5",
        "vision": "openai/gpt-4o",
        "long_context": "google/gemini-2.5-pro",
        "default": "anthropic/claude-sonnet-4-5",
    }
    model = paid_models.get(task, paid_models["default"])
    if provider == "openrouter":
        return f"openrouter/{model}"
    return model
```

## Related Skills
- `llm-routing-and-fallback` — model routing
- `ai-cost-optimizer` — cost optimization
- `ollama-integration` — local model routing

## GitNexus Index
This skill is indexed by GitNexus for knowledge graph traversal.
Index path: /Users/localuser/.claude/skills/openrouter-litellm/.gitnexus
Last indexed: 2026-05-23
