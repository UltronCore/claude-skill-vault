---
name: llm-caching-strategies
description: Implement prompt caching, semantic caching, and response memoization for LLM applications to reduce latency and API costs by 50-90%. Covers Anthropic prompt caching, Redis semantic cache, exact-match caching, and cache invalidation strategies.
version: 1.0.0
tags: [llm, caching, prompt-caching, semantic-cache, redis, anthropic, openai, cost-optimization, ai, backend]
---

# LLM Caching Strategies

## Overview

LLM API calls are the most expensive operation in AI applications — both in latency (500ms-5s) and cost ($0.01-$0.15 per request). Caching strategies can reduce costs by 50-90% and latency by 10-100x by reusing previous LLM computations. The three main strategies are exact-match caching (identical prompts), semantic caching (similar-meaning prompts), and provider-native prompt caching (Anthropic's KV cache for static prompt prefixes).

## When to Use

- LLM API costs exceed $100/month and growing with user base
- Users are asking similar or identical questions (FAQ-style, code generation templates, document analysis)
- Slow response times from LLM APIs degrading UX (semantic cache returns in <10ms vs 2-5s)
- Repeated calls with large static system prompts that don't change per-request
- Building a multi-tenant SaaS where you can share cached responses across users
- Testing and development where you want deterministic responses without API calls

## Step-by-Step Workflow

### 1. Anthropic Prompt Caching (Provider-Native)

```python
# pip install anthropic
# Caches up to 4 cache_control breakpoints per request
# Cached tokens: $0.30/1M input (vs $3.00/1M) — 90% cheaper
# Cache TTL: 5 minutes, refreshed on each hit

import anthropic

client = anthropic.Anthropic()

# Pattern: large static system prompt + dynamic user message
LARGE_SYSTEM_PROMPT = """
You are an expert Python code reviewer. You follow PEP 8, identify security
vulnerabilities, suggest performance improvements, and explain your reasoning.

[Imagine 10,000 tokens of coding guidelines, examples, and rules here...]
""" * 100  # Simulate a large prompt

def review_code(user_code: str) -> str:
    response = client.messages.create(
        model="claude-sonnet-4-5",
        max_tokens=1024,
        system=[
            {
                "type": "text",
                "text": LARGE_SYSTEM_PROMPT,
                "cache_control": {"type": "ephemeral"}  # Cache this prefix
            }
        ],
        messages=[
            {"role": "user", "content": f"Review this code:\n```python\n{user_code}\n```"}
        ]
    )

    # Check cache performance in response
    usage = response.usage
    print(f"Cache read tokens: {usage.cache_read_input_tokens}")
    print(f"Cache write tokens: {usage.cache_creation_input_tokens}")
    print(f"Regular input tokens: {usage.input_tokens}")

    return response.content[0].text

# Multi-turn conversation caching — cache grows with each turn
def cached_conversation():
    messages = []

    # Turn 1 — fills cache
    messages.append({"role": "user", "content": "What is dependency injection?"})
    r1 = client.messages.create(
        model="claude-sonnet-4-5",
        max_tokens=512,
        system=[{"type": "text", "text": LARGE_SYSTEM_PROMPT,
                  "cache_control": {"type": "ephemeral"}}],
        messages=messages
    )
    messages.append({"role": "assistant", "content": r1.content[0].text})

    # Turn 2 — hits cache for system + previous turns
    messages.append({"role": "user", "content": "Show me an example in Python"})
    messages[-3]["cache_control"] = {"type": "ephemeral"}  # Cache up to here
    r2 = client.messages.create(
        model="claude-sonnet-4-5",
        max_tokens=512,
        system=[{"type": "text", "text": LARGE_SYSTEM_PROMPT,
                  "cache_control": {"type": "ephemeral"}}],
        messages=messages
    )
    return r2.content[0].text
```

### 2. Exact-Match Cache with Redis

```python
import hashlib, json, redis.asyncio as aioredis
from anthropic import AsyncAnthropic

redis = aioredis.from_url("redis://localhost:6379")
client = AsyncAnthropic()

def make_cache_key(model: str, messages: list, system: str = "") -> str:
    """Deterministic cache key from request parameters."""
    payload = json.dumps(
        {"model": model, "messages": messages, "system": system},
        sort_keys=True
    )
    return f"llm:exact:{hashlib.sha256(payload.encode()).hexdigest()}"

async def cached_complete(
    messages: list,
    model: str = "claude-sonnet-4-5",
    system: str = "",
    ttl: int = 3600,       # 1 hour default
    bypass_cache: bool = False
) -> dict:
    """
    Exact-match caching: identical requests return cached response.
    Best for: templates, batch processing, dev/test environments.
    """
    cache_key = make_cache_key(model, messages, system)

    if not bypass_cache:
        cached = await redis.get(cache_key)
        if cached:
            result = json.loads(cached)
            result["cached"] = True
            return result

    # Cache miss — call the API
    response = await client.messages.create(
        model=model,
        max_tokens=1024,
        system=system,
        messages=messages
    )

    result = {
        "content": response.content[0].text,
        "model": response.model,
        "usage": {
            "input_tokens": response.usage.input_tokens,
            "output_tokens": response.usage.output_tokens,
        },
        "cached": False
    }

    # Store with TTL
    await redis.setex(cache_key, ttl, json.dumps(result))
    return result
```

### 3. Semantic Cache (Similar Queries)

```python
# pip install redis[hiredis] openai numpy
# Semantic cache: embed the question, find nearest cached answer

import numpy as np
import openai, json
import redis.asyncio as aioredis

openai_client = openai.AsyncOpenAI()
redis = aioredis.from_url("redis://localhost:6379")

async def get_embedding(text: str) -> list[float]:
    """Get embedding vector for semantic similarity."""
    response = await openai_client.embeddings.create(
        model="text-embedding-3-small",
        input=text
    )
    return response.data[0].embedding

def cosine_similarity(a: list[float], b: list[float]) -> float:
    a, b = np.array(a), np.array(b)
    return float(np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b)))

class SemanticCache:
    """
    Semantic cache: find cached responses for similar (not identical) queries.
    Uses embeddings + cosine similarity to match intent.
    """

    def __init__(self, redis, threshold: float = 0.92, ttl: int = 86400):
        self.redis = redis
        self.threshold = threshold  # 0.92 = very similar, 0.85 = somewhat similar
        self.ttl = ttl

    async def get(self, query: str) -> str | None:
        """Return cached response if a similar query was asked before."""
        query_embedding = await get_embedding(query)

        # Get all cached embeddings (in production, use Redis Vector Search)
        keys = await self.redis.keys("semantic:*")
        best_score = 0.0
        best_key = None

        for key in keys:
            data = json.loads(await self.redis.get(key))
            score = cosine_similarity(query_embedding, data["embedding"])
            if score > best_score:
                best_score = score
                best_key = key

        if best_score >= self.threshold:
            data = json.loads(await self.redis.get(best_key))
            print(f"Cache hit! Similarity: {best_score:.3f}")
            return data["response"]

        return None

    async def set(self, query: str, response: str) -> None:
        """Cache a query-response pair with its embedding."""
        embedding = await get_embedding(query)
        cache_key = f"semantic:{hashlib.sha256(query.encode()).hexdigest()}"
        data = {"query": query, "embedding": embedding, "response": response}
        await self.redis.setex(cache_key, self.ttl, json.dumps(data))

# Redis Vector Search version (production — much faster at scale)
# Using redis-py with RedisVL
async def setup_vector_index(redis):
    """Create Redis vector index for O(log n) similarity search."""
    from redisvl.index import SearchIndex
    from redisvl.schema import IndexSchema

    schema = IndexSchema.from_dict({
        "index": {"name": "semantic-cache", "prefix": "semantic:"},
        "fields": [
            {"name": "query", "type": "text"},
            {"name": "response", "type": "text"},
            {"name": "embedding", "type": "vector",
             "attrs": {"dims": 1536, "distance_metric": "cosine", "algorithm": "hnsw"}}
        ]
    })
    index = SearchIndex(schema, redis)
    await index.create(overwrite=False)
    return index
```

### 4. LangChain GPTCache Integration

```python
# pip install gptcache langchain langchain-anthropic
# GPTCache provides plug-and-play caching for LangChain

from gptcache import cache
from gptcache.adapter.langchain_models import LangChainLLMs
from gptcache.embedding import Onnx
from gptcache.manager import CacheBase, VectorBase, get_data_manager
from gptcache.similarity_evaluation.distance import SearchDistanceEvaluation
from langchain_anthropic import ChatAnthropic

def init_gptcache(cache_obj, llm_string: str):
    """Initialize GPTCache with semantic similarity."""
    onnx = Onnx()
    data_manager = get_data_manager(
        CacheBase("sqlite"),
        VectorBase("faiss", dimension=onnx.dimension)
    )
    cache_obj.init(
        embedding_func=onnx.to_embeddings,
        data_manager=data_manager,
        similarity_evaluation=SearchDistanceEvaluation(max_distance=0.3),
    )

from langchain.cache import GPTCache
import langchain
langchain.llm_cache = GPTCache(init_gptcache)

# Now all LangChain LLM calls are automatically cached
llm = ChatAnthropic(model="claude-sonnet-4-5")

# First call: hits API (2s)
result1 = llm.invoke("What is the capital of France?")
# Second call with similar question: cache hit (<10ms)
result2 = llm.invoke("What's the capital city of France?")
# result1 and result2 should be identical (semantic match)
```

### 5. Response Streaming with Cache Passthrough

```python
# Stream from API on cache miss; return stored response on hit
import asyncio
from typing import AsyncIterator

async def cached_stream(query: str, cache: SemanticCache) -> AsyncIterator[str]:
    """Stream response — bypass cache for streaming, cache final result."""
    cached = await cache.get(query)

    if cached:
        # Simulate streaming from cache (for consistent UX)
        words = cached.split()
        for word in words:
            yield word + " "
            await asyncio.sleep(0.01)  # Small delay for UX consistency
        return

    # Stream from API
    full_response = []
    async with client.messages.stream(
        model="claude-sonnet-4-5",
        max_tokens=1024,
        messages=[{"role": "user", "content": query}]
    ) as stream:
        async for text in stream.text_stream:
            full_response.append(text)
            yield text

    # Cache the complete response
    complete = "".join(full_response)
    await cache.set(query, complete)
```

## Key Commands Reference

```bash
# Redis for caching
redis-cli KEYS "llm:*"                     # All LLM cache keys
redis-cli DBSIZE                           # Total cached items
redis-cli TTL "llm:exact:abc123"          # Time until expiry
redis-cli INFO stats | grep keyspace_hits # Cache hit rate

# Cache hit rate analysis
redis-cli INFO stats | grep -E "(keyspace_hits|keyspace_misses)"
# keyspace_hits:1234  keyspace_misses:567
# Hit rate = 1234 / (1234 + 567) = 68.5%

# Clear LLM cache (all exact-match keys)
redis-cli KEYS "llm:exact:*" | xargs redis-cli DEL

# Monitor cache activity in real time
redis-cli MONITOR | grep "llm:"

# Anthropic cache performance check — look for cache_read_input_tokens in response
# In Python: response.usage.cache_read_input_tokens > 0 means cache hit
```

## Common Patterns

### Pattern 1: Cost Tracking with Cache Metrics

```python
from dataclasses import dataclass, field
from collections import defaultdict

@dataclass
class CacheMetrics:
    hits: int = 0
    misses: int = 0
    tokens_saved: int = 0
    cost_saved_usd: float = 0.0

metrics = CacheMetrics()

async def tracked_cached_complete(messages: list, **kwargs) -> dict:
    cache_key = make_cache_key(**kwargs, messages=messages)
    cached = await redis.get(cache_key)

    if cached:
        metrics.hits += 1
        result = json.loads(cached)
        saved_tokens = result["usage"]["input_tokens"]
        # claude-sonnet-4-5: $3/1M input tokens
        metrics.tokens_saved += saved_tokens
        metrics.cost_saved_usd += (saved_tokens / 1_000_000) * 3.0
        return {**result, "cached": True}

    metrics.misses += 1
    result = await call_api(messages, **kwargs)
    await redis.setex(cache_key, 3600, json.dumps(result))
    return result

def get_cache_report() -> dict:
    total = metrics.hits + metrics.misses
    return {
        "hit_rate": f"{100 * metrics.hits / total:.1f}%" if total else "0%",
        "tokens_saved": metrics.tokens_saved,
        "cost_saved_usd": f"${metrics.cost_saved_usd:.2f}",
    }
```

### Pattern 2: Tiered Cache (L1 Memory, L2 Redis, L3 API)

```python
from functools import lru_cache

class TieredLLMCache:
    """L1: in-process LRU | L2: Redis | L3: LLM API"""

    def __init__(self, redis, l1_size: int = 128):
        self.redis = redis
        self._l1: dict = {}    # In-process cache
        self._l1_size = l1_size

    def _l1_get(self, key: str) -> str | None:
        return self._l1.get(key)

    def _l1_set(self, key: str, value: str):
        if len(self._l1) >= self._l1_size:
            # Evict oldest (simple FIFO — use OrderedDict for LRU)
            self._l1.pop(next(iter(self._l1)))
        self._l1[key] = value

    async def get(self, key: str) -> str | None:
        # L1: microseconds
        if val := self._l1_get(key):
            return val
        # L2: ~1ms
        if val := await self.redis.get(key):
            self._l1_set(key, val)
            return val.decode()
        return None

    async def set(self, key: str, value: str, ttl: int = 3600):
        self._l1_set(key, value)
        await self.redis.setex(key, ttl, value)
```

### Pattern 3: Cache Warming for Known Queries

```python
# Pre-populate cache for common/expensive queries at startup
COMMON_QUERIES = [
    "What is your refund policy?",
    "How do I reset my password?",
    "What payment methods do you accept?",
]

async def warm_cache(queries: list[str], cache: SemanticCache):
    """Pre-populate cache at startup for known high-frequency queries."""
    print(f"Warming cache with {len(queries)} queries...")
    for query in queries:
        if await cache.get(query) is None:
            response = await call_llm(query)
            await cache.set(query, response)
            print(f"  Cached: {query[:50]}...")

# Run at application startup
async def startup():
    await warm_cache(COMMON_QUERIES, semantic_cache)
```

## Pitfalls to Avoid

1. **Caching non-deterministic responses inappropriately**: Don't cache responses that must be fresh — current stock prices, real-time data, or personalized user-specific content. Always include a `bypass_cache=True` parameter and apply cache only to queries where the same answer is valid for all users over the TTL window.

2. **Setting TTL too long for rapidly-changing information**: A 24-hour TTL on a query like "What is today's weather?" returns stale data. Model your TTL based on how quickly the correct answer changes: factual/static = 30 days, guidelines/docs = 24 hours, news/current events = 1 hour, real-time data = don't cache.

3. **Not accounting for semantic cache false positives**: At similarity threshold 0.85, "Is Python good for web apps?" and "Is Python good for data science?" might match — they have similar embeddings but the correct answer differs. Raise the threshold (0.92+) for factual queries and lower it (0.85) for general advice. Always log cache hits with their similarity score so you can tune the threshold.

## Related Skills

- `redis-patterns` — Redis data structures and performance tuning
- `ai-cost-optimizer` — Broader LLM cost optimization beyond caching
- `embedding-pipeline` — Embedding infrastructure used by semantic cache
- `vector-db-production` — Production vector stores for semantic cache at scale
- `streaming-llm-responses` — Streaming LLM responses that interact with caching

## GitNexus Index

```json
{
  "skill": "llm-caching-strategies",
  "category": "ai-ml",
  "triggers": ["LLM caching", "prompt caching", "semantic cache", "anthropic cache", "GPTCache", "LLM cost reduction", "response memoization", "AI cost optimization", "cache_control ephemeral", "cache hit rate"],
  "outputs": ["make_cache_key", "cached_complete", "SemanticCache", "TieredLLMCache", "warm_cache", "init_gptcache", "CacheMetrics"],
  "complexity": "medium",
  "tools": ["anthropic", "openai", "redis", "langchain", "gptcache", "numpy", "python"]
}
```
