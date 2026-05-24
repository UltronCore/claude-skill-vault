---
name: redis-patterns
description: Implement production Redis patterns including caching strategies, rate limiting, distributed locks, pub/sub, sorted sets for leaderboards, streams, and Lua scripting.
version: 1.0.0
tags: [redis, caching, rate-limiting, distributed-locks, pubsub, data-structures]
---

# Redis Patterns

## Overview

This skill covers battle-tested Redis usage patterns for production systems: cache-aside with TTL management, distributed locking with Redlock, rate limiting algorithms, real-time leaderboards with sorted sets, pub/sub messaging, and Redis Streams for durable messaging. It goes beyond basic get/set to show how to leverage Redis data structures for performance-critical application needs.

## When to Use

- Implementing API rate limiting that needs to survive restarts
- Caching expensive database queries with proper invalidation
- Distributed locking across multiple application instances
- Real-time leaderboards, session stores, or presence systems
- Simple pub/sub messaging without Kafka complexity
- Job queues or background task distribution

## Step-by-Step Workflow

### 1. Connection Setup (Python with redis-py)
```python
import redis
from redis.retry import Retry
from redis.backoff import ExponentialBackoff

pool = redis.ConnectionPool(
    host='localhost',
    port=6379,
    db=0,
    max_connections=50,
    socket_timeout=5,
    socket_connect_timeout=5,
    retry=Retry(ExponentialBackoff(), 3),
    health_check_interval=30,
)
r = redis.Redis(connection_pool=pool, decode_responses=True)
```

### 2. Cache-Aside Pattern
```python
import json
import hashlib
from functools import wraps
from typing import Optional, Callable, Any

def cache(ttl_seconds: int = 300, key_prefix: str = "cache"):
    """Decorator for cache-aside pattern with JSON serialization."""
    def decorator(fn: Callable) -> Callable:
        @wraps(fn)
        def wrapper(*args, **kwargs) -> Any:
            # Build cache key from function name + hashed args
            arg_hash = hashlib.md5(
                json.dumps([args, kwargs], sort_keys=True).encode()
            ).hexdigest()[:8]
            cache_key = f"{key_prefix}:{fn.__name__}:{arg_hash}"
            
            cached = r.get(cache_key)
            if cached is not None:
                return json.loads(cached)
            
            result = fn(*args, **kwargs)
            r.setex(cache_key, ttl_seconds, json.dumps(result))
            return result
        return wrapper
    return decorator

@cache(ttl=600, key_prefix="api")
def get_user_profile(user_id: str) -> dict:
    return db.query("SELECT * FROM users WHERE id = %s", user_id)
```

### 3. Rate Limiting (Token Bucket via Lua)
```python
RATE_LIMIT_SCRIPT = """
local key = KEYS[1]
local limit = tonumber(ARGV[1])
local window = tonumber(ARGV[2])

local current = redis.call('GET', key)
if current and tonumber(current) >= limit then
    return 0
end

local count = redis.call('INCR', key)
if count == 1 then
    redis.call('EXPIRE', key, window)
end
return 1
"""

rate_limit_fn = r.register_script(RATE_LIMIT_SCRIPT)

def check_rate_limit(user_id: str, limit: int = 100, window: int = 60) -> bool:
    """Returns True if request is allowed, False if rate limited."""
    key = f"ratelimit:{user_id}"
    result = rate_limit_fn(keys=[key], args=[limit, window])
    return bool(result)

# Usage in FastAPI
@app.get("/api/data")
async def get_data(user_id: str = Header(...)):
    if not check_rate_limit(user_id, limit=100, window=60):
        raise HTTPException(429, "Rate limit exceeded")
    return {"data": "..."}
```

### 4. Distributed Lock (Redlock)
```python
import uuid
import time

def acquire_lock(resource: str, ttl_ms: int = 10000) -> Optional[str]:
    """Returns lock token if acquired, None if already locked."""
    token = str(uuid.uuid4())
    key = f"lock:{resource}"
    acquired = r.set(key, token, px=ttl_ms, nx=True)
    return token if acquired else None

def release_lock(resource: str, token: str) -> bool:
    """Safely releases lock only if we own it."""
    UNLOCK_SCRIPT = """
    if redis.call('GET', KEYS[1]) == ARGV[1] then
        return redis.call('DEL', KEYS[1])
    else
        return 0
    end
    """
    unlock = r.register_script(UNLOCK_SCRIPT)
    return bool(unlock(keys=[f"lock:{resource}"], args=[token]))

# Context manager
from contextlib import contextmanager

@contextmanager
def distributed_lock(resource: str, ttl_ms: int = 10000, timeout: float = 5.0):
    start = time.time()
    token = None
    while token is None:
        token = acquire_lock(resource, ttl_ms)
        if token is None:
            if time.time() - start > timeout:
                raise TimeoutError(f"Could not acquire lock on {resource}")
            time.sleep(0.05)
    try:
        yield
    finally:
        release_lock(resource, token)

# Usage
with distributed_lock("invoice-123", ttl_ms=5000):
    process_invoice("invoice-123")
```

### 5. Leaderboard with Sorted Sets
```python
def update_score(leaderboard: str, user_id: str, delta: float) -> float:
    """Increment score and return new score."""
    return r.zincrby(leaderboard, delta, user_id)

def get_top_n(leaderboard: str, n: int = 10) -> list[dict]:
    """Get top N players with ranks and scores."""
    entries = r.zrevrange(leaderboard, 0, n - 1, withscores=True)
    return [
        {"rank": i + 1, "user_id": user_id, "score": score}
        for i, (user_id, score) in enumerate(entries)
    ]

def get_user_rank(leaderboard: str, user_id: str) -> Optional[int]:
    rank = r.zrevrank(leaderboard, user_id)
    return rank + 1 if rank is not None else None

# Usage
update_score("global-leaderboard", "user-123", 50)
print(get_top_n("global-leaderboard", 10))
print(get_user_rank("global-leaderboard", "user-123"))
```

### 6. Redis Streams
```python
# Producer: append to stream
stream_id = r.xadd("events:orders", {
    "order_id": "ord-123",
    "user_id": "usr-456",
    "total": "99.99",
    "status": "created",
})

# Consumer group for reliable processing
r.xgroup_create("events:orders", "order-processor", id="0", mkstream=True)

# Consumer: read and acknowledge
messages = r.xreadgroup(
    groupname="order-processor",
    consumername="worker-1",
    streams={"events:orders": ">"},
    count=10,
    block=1000,  # Wait 1s for new messages
)

for stream, msgs in (messages or []):
    for msg_id, fields in msgs:
        try:
            process_order(fields)
            r.xack("events:orders", "order-processor", msg_id)
        except Exception as e:
            print(f"Failed {msg_id}: {e}")  # Will be redelivered
```

## Key Commands Reference

```bash
# Connection and info
redis-cli ping
redis-cli info server | grep redis_version
redis-cli monitor  # Real-time command stream (dev only!)
redis-cli slowlog get 10  # Slow queries

# Memory analysis
redis-cli memory doctor
redis-cli memory usage mykey

# Debug patterns
redis-cli --scan --pattern "cache:*" | wc -l
redis-cli --scan --pattern "lock:*" | xargs redis-cli del  # Purge locks

# Pub/Sub
redis-cli subscribe channel-name
redis-cli publish channel-name "hello"

# Stream inspection
redis-cli xlen events:orders
redis-cli xrange events:orders - + COUNT 5
redis-cli xinfo groups events:orders
redis-cli xpending events:orders order-processor - + 10
```

## Common Patterns

### Pattern 1: Cache Stampede Prevention (Probabilistic Early Expiration)
```python
import math, random

def get_with_pex(key: str, fn: Callable, ttl: int, beta: float = 1.0) -> Any:
    """Probabilistic early expiration prevents cache stampede."""
    data = r.get(key)
    if data:
        value, expiry = json.loads(data)
        time_remaining = expiry - time.time()
        gap = -math.log(random.random()) * beta
        if time_remaining > gap:
            return value
    
    result = fn()
    expiry = time.time() + ttl
    r.setex(key, ttl, json.dumps([result, expiry]))
    return result
```

### Pattern 2: Pub/Sub Event Bus
```python
import threading

def subscribe_to_events(channel: str, handler: Callable):
    pubsub = r.pubsub()
    pubsub.subscribe(channel)
    
    def listener():
        for message in pubsub.listen():
            if message["type"] == "message":
                handler(json.loads(message["data"]))
    
    thread = threading.Thread(target=listener, daemon=True)
    thread.start()
    return pubsub  # Call pubsub.unsubscribe() to stop

def publish_event(channel: str, event: dict):
    r.publish(channel, json.dumps(event))
```

### Pattern 3: Session Store with Sliding Expiration
```python
SESSION_TTL = 3600  # 1 hour

def get_session(session_id: str) -> Optional[dict]:
    key = f"session:{session_id}"
    data = r.get(key)
    if data:
        r.expire(key, SESSION_TTL)  # Sliding expiration
        return json.loads(data)
    return None

def set_session(session_id: str, data: dict):
    r.setex(f"session:{session_id}", SESSION_TTL, json.dumps(data))

def delete_session(session_id: str):
    r.delete(f"session:{session_id}")
```

## Pitfalls to Avoid

1. **Using KEYS in production**: `KEYS *` blocks the Redis event loop — can lock up production for seconds on large keyspaces. Use `SCAN` with a cursor instead: `redis-cli --scan --pattern "prefix:*"`. Set up keyspace notifications for monitoring specific key changes.

2. **Unbounded caches**: Without expiry, Redis fills RAM and starts evicting random keys with `allkeys-lru` or crashes with `noeviction`. Always set TTLs. Use `maxmemory` and `maxmemory-policy` in `redis.conf`. Monitor `used_memory` vs `maxmemory`.

3. **Race conditions in non-atomic operations**: `GET` + `SET` in two separate commands is not atomic. Other clients can modify the key between calls. Use Lua scripts, `SET NX`, `GETSET`, or transactions (`MULTI`/`EXEC`) for atomic operations.

## Related Skills

- `event-driven-architecture` — Redis as event bus for simple use cases
- `circuit-breaker-patterns` — Circuit breaker state stored in Redis
- `api-gateway-design` — Rate limiting at the gateway with Redis
- `kafka-event-streaming` — When Redis Streams isn't enough

## GitNexus Index

```json
{
  "skill": "redis-patterns",
  "category": "backend",
  "triggers": ["redis", "caching", "rate limit", "distributed lock", "pub/sub", "sorted set", "leaderboard", "session store"],
  "outputs": ["cache implementation", "rate limiter", "distributed lock", "leaderboard", "event bus"],
  "complexity": "medium",
  "tools": ["redis", "redis-py", "ioredis", "redis-cli"]
}
```
