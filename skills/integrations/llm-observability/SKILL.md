---
name: llm-observability
description: Add observability, tracing, and monitoring to Claude Code skill executions. Track prompt versions, response quality, latency, and costs across runs. Use when building production Claude workflows that need debugging, performance tracking, or A/B testing of prompts. Trigger when users mention LLM observability, langfuse, prompt tracing, agentops, mlflow, or monitoring Claude calls.
---

# LLM Observability

Track what Claude does in production — prompts, responses, latency, costs, and quality scores.

## Langfuse (open-source, self-hostable)
```python
pip install langfuse anthropic

from langfuse import Langfuse
from langfuse.decorators import observe, langfuse_context
import anthropic

langfuse = Langfuse(
    public_key="pk-...",
    secret_key="sk-...",
    host="https://cloud.langfuse.com"
)

@observe()  # automatically traces this function
def call_claude(prompt: str) -> str:
    client = anthropic.Anthropic()
    response = client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=1024,
        messages=[{"role": "user", "content": prompt}]
    )
    return response.content[0].text

result = call_claude("Explain RAG in one sentence")
langfuse.flush()
# View trace at cloud.langfuse.com
```

## AgentOps (agent-focused monitoring)
```python
pip install agentops anthropic

import agentops
import anthropic

agentops.init(api_key="your_key")

@agentops.record_action("claude_call")
def call_claude(prompt: str) -> str:
    client = anthropic.Anthropic()
    response = client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=1024,
        messages=[{"role": "user", "content": prompt}]
    )
    agentops.end_session("Success")
    return response.content[0].text
```

## MLflow (experiment tracking)
Best for: tracking prompt experiments, comparing versions
```python
pip install mlflow anthropic

import mlflow

with mlflow.start_run():
    mlflow.log_param("model", "claude-sonnet-4-6")
    mlflow.log_param("prompt_version", "v3")

    response = call_claude(prompt)

    mlflow.log_metric("response_length", len(response))
    mlflow.log_metric("latency_ms", elapsed_ms)
    mlflow.log_text(response, "response.txt")
```

## Minimal DIY tracing (no extra deps)
```python
import time, json
from pathlib import Path

def traced_call(prompt: str, run_id: str) -> str:
    start = time.time()
    result = call_claude(prompt)
    elapsed = time.time() - start

    trace = {
        "run_id": run_id,
        "prompt": prompt[:200],
        "response": result[:200],
        "latency_ms": round(elapsed * 1000),
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ")
    }
    Path("traces.jsonl").open("a").write(json.dumps(trace) + "\n")
    return result
```

## What to track
- Prompt version + content hash
- Model used + temperature
- Latency per call
- Token counts (input + output)
- Pass/fail on output validation
- User feedback when available

## Related skills
sentry-and-otel-setup, claude-usage-orchestrator
