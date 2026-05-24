---
name: ai-cost-optimizer
description: >
  LLM cost reduction: prompt caching, model routing, token optimization, and batching. Triggers on: prompt caching, cache_control, token budget, cost optimization, batch API, model routing, input tokens.
---

# AI Cost Optimizer

## When to Use
- Adding prompt caching to reduce repeated system prompt costs
- Choosing the right model tier for a task (Haiku vs Sonnet vs Opus)
- Using the Batch API for offline/async workloads
- Counting tokens before sending a request
- Truncating conversation history to fit a budget
- Estimating API costs before running a pipeline

## Core Rules
1. Always cache system prompts and static context — they're re-sent every turn and caching cuts that cost by ~90%.
2. `cache_control: {type: "ephemeral"}` requires a minimum of 1024 tokens to actually cache.
3. Cached tokens cost ~10% of normal input price; first-fill costs ~25% more but is amortized quickly.
4. Use `claude-haiku-4-5` for classification, routing, extraction, and simple Q&A — it's 10-30x cheaper than Opus.
5. Use the Batch API for any workload that can wait up to 24 hours — it's 50% cheaper than the sync API.
6. Count tokens with `client.messages.count_tokens()` before running expensive pipelines.
7. Truncate conversation history from the middle, not the end — preserve system context and recent messages.
8. Set `max_tokens` to the actual expected output length — you pay for capacity, not unused tokens.
9. For RAG, retrieve only the top-K most relevant chunks; don't stuff the full document into context.
10. Cache the large/static part of the prompt at the top; dynamic content goes at the bottom (cache reads are positional from the top).

## Pricing Reference (approximate, check anthropic.com for latest)

| Model | Input (per 1M) | Output (per 1M) | Cache Write | Cache Read |
|-------|---------------|-----------------|-------------|------------|
| claude-haiku-4-5 | $0.80 | $4.00 | $1.00 | $0.08 |
| claude-sonnet-4-5 | $3.00 | $15.00 | $3.75 | $0.30 |
| claude-opus-4-5 | $15.00 | $75.00 | $18.75 | $1.50 |

## Prompt Caching (Python)

```python
import anthropic

client = anthropic.Anthropic()

LARGE_DOCUMENT = "..." * 500  # 1000+ tokens of static content

response = client.messages.create(
    model="claude-opus-4-5",
    max_tokens=1024,
    system=[
        {
            "type": "text",
            "text": "You are an expert document analyst. Answer questions precisely.",
        },
        {
            "type": "text",
            "text": LARGE_DOCUMENT,
            "cache_control": {"type": "ephemeral"},  # Cache this block
        },
    ],
    messages=[{"role": "user", "content": "What are the main themes?"}],
)

# Check cache performance
usage = response.usage
print(f"Input tokens: {usage.input_tokens}")
print(f"Cache creation: {getattr(usage, 'cache_creation_input_tokens', 0)}")
print(f"Cache read: {getattr(usage, 'cache_read_input_tokens', 0)}")

# Second request — cache_read_input_tokens will be high
response2 = client.messages.create(
    model="claude-opus-4-5",
    max_tokens=1024,
    system=[
        {"type": "text", "text": "You are an expert document analyst."},
        {
            "type": "text",
            "text": LARGE_DOCUMENT,
            "cache_control": {"type": "ephemeral"},  # Same block = cache hit
        },
    ],
    messages=[{"role": "user", "content": "Who are the key stakeholders?"}],
)
```

## Prompt Caching (TypeScript)

```typescript
import Anthropic from "@anthropic-ai/sdk";

const client = new Anthropic();

const STATIC_CONTEXT = "...".repeat(300); // Must be 1024+ tokens

async function askWithCache(question: string) {
  const response = await client.messages.create({
    model: "claude-opus-4-5",
    max_tokens: 1024,
    system: [
      {
        type: "text",
        text: "You are a helpful assistant. Answer concisely.",
      },
      {
        type: "text",
        text: STATIC_CONTEXT,
        // @ts-ignore — cache_control is a beta field
        cache_control: { type: "ephemeral" },
      },
    ] as Anthropic.TextBlockParam[],
    messages: [{ role: "user", content: question }],
  });

  const usage = response.usage as Anthropic.Usage & {
    cache_creation_input_tokens?: number;
    cache_read_input_tokens?: number;
  };

  console.log(`Cache hit: ${usage.cache_read_input_tokens ?? 0} tokens`);
  return (response.content[0] as Anthropic.TextBlock).text;
}
```

## Caching Conversation History

```python
def chat_with_cached_history(messages: list[dict], new_message: str) -> str:
    """Cache the conversation history, only pay full price for the new message."""
    # Mark the last message in history for caching
    cached_messages = []
    for i, msg in enumerate(messages):
        if i == len(messages) - 1:
            # Cache the last historical message
            content = msg["content"]
            if isinstance(content, str):
                content = [{"type": "text", "text": content, "cache_control": {"type": "ephemeral"}}]
            cached_messages.append({"role": msg["role"], "content": content})
        else:
            cached_messages.append(msg)

    cached_messages.append({"role": "user", "content": new_message})

    response = client.messages.create(
        model="claude-opus-4-5",
        max_tokens=1024,
        messages=cached_messages,
    )
    return response.content[0].text
```

## Token Counting

```python
import anthropic

client = anthropic.Anthropic()

# Count tokens before sending
messages = [{"role": "user", "content": "Explain quantum entanglement in detail."}]

token_count = client.messages.count_tokens(
    model="claude-opus-4-5",
    system="You are a physics professor.",
    messages=messages,
)
print(f"This request will use ~{token_count.input_tokens} input tokens")

# Estimate cost
INPUT_PRICE_PER_TOKEN = 15.00 / 1_000_000  # Opus pricing
estimated_cost = token_count.input_tokens * INPUT_PRICE_PER_TOKEN
print(f"Estimated input cost: ${estimated_cost:.4f}")
```

## Conversation History Truncation

```python
def truncate_history(
    messages: list[dict],
    max_tokens: int,
    model: str = "claude-opus-4-5",
    system: str = "",
    keep_first: int = 2,  # Always keep first N messages (for context)
    keep_last: int = 4,   # Always keep last N messages (for recency)
) -> list[dict]:
    """Truncate middle of conversation history to stay under token limit."""
    if len(messages) <= keep_first + keep_last:
        return messages

    # Count current tokens
    count = client.messages.count_tokens(
        model=model, system=system, messages=messages
    ).input_tokens

    if count <= max_tokens:
        return messages

    # Remove messages from the middle until we're under the limit
    head = messages[:keep_first]
    tail = messages[-keep_last:]
    middle = messages[keep_first:-keep_last]

    while middle and count > max_tokens:
        middle.pop(0)  # Remove oldest middle message
        truncated = head + middle + tail
        count = client.messages.count_tokens(
            model=model, system=system, messages=truncated
        ).input_tokens

    return head + middle + tail
```

## Batch API (Python)

```python
import anthropic
import time

client = anthropic.Anthropic()

# Create a batch of requests (up to 100k requests, 256MB total)
batch = client.messages.batches.create(
    requests=[
        {
            "custom_id": f"analysis-{i}",
            "params": {
                "model": "claude-haiku-4-5",  # Use Haiku for batch savings
                "max_tokens": 512,
                "messages": [
                    {"role": "user", "content": f"Classify this text as positive/negative/neutral: '{text}'"}
                ],
            },
        }
        for i, text in enumerate(["Great product!", "Terrible service", "It was okay"])
    ]
)

print(f"Batch ID: {batch.id}")
print(f"Status: {batch.processing_status}")

# Poll until complete (or use webhooks in production)
while batch.processing_status == "in_progress":
    time.sleep(60)  # Check every minute
    batch = client.messages.batches.retrieve(batch.id)
    print(f"Status: {batch.processing_status}")

# Retrieve results
results = {}
for result in client.messages.batches.results(batch.id):
    if result.result.type == "succeeded":
        results[result.custom_id] = result.result.message.content[0].text
    elif result.result.type == "errored":
        results[result.custom_id] = f"Error: {result.result.error}"

print(results)
```

## Batch API (TypeScript)

```typescript
import Anthropic from "@anthropic-ai/sdk";

const client = new Anthropic();

async function runBatch(items: { id: string; text: string }[]) {
  const batch = await client.messages.batches.create({
    requests: items.map((item) => ({
      custom_id: item.id,
      params: {
        model: "claude-haiku-4-5",
        max_tokens: 256,
        messages: [
          { role: "user" as const, content: `Summarize in one sentence: ${item.text}` },
        ],
      },
    })),
  });

  console.log(`Batch created: ${batch.id}`);

  // Poll for completion
  let status = batch;
  while (status.processing_status === "in_progress") {
    await new Promise((r) => setTimeout(r, 30_000));
    status = await client.messages.batches.retrieve(batch.id);
  }

  // Collect results
  const results: Record<string, string> = {};
  for await (const result of await client.messages.batches.results(batch.id)) {
    if (result.result.type === "succeeded") {
      const textBlock = result.result.message.content.find(
        (b): b is Anthropic.TextBlock => b.type === "text"
      );
      results[result.custom_id] = textBlock?.text ?? "";
    }
  }
  return results;
}
```

## Model Routing by Task

```python
def route_to_model(task_type: str, complexity: str = "low") -> str:
    """Select the cheapest model that can handle the task."""
    routing_table = {
        # Cheap tasks → Haiku
        ("classification", "low"): "claude-haiku-4-5",
        ("extraction", "low"): "claude-haiku-4-5",
        ("summarization", "low"): "claude-haiku-4-5",
        ("qa", "low"): "claude-haiku-4-5",
        ("translation", "low"): "claude-haiku-4-5",

        # Medium tasks → Sonnet
        ("summarization", "high"): "claude-sonnet-4-5",
        ("code", "low"): "claude-sonnet-4-5",
        ("analysis", "low"): "claude-sonnet-4-5",
        ("qa", "high"): "claude-sonnet-4-5",

        # Complex tasks → Opus
        ("code", "high"): "claude-opus-4-5",
        ("reasoning", "high"): "claude-opus-4-5",
        ("analysis", "high"): "claude-opus-4-5",
        ("research", "high"): "claude-opus-4-5",
    }

    return routing_table.get((task_type, complexity), "claude-sonnet-4-5")

# Usage in a pipeline
def smart_process(text: str, task: str) -> str:
    complexity = "high" if len(text) > 5000 else "low"
    model = route_to_model(task, complexity)

    response = client.messages.create(
        model=model,
        max_tokens=512,
        messages=[{"role": "user", "content": f"Task: {task}\n\nText: {text}"}],
    )
    return response.content[0].text
```

## Output Token Budget

```python
# Set max_tokens based on expected output — don't over-provision
TASK_TOKEN_BUDGETS = {
    "classification": 10,    # Just a label
    "sentiment": 5,          # positive/negative/neutral
    "yes_no": 3,             # yes or no
    "summary_short": 100,    # One paragraph
    "summary_long": 500,     # Multiple paragraphs
    "code_snippet": 300,     # Small function
    "full_response": 2048,   # Open-ended
}

def call_with_budget(prompt: str, task_type: str) -> str:
    max_tokens = TASK_TOKEN_BUDGETS.get(task_type, 1024)
    response = client.messages.create(
        model="claude-haiku-4-5",
        max_tokens=max_tokens,
        messages=[{"role": "user", "content": prompt}],
    )
    return response.content[0].text
```

## Cost Calculator

```python
def estimate_cost(
    input_tokens: int,
    output_tokens: int,
    model: str = "claude-opus-4-5",
    cache_hit_tokens: int = 0,
) -> dict:
    """Estimate API cost in USD."""
    pricing = {
        "claude-haiku-4-5":   {"input": 0.80, "output": 4.00, "cache_read": 0.08},
        "claude-sonnet-4-5":  {"input": 3.00, "output": 15.00, "cache_read": 0.30},
        "claude-opus-4-5":    {"input": 15.00, "output": 75.00, "cache_read": 1.50},
    }
    p = pricing.get(model, pricing["claude-opus-4-5"])
    M = 1_000_000

    regular_input = max(0, input_tokens - cache_hit_tokens)
    input_cost = regular_input * p["input"] / M
    cache_cost = cache_hit_tokens * p["cache_read"] / M
    output_cost = output_tokens * p["output"] / M
    total = input_cost + cache_cost + output_cost

    return {
        "input_cost": round(input_cost, 6),
        "cache_cost": round(cache_cost, 6),
        "output_cost": round(output_cost, 6),
        "total": round(total, 6),
        "savings_vs_no_cache": round((input_tokens * p["input"] / M) - (input_cost + cache_cost), 6),
    }

# Example: 100k input tokens, 1k output, 80k cache hits
print(estimate_cost(100_000, 1_000, "claude-opus-4-5", cache_hit_tokens=80_000))
# {'input_cost': 0.3, 'cache_cost': 0.12, 'output_cost': 0.075, 'total': 0.495, 'savings': 0.9}
```

## RAG Context Optimization

```python
def build_rag_context(
    retrieved_chunks: list[dict],
    max_context_tokens: int = 40_000,
    model: str = "claude-sonnet-4-5",
) -> str:
    """Select top chunks that fit within token budget."""
    context_parts = []
    total_tokens = 0

    for chunk in sorted(retrieved_chunks, key=lambda x: x["score"], reverse=True):
        chunk_text = f"[Source: {chunk['source']}]\n{chunk['text']}\n"
        # Rough estimate: 1 token ≈ 4 characters
        chunk_tokens = len(chunk_text) // 4

        if total_tokens + chunk_tokens > max_context_tokens:
            break

        context_parts.append(chunk_text)
        total_tokens += chunk_tokens

    return "\n---\n".join(context_parts)
```

## GitNexus Index
This skill is indexed by GitNexus for knowledge graph traversal.
Index path: /Users/localuser/claude-skill-vault/skills/ai-ml/ai-cost-optimizer/.gitnexus
Last indexed: 2026-05-23
