---
name: circuit-breaker-patterns
description: Implement circuit breaker, bulkhead, and retry patterns for resilient distributed systems. Covers open/half-open/closed states, fallback strategies, and libraries for Python, Go, Node.js, and Java.
version: 1.0.0
tags: [resilience, circuit-breaker, distributed-systems, fault-tolerance, retry, bulkhead]
---

# Circuit Breaker Patterns

## Overview

This skill covers implementing resilience patterns for distributed systems: circuit breakers that stop cascading failures, bulkheads that isolate resource pools, retry with exponential backoff and jitter, and timeout management. These patterns are essential when your service calls external APIs, databases, or other microservices that can fail. The goal is graceful degradation instead of catastrophic cascades.

## When to Use

- Any service that makes HTTP calls to external APIs or other services
- Database calls that can be slow or unavailable under load
- Third-party payment, email, or notification integrations
- Microservice architectures where one slow service causes backpressure
- Replacing bare requests with resilient calling patterns

## Step-by-Step Workflow

### 1. Circuit Breaker State Machine
```
CLOSED → (failure_count >= threshold) → OPEN
OPEN   → (timeout elapsed)            → HALF_OPEN
HALF_OPEN → (probe succeeds)          → CLOSED
HALF_OPEN → (probe fails)             → OPEN
```

### 2. Python Implementation (manual)
```python
import threading
import time
from enum import Enum
from functools import wraps

class CircuitState(Enum):
    CLOSED = "closed"
    OPEN = "open"
    HALF_OPEN = "half_open"

class CircuitBreaker:
    def __init__(
        self,
        failure_threshold: int = 5,
        recovery_timeout: float = 60.0,
        expected_exception: type = Exception,
    ):
        self.failure_threshold = failure_threshold
        self.recovery_timeout = recovery_timeout
        self.expected_exception = expected_exception
        
        self._state = CircuitState.CLOSED
        self._failure_count = 0
        self._last_failure_time: float = 0
        self._lock = threading.Lock()
    
    @property
    def state(self) -> CircuitState:
        with self._lock:
            if self._state == CircuitState.OPEN:
                if time.monotonic() - self._last_failure_time > self.recovery_timeout:
                    self._state = CircuitState.HALF_OPEN
            return self._state
    
    def call(self, fn, *args, **kwargs):
        state = self.state
        if state == CircuitState.OPEN:
            raise CircuitOpenError(f"Circuit is OPEN — refusing call to protect system")
        
        try:
            result = fn(*args, **kwargs)
            self._on_success()
            return result
        except self.expected_exception as e:
            self._on_failure()
            raise
    
    def _on_success(self):
        with self._lock:
            self._failure_count = 0
            self._state = CircuitState.CLOSED
    
    def _on_failure(self):
        with self._lock:
            self._failure_count += 1
            self._last_failure_time = time.monotonic()
            if self._failure_count >= self.failure_threshold:
                self._state = CircuitState.OPEN

class CircuitOpenError(Exception):
    pass

# Decorator usage
def circuit_breaker(cb: CircuitBreaker):
    def decorator(fn):
        @wraps(fn)
        def wrapper(*args, **kwargs):
            return cb.call(fn, *args, **kwargs)
        return wrapper
    return decorator

# Usage
payment_cb = CircuitBreaker(failure_threshold=3, recovery_timeout=30.0)

@circuit_breaker(payment_cb)
def charge_payment(order_id: str, amount: float) -> dict:
    return payment_api.charge(order_id, amount)

def process_order(order):
    try:
        return charge_payment(order.id, order.total)
    except CircuitOpenError:
        return {"status": "queued", "message": "Payment service unavailable, will retry"}
    except PaymentError as e:
        raise
```

### 3. Using tenacity for Retry + Circuit Breaker
```python
from tenacity import (
    retry, stop_after_attempt, wait_exponential_jitter,
    retry_if_exception_type, before_sleep_log
)
import logging

logger = logging.getLogger(__name__)

@retry(
    retry=retry_if_exception_type((ConnectionError, TimeoutError)),
    stop=stop_after_attempt(4),
    wait=wait_exponential_jitter(initial=0.5, max=30),
    before_sleep=before_sleep_log(logger, logging.WARNING),
    reraise=True,
)
def call_external_api(endpoint: str, data: dict) -> dict:
    response = requests.post(endpoint, json=data, timeout=5)
    response.raise_for_status()
    return response.json()
```

### 4. Using pybreaker (Production-Ready)
```python
import pybreaker
import redis

# Use Redis for shared state across instances
class RedisCircuitBreakerStorage(pybreaker.CircuitBreakerStorage):
    def __init__(self, redis_client, namespace):
        self.redis = redis_client
        self.namespace = namespace
    # ... implements get/set for failure count and state

storage = RedisCircuitBreakerStorage(redis_client, "payment-service")
payment_breaker = pybreaker.CircuitBreaker(
    fail_max=5,
    reset_timeout=30,
    state_storage=storage,
    listeners=[pybreaker.CircuitBreakerListener()],
)

@payment_breaker
def charge_payment(order_id, amount):
    return payment_api.charge(order_id, amount)
```

### 5. Bulkhead Pattern (Thread Pool Isolation)
```python
from concurrent.futures import ThreadPoolExecutor, TimeoutError
from functools import partial

class Bulkhead:
    def __init__(self, max_concurrent: int = 10, queue_size: int = 50):
        self.executor = ThreadPoolExecutor(
            max_workers=max_concurrent,
            max_tasks_in_queue=queue_size,
        )
    
    def execute(self, fn, *args, timeout: float = 10.0, **kwargs):
        future = self.executor.submit(fn, *args, **kwargs)
        try:
            return future.result(timeout=timeout)
        except TimeoutError:
            future.cancel()
            raise TimeoutError(f"Bulkhead timeout after {timeout}s")

# Separate bulkheads prevent one service from consuming all threads
payment_bulkhead = Bulkhead(max_concurrent=20)
email_bulkhead = Bulkhead(max_concurrent=5)
db_bulkhead = Bulkhead(max_concurrent=50)
```

### 6. Fallback Strategy
```python
from functools import lru_cache

def get_product_recommendations(user_id: str) -> list[dict]:
    """Get personalized recommendations with fallback to popular items."""
    try:
        with circuit_breaker_context(ml_service_cb):
            return ml_service.get_recommendations(user_id, timeout=2.0)
    except (CircuitOpenError, TimeoutError):
        # Fallback to cached popular items
        return get_cached_popular_items()

@lru_cache(maxsize=1)
def get_cached_popular_items() -> list[dict]:
    return [{"id": "prod-1", "name": "Popular Item 1"}, ...]
```

## Key Commands Reference

```bash
# Install libraries
pip install tenacity pybreaker redis

# Node.js: opossum
npm install opossum

# Go: sony/gobreaker
go get github.com/sony/gobreaker

# Java: resilience4j
# Add to pom.xml:
# io.github.resilience4j:resilience4j-circuitbreaker:2.1.0
```

## Common Patterns

### Pattern 1: Node.js with Opossum
```javascript
const CircuitBreaker = require('opossum');

const options = {
  timeout: 3000,              // If fn takes > 3s, treat as failure
  errorThresholdPercentage: 50, // Open when 50% requests fail
  resetTimeout: 30000,         // Try again after 30s
};

const breaker = new CircuitBreaker(paymentService.charge, options);

breaker.fallback(() => ({ status: 'queued' }));
breaker.on('open', () => console.log('Circuit OPEN'));
breaker.on('halfOpen', () => console.log('Circuit HALF_OPEN'));
breaker.on('close', () => console.log('Circuit CLOSED'));

// Use it
const result = await breaker.fire(orderId, amount);
```

### Pattern 2: Exponential Backoff with Jitter (Full Jitter)
```python
import random
import time

def with_backoff(fn, max_retries=5, base_delay=0.5, max_delay=60.0):
    for attempt in range(max_retries):
        try:
            return fn()
        except (ConnectionError, TimeoutError) as e:
            if attempt == max_retries - 1:
                raise
            # Full jitter: sleep between 0 and min(cap, base * 2^attempt)
            sleep = random.uniform(0, min(max_delay, base_delay * (2 ** attempt)))
            time.sleep(sleep)
```

### Pattern 3: Timeout Propagation with Context
```python
import asyncio

async def call_with_timeout(coro, timeout: float):
    try:
        return await asyncio.wait_for(coro, timeout=timeout)
    except asyncio.TimeoutError:
        raise TimeoutError(f"Operation timed out after {timeout}s")

async def process_order(order_id: str):
    # Propagate decreasing timeout budget
    TOTAL_BUDGET = 10.0
    start = asyncio.get_event_loop().time()
    
    payment = await call_with_timeout(charge_payment(order_id), timeout=3.0)
    
    elapsed = asyncio.get_event_loop().time() - start
    remaining = TOTAL_BUDGET - elapsed
    
    await call_with_timeout(send_confirmation(order_id), timeout=remaining)
```

## Pitfalls to Avoid

1. **Shared circuit breaker for different operations**: Never share one breaker for read and write operations to the same service. A slow write path shouldn't block fast reads. Create separate breakers per operation type or criticality level.

2. **Not adding jitter to retries**: Pure exponential backoff causes thundering herd — all retrying clients hit the recovering service at the same time. Always add random jitter: `sleep = random.uniform(0, calculated_delay)`. AWS calls this "Full Jitter" and it's dramatically better.

3. **Silent fallbacks hiding real problems**: Fallback paths must emit metrics and alerts. A circuit breaker silently returning stale data for days while the downstream service is broken is worse than an immediate error. Log every circuit open/close event and alert on sustained open state.

## Related Skills

- `redis-patterns` — Storing shared circuit breaker state in Redis
- `opentelemetry-instrumentation` — Tracing circuit breaker state transitions
- `chaos-engineering` — Testing that circuit breakers work under failure
- `go-microservices` — Circuit breakers in Go with gobreaker

## GitNexus Index

```json
{
  "skill": "circuit-breaker-patterns",
  "category": "backend",
  "triggers": ["circuit breaker", "resilience", "fault tolerance", "retry pattern", "bulkhead", "cascading failure", "fallback"],
  "outputs": ["circuit breaker implementation", "retry logic", "fallback strategy", "bulkhead"],
  "complexity": "medium",
  "tools": ["tenacity", "pybreaker", "opossum", "resilience4j", "gobreaker"]
}
```
