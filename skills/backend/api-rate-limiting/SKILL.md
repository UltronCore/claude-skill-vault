---
name: api-rate-limiting
description: Implement production-grade API rate limiting with sliding window, token bucket, and fixed window algorithms using Redis. Covers per-user limits, tiered pricing gates, distributed rate limiting, and rate limit headers.
version: 1.0.0
tags: [rate-limiting, redis, api, fastapi, express, sliding-window, token-bucket, backend, security]
---

# API Rate Limiting

## Overview

Rate limiting protects APIs from abuse, ensures fair resource distribution across clients, and prevents runaway costs. The three core algorithms — fixed window, sliding window, and token bucket — each offer different tradeoffs between accuracy, memory, and burst tolerance. In production, Redis-backed distributed rate limiting is standard because it works across multiple API server instances and survives restarts.

## When to Use

- Preventing a single client from monopolizing API capacity or causing cascading failures
- Enforcing tiered pricing (free: 100/day, pro: 10,000/day, enterprise: unlimited)
- Protecting expensive operations like LLM inference, image generation, or email sending
- Defending against credential stuffing and brute-force attacks on auth endpoints
- Complying with upstream API rate limits (forwarding limits to your own callers)
- Adding per-endpoint rate limits when some routes are far more expensive than others

## Step-by-Step Workflow

### 1. Fixed Window Rate Limiter (Redis)

```python
# pip install redis fastapi
import redis.asyncio as aioredis
from fastapi import FastAPI, Request, HTTPException
from fastapi.responses import JSONResponse
import time

redis_client = aioredis.from_url("redis://localhost:6379")
app = FastAPI()

async def fixed_window_limit(
    key: str,
    limit: int,
    window_seconds: int
) -> tuple[bool, int, int]:
    """
    Returns: (allowed, remaining, reset_at_unix)
    Simple: counts requests in a fixed time window.
    Weakness: allows 2x burst at window boundary.
    """
    now = int(time.time())
    window_key = f"ratelimit:{key}:{now // window_seconds}"

    pipe = redis_client.pipeline()
    pipe.incr(window_key)
    pipe.expire(window_key, window_seconds)
    count, _ = await pipe.execute()

    remaining = max(0, limit - count)
    reset_at = (now // window_seconds + 1) * window_seconds
    return count <= limit, remaining, reset_at

@app.middleware("http")
async def rate_limit_middleware(request: Request, call_next):
    # Identify client: prefer API key, fall back to IP
    api_key = request.headers.get("X-API-Key")
    client_id = api_key or request.client.host

    allowed, remaining, reset_at = await fixed_window_limit(
        key=client_id,
        limit=100,
        window_seconds=60
    )

    if not allowed:
        return JSONResponse(
            status_code=429,
            content={"error": "Rate limit exceeded", "retry_after": reset_at - int(time.time())},
            headers={
                "X-RateLimit-Limit": "100",
                "X-RateLimit-Remaining": "0",
                "X-RateLimit-Reset": str(reset_at),
                "Retry-After": str(reset_at - int(time.time())),
            }
        )

    response = await call_next(request)
    response.headers["X-RateLimit-Limit"] = "100"
    response.headers["X-RateLimit-Remaining"] = str(remaining)
    response.headers["X-RateLimit-Reset"] = str(reset_at)
    return response
```

### 2. Sliding Window Log (Most Accurate)

```python
import redis.asyncio as aioredis
import time

async def sliding_window_log(
    redis: aioredis.Redis,
    key: str,
    limit: int,
    window_seconds: int
) -> tuple[bool, int]:
    """
    Stores timestamp of every request in a sorted set.
    Most accurate — no boundary burst problem.
    Memory: O(limit) per key.
    """
    now = time.time()
    window_start = now - window_seconds

    async with redis.pipeline() as pipe:
        # Remove timestamps outside the window
        await pipe.zremrangebyscore(key, 0, window_start)
        # Count requests in window
        await pipe.zcard(key)
        # Add current request timestamp
        await pipe.zadd(key, {str(now): now})
        # Expire the key after the window
        await pipe.expire(key, window_seconds)
        results = await pipe.execute()

    count = results[1]
    allowed = count < limit
    remaining = max(0, limit - count - (1 if allowed else 0))
    return allowed, remaining
```

### 3. Token Bucket (Handles Bursts Gracefully)

```python
import redis.asyncio as aioredis
import time

class TokenBucket:
    """
    Tokens replenish at a fixed rate. Allows bursting up to capacity.
    Best for: variable-cost operations where you want burst tolerance.
    """
    def __init__(self, redis: aioredis.Redis, capacity: int, refill_rate: float):
        self.redis = redis
        self.capacity = capacity          # Max tokens (burst size)
        self.refill_rate = refill_rate    # Tokens per second

    async def consume(self, key: str, tokens: int = 1) -> tuple[bool, float]:
        """Returns (allowed, tokens_remaining)."""
        bucket_key = f"bucket:{key}"
        last_refill_key = f"bucket_time:{key}"

        now = time.time()

        async with self.redis.pipeline() as pipe:
            current_tokens = await pipe.get(bucket_key).execute()

        current_tokens = float(current_tokens[0] or self.capacity)
        last_refill = float(await self.redis.get(last_refill_key) or now)

        # Refill based on elapsed time
        elapsed = now - last_refill
        refilled = min(self.capacity, current_tokens + elapsed * self.refill_rate)

        if refilled >= tokens:
            new_tokens = refilled - tokens
            async with self.redis.pipeline() as pipe:
                pipe.set(bucket_key, new_tokens, ex=3600)
                pipe.set(last_refill_key, now, ex=3600)
                await pipe.execute()
            return True, new_tokens
        else:
            # Update last refill without consuming
            await self.redis.set(last_refill_key, now, ex=3600)
            return False, refilled

# Usage — cost-weighted consumption
bucket = TokenBucket(redis_client, capacity=100, refill_rate=10.0)  # 10/sec, burst 100

@app.post("/generate-image")
async def generate_image(request: Request):
    client = request.headers.get("X-API-Key", request.client.host)
    allowed, remaining = await bucket.consume(client, tokens=10)  # Image = 10 tokens
    if not allowed:
        raise HTTPException(429, "Rate limit exceeded")
    return {"message": "generating..."}
```

### 4. Tiered Rate Limits with Decorator

```python
from functools import wraps
from enum import Enum

class Tier(str, Enum):
    FREE = "free"
    PRO = "pro"
    ENTERPRISE = "enterprise"

TIER_LIMITS = {
    Tier.FREE: {"limit": 100, "window": 3600},        # 100/hour
    Tier.PRO: {"limit": 10_000, "window": 3600},      # 10k/hour
    Tier.ENTERPRISE: {"limit": 1_000_000, "window": 3600},  # Effectively unlimited
}

def rate_limit(cost: int = 1):
    """Decorator for tiered rate limiting per API endpoint."""
    def decorator(func):
        @wraps(func)
        async def wrapper(request: Request, *args, **kwargs):
            api_key = request.headers.get("X-API-Key")
            if not api_key:
                raise HTTPException(401, "API key required")

            # Look up user tier from database or cache
            user = await get_user_by_api_key(api_key)  # Your auth logic
            tier_config = TIER_LIMITS[user.tier]

            allowed, remaining = await sliding_window_log(
                redis_client,
                key=f"{api_key}:{func.__name__}",
                limit=tier_config["limit"],
                window_seconds=tier_config["window"]
            )

            if not allowed:
                raise HTTPException(
                    status_code=429,
                    detail={
                        "error": "Rate limit exceeded",
                        "tier": user.tier,
                        "limit": tier_config["limit"],
                        "upgrade_url": "https://api.acme.com/upgrade"
                    }
                )
            return await func(request, *args, **kwargs)
        return wrapper
    return decorator

@app.post("/completions")
@rate_limit(cost=1)
async def completions(request: Request):
    return {"result": "..."}
```

### 5. Node.js / Express Rate Limiting

```typescript
// npm install rate-limiter-flexible ioredis
import { RateLimiterRedis } from "rate-limiter-flexible";
import Redis from "ioredis";
import express, { Request, Response, NextFunction } from "express";

const redisClient = new Redis({ host: "localhost", port: 6379 });

const rateLimiter = new RateLimiterRedis({
  storeClient: redisClient,
  keyPrefix: "middleware",
  points: 100,          // Max requests
  duration: 60,         // Per 60 seconds
  blockDuration: 60,    // Block for 60s after limit hit
});

// Per-endpoint rate limiters
const authLimiter = new RateLimiterRedis({
  storeClient: redisClient,
  keyPrefix: "auth",
  points: 5,        // Only 5 login attempts
  duration: 900,    // Per 15 minutes
  blockDuration: 900,
});

function rateLimitMiddleware(limiter: RateLimiterRedis) {
  return async (req: Request, res: Response, next: NextFunction) => {
    const key = req.headers["x-api-key"] as string || req.ip;
    try {
      const rateLimitRes = await limiter.consume(key);
      res.set({
        "X-RateLimit-Limit": String(limiter.points),
        "X-RateLimit-Remaining": String(rateLimitRes.remainingPoints),
        "X-RateLimit-Reset": new Date(Date.now() + rateLimitRes.msBeforeNext).toISOString(),
      });
      next();
    } catch (rejRes: any) {
      const secs = Math.round(rejRes.msBeforeNext / 1000);
      res.set("Retry-After", String(secs));
      res.status(429).json({
        error: "Too Many Requests",
        retryAfter: secs,
      });
    }
  };
}

const app = express();
app.use(rateLimitMiddleware(rateLimiter));  // Global limit
app.post("/auth/login", rateLimitMiddleware(authLimiter), loginHandler);
```

## Key Commands Reference

```bash
# Redis CLI — inspect rate limit state
redis-cli KEYS "ratelimit:*"                    # See all rate limit keys
redis-cli GET "ratelimit:user123:1234567890"    # Check fixed window count
redis-cli ZCARD "ratelimit:user123"             # Sliding window request count
redis-cli TTL "ratelimit:user123"               # Time until window resets

# Monitor rate limit hits in real time
redis-cli MONITOR | grep ratelimit

# Test rate limit headers
curl -i -H "X-API-Key: test" http://localhost:8000/api/endpoint
# Look for: X-RateLimit-Limit, X-RateLimit-Remaining, X-RateLimit-Reset

# Load test to verify limits
# pip install httpx
python3 -c "
import httpx, asyncio
async def spam():
    async with httpx.AsyncClient() as c:
        for i in range(110):
            r = await c.get('http://localhost:8000/api', headers={'X-API-Key': 'test'})
            print(i, r.status_code, r.headers.get('X-RateLimit-Remaining'))
asyncio.run(spam())
"

# Redis info for memory usage
redis-cli INFO memory | grep used_memory_human
```

## Common Patterns

### Pattern 1: Distributed Rate Limiting with Lua Script (Atomic)

```python
# Atomic sliding window using Lua — prevents race conditions
SLIDING_WINDOW_SCRIPT = """
local key = KEYS[1]
local now = tonumber(ARGV[1])
local window = tonumber(ARGV[2])
local limit = tonumber(ARGV[3])

redis.call('ZREMRANGEBYSCORE', key, 0, now - window)
local count = redis.call('ZCARD', key)

if count < limit then
    redis.call('ZADD', key, now, now)
    redis.call('EXPIRE', key, window)
    return {1, limit - count - 1}  -- allowed, remaining
else
    return {0, 0}  -- blocked
end
"""

_script = None

async def atomic_sliding_window(redis, key, limit, window_ms):
    global _script
    if not _script:
        _script = redis.register_script(SLIDING_WINDOW_SCRIPT)
    now_ms = int(time.time() * 1000)
    result = await _script(keys=[key], args=[now_ms, window_ms, limit])
    return bool(result[0]), int(result[1])
```

### Pattern 2: Rate Limit by Cost (AI Token Budget)

```python
# Bill clients by token usage, not just request count
async def consume_token_budget(api_key: str, tokens_used: int) -> bool:
    """Deduct from monthly token budget (not time-windowed)."""
    budget_key = f"token_budget:{api_key}:{get_current_month()}"
    monthly_limits = {"free": 100_000, "pro": 5_000_000}

    tier = await get_user_tier(api_key)
    budget = monthly_limits.get(tier, 100_000)

    new_total = await redis_client.incrby(budget_key, tokens_used)
    if new_total == tokens_used:
        # First request this month — set TTL
        await redis_client.expire(budget_key, 32 * 86400)  # ~1 month

    return new_total <= budget

@app.post("/completions")
async def completions(request: Request, body: CompletionRequest):
    api_key = request.headers["X-API-Key"]
    result = await call_llm(body.prompt)
    tokens_used = result.usage.total_tokens

    # Deduct after call (tail-based billing)
    within_budget = await consume_token_budget(api_key, tokens_used)
    if not within_budget:
        # Still return result but warn client
        return {**result.dict(), "warning": "Monthly token budget exceeded"}
    return result
```

### Pattern 3: Graceful Degradation on Rate Limit

```typescript
// Client-side: respect rate limits with exponential backoff
async function fetchWithRetry(
  url: string,
  options: RequestInit,
  maxRetries = 3
): Promise<Response> {
  for (let attempt = 0; attempt < maxRetries; attempt++) {
    const res = await fetch(url, options);

    if (res.status !== 429) return res;

    const retryAfter = res.headers.get("Retry-After");
    const waitMs = retryAfter
      ? parseInt(retryAfter) * 1000
      : Math.pow(2, attempt) * 1000 + Math.random() * 1000;

    console.log(`Rate limited. Retrying in ${waitMs}ms (attempt ${attempt + 1})`);
    await new Promise(resolve => setTimeout(resolve, waitMs));
  }
  throw new Error("Rate limit exceeded after max retries");
}
```

## Pitfalls to Avoid

1. **Using in-memory rate limiting in multi-instance deployments**: If you store rate limit state in process memory, each server instance tracks counts independently — a client hitting 3 servers can exceed the limit 3x. Always use Redis (or another shared store) as the source of truth for distributed deployments.

2. **Not setting Redis key TTL**: Rate limit keys without expiry accumulate forever and can exhaust Redis memory. Always set `EXPIRE` matching your window duration. For sliding window sorted sets, set TTL to the window duration after each write.

3. **Applying the same limit to all endpoints**: A rate limit protecting your homepage is too aggressive for your image generation endpoint and too lenient for your login endpoint. Model limits per-endpoint based on cost and abuse risk — auth endpoints need stricter limits, read endpoints can be more generous.

## Related Skills

- `api-security-hardening` — Broader API security including auth, input validation
- `redis-patterns` — Redis data structures, pipelining, and caching patterns
- `fastapi-expert` — FastAPI middleware and dependency injection for limits
- `circuit-breaker-patterns` — Complementary pattern for downstream service protection
- `api-gateway-design` — Rate limiting at the gateway layer

## GitNexus Index

```json
{
  "skill": "api-rate-limiting",
  "category": "backend",
  "triggers": ["rate limiting", "rate limit", "429 too many requests", "sliding window", "token bucket", "fixed window", "throttling", "api quota", "per-user limits", "redis rate limit"],
  "outputs": ["fixed_window_limit", "sliding_window_log", "TokenBucket", "rate_limit decorator", "RateLimiterRedis", "SLIDING_WINDOW_SCRIPT", "X-RateLimit headers"],
  "complexity": "medium",
  "tools": ["redis", "fastapi", "express", "python", "typescript", "rate-limiter-flexible"]
}
```
