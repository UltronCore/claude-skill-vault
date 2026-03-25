---
name: llm-routing-and-fallback
description: Route LLM API calls through cost-efficient proxy layers with automatic model fallback, budget caps, and retry logic. Use when building systems that need to switch between Claude models, fall back from expensive to cheaper models, or unify multiple LLM providers behind one interface. Trigger when users mention litellm, model routing, API cost reduction, model fallback, or budget-aware inference.
---

# LLM Routing and Fallback

When building Claude Code skills or automation that calls LLM APIs, routing through a proxy layer reduces cost, adds reliability, and enables model switching without code changes.

## Core patterns

### Pattern 1: litellm unified interface
litellm provides an OpenAI-compatible interface for 100+ LLMs. Claude calls look identical to GPT calls at the code level.

```python
import litellm

# Route to Claude
response = litellm.completion(
    model="anthropic/claude-sonnet-4-6",
    messages=[{"role": "user", "content": "Hello"}]
)

# Fallback: if claude fails, try gpt-4o
response = litellm.completion(
    model="anthropic/claude-sonnet-4-6",
    messages=[{"role": "user", "content": "Hello"}],
    fallbacks=["openai/gpt-4o"]
)
```

### Pattern 2: Budget caps
```python
import litellm
litellm.max_budget = 0.50  # $0.50 cap per run

response = litellm.completion(
    model="anthropic/claude-haiku-4-5-20251001",  # cheapest first
    messages=[{"role": "user", "content": prompt}]
)
```

### Pattern 3: Model tiering
Route by task complexity:
- Simple tasks → claude-haiku (cheapest)
- Standard tasks → claude-sonnet
- Complex/creative → claude-opus (only when justified)

```python
def route_by_complexity(prompt: str, complexity: str) -> str:
    models = {
        "simple": "anthropic/claude-haiku-4-5-20251001",
        "standard": "anthropic/claude-sonnet-4-6",
        "intensive": "anthropic/claude-opus-4-6"
    }
    return litellm.completion(
        model=models[complexity],
        messages=[{"role": "user", "content": prompt}]
    ).choices[0].message.content
```

### Pattern 4: Vercel AI SDK (TypeScript)
```typescript
import { anthropic } from "@ai-sdk/anthropic";
import { generateText } from "ai";

const { text } = await generateText({
    model: anthropic("claude-sonnet-4-6"),
    prompt: "Hello",
    maxRetries: 3,
});
```

## When to use each pattern
- Building a tool that should work across multiple LLM providers → Pattern 1
- Enforcing API spend limits → Pattern 2
- Optimizing cost by routing based on task complexity → Pattern 3 + claude-usage-orchestrator
- Building TypeScript/Next.js skills → Pattern 4

## Related skills
- claude-usage-orchestrator (routing decisions)
- sentry-and-otel-setup (observability for LLM calls)
