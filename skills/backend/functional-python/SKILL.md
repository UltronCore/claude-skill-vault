---
name: functional-python
description: Write cleaner, more testable Python using functional programming patterns. Covers pure functions, immutable data with dataclasses/NamedTuple, function composition, partial application, monadic error handling with Result types, itertools/functools, and avoiding common anti-patterns.
version: 1.0.0
tags: [python, functional-programming, pure-functions, immutability, composition, result-type, itertools, functools]
---

# Functional Python

## Overview

Functional Python applies functional programming principles to write more predictable, testable, and composable code — without abandoning Python's pragmatic nature. It means preferring pure functions (same input → same output, no side effects), immutable data structures, function composition over inheritance hierarchies, and explicit error handling with Result types instead of exceptions as control flow. These patterns reduce bugs by eliminating hidden state and make code easier to reason about and test.

## When to Use

- Data transformation pipelines where clarity and composability matter
- Functions with complex branching that could return errors or success
- Code that's hard to test because of hidden state and side effects
- Building reusable utility functions that should work predictably anywhere
- Replacing complex class hierarchies with simple function composition

## Step-by-Step Workflow

### 1. Pure Functions and Immutability
```python
# AVOID: Mutates input, has side effects, non-deterministic
order_items = []
def add_item(items, product_id, quantity, price):
    items.append({"product_id": product_id, "quantity": quantity, "price": price})
    print(f"Added {product_id}")  # side effect

# PREFER: Pure function — returns new value, no mutation
from dataclasses import dataclass, replace
from decimal import Decimal
from typing import NamedTuple

class OrderItem(NamedTuple):
    product_id: str
    quantity: int
    unit_price: Decimal
    
    @property
    def subtotal(self) -> Decimal:
        return self.unit_price * self.quantity

class Order(NamedTuple):
    id: str
    user_id: str
    items: tuple[OrderItem, ...]
    status: str = "pending"
    
    @property
    def total(self) -> Decimal:
        return sum(item.subtotal for item in self.items)
    
    def add_item(self, item: OrderItem) -> "Order":
        """Returns new Order — original unchanged."""
        return Order(id=self.id, user_id=self.user_id, items=(*self.items, item))
    
    def with_status(self, status: str) -> "Order":
        return self._replace(status=status)

# Pure: no side effects, always same result for same input
def calculate_discount(total: Decimal, user_tier: str) -> Decimal:
    rates = {"gold": Decimal("0.15"), "silver": Decimal("0.10"), "basic": Decimal("0.05")}
    return total * rates.get(user_tier, Decimal("0"))

def apply_discount(order: Order, user_tier: str) -> tuple[Order, Decimal]:
    discount = calculate_discount(order.total, user_tier)
    # Return both modified state and computed value — no hidden mutation
    return order, discount
```

### 2. Result Type for Error Handling
```python
# Instead of exceptions as control flow, use explicit Result type
from dataclasses import dataclass
from typing import TypeVar, Generic, Callable
from functools import reduce

T = TypeVar("T")
E = TypeVar("E")

@dataclass(frozen=True)
class Ok(Generic[T]):
    value: T
    
    def map(self, f: Callable[[T], "Ok[T]"]) -> "Ok":
        return Ok(f(self.value))
    
    def flat_map(self, f: Callable) -> "Ok | Err":
        return f(self.value)
    
    def map_err(self, f: Callable) -> "Ok":
        return self  # Errors don't apply to Ok
    
    def unwrap(self) -> T:
        return self.value
    
    def is_ok(self) -> bool:
        return True

@dataclass(frozen=True)
class Err(Generic[E]):
    error: E
    
    def map(self, f: Callable) -> "Err":
        return self  # Transforms don't apply to errors
    
    def flat_map(self, f: Callable) -> "Err":
        return self
    
    def map_err(self, f: Callable) -> "Err":
        return Err(f(self.error))
    
    def unwrap(self) -> T:
        raise ValueError(f"Called unwrap on Err: {self.error}")
    
    def is_ok(self) -> bool:
        return False

Result = Ok[T] | Err[E]

# Usage: explicit error paths, no exception control flow
def parse_order_amount(raw: str) -> Result[Decimal, str]:
    try:
        amount = Decimal(raw)
        if amount <= 0:
            return Err("Amount must be positive")
        return Ok(amount)
    except Exception:
        return Err(f"Invalid amount: {raw!r}")

def validate_user(user_id: str) -> Result[dict, str]:
    if not user_id.startswith("u_"):
        return Err("Invalid user ID format")
    return Ok({"id": user_id, "tier": "gold"})

def charge_payment(user: dict, amount: Decimal) -> Result[str, str]:
    # Simulate payment
    return Ok(f"payment_{user['id']}_{amount}")

# Chain operations — each step only runs if previous succeeded
def process_payment(user_id: str, raw_amount: str) -> Result[str, str]:
    return (
        validate_user(user_id)
        .flat_map(lambda user:
            parse_order_amount(raw_amount)
            .flat_map(lambda amount: charge_payment(user, amount))
        )
    )

result = process_payment("u_12345", "99.99")
match result:
    case Ok(value=payment_id):
        print(f"Payment succeeded: {payment_id}")
    case Err(error=msg):
        print(f"Payment failed: {msg}")
```

### 3. Function Composition
```python
from functools import reduce, partial
from typing import Callable, TypeVar

A = TypeVar("A")
B = TypeVar("B")
C = TypeVar("C")

def compose(*fns: Callable) -> Callable:
    """Compose functions right-to-left: compose(f, g, h)(x) = f(g(h(x)))"""
    def composed(x):
        return reduce(lambda v, f: f(v), reversed(fns), x)
    return composed

def pipe(*fns: Callable) -> Callable:
    """Pipe functions left-to-right: pipe(f, g, h)(x) = h(g(f(x)))"""
    def piped(x):
        return reduce(lambda v, f: f(v), fns, x)
    return piped

# Domain functions
def strip_whitespace(s: str) -> str:
    return s.strip()

def to_lowercase(s: str) -> str:
    return s.lower()

def remove_special_chars(s: str) -> str:
    import re
    return re.sub(r"[^a-z0-9\s-]", "", s)

def replace_spaces(s: str) -> str:
    return s.replace(" ", "-")

# Compose into a pipeline
slugify = pipe(strip_whitespace, to_lowercase, remove_special_chars, replace_spaces)

print(slugify("  Hello World! It's a Test  "))  # "hello-world-its-a-test"

# Partial application — create specialized functions
from functools import partial

def apply_discount_rate(rate: Decimal, amount: Decimal) -> Decimal:
    return amount * (1 - rate)

apply_gold_discount = partial(apply_discount_rate, Decimal("0.15"))
apply_silver_discount = partial(apply_discount_rate, Decimal("0.10"))

# Currying with decorators
def curry(f: Callable) -> Callable:
    import inspect
    params = inspect.signature(f).parameters
    arity = len(params)
    
    def curried(*args):
        if len(args) >= arity:
            return f(*args)
        return lambda *more: curried(*args, *more)
    
    return curried

@curry
def add_tax(rate: Decimal, amount: Decimal) -> Decimal:
    return amount * (1 + rate)

add_vat = add_tax(Decimal("0.20"))
print(add_vat(Decimal("100")))  # Decimal('120')
```

### 4. Itertools and Lazy Evaluation
```python
from itertools import (
    islice, chain, groupby, takewhile, dropwhile,
    accumulate, starmap, product as cartesian_product,
    compress, filterfalse
)
from functools import reduce
from typing import Iterator, Iterable

# Infinite sequences — lazy evaluation avoids memory overhead
def naturals(start: int = 1) -> Iterator[int]:
    n = start
    while True:
        yield n
        n += 1

# First 10 primes using generators
def is_prime(n: int) -> bool:
    if n < 2: return False
    return all(n % i != 0 for i in range(2, int(n**0.5) + 1))

first_10_primes = list(islice(filter(is_prime, naturals()), 10))

# Data transformation pipeline — lazy, processes one item at a time
def process_records(records: Iterable[dict]) -> Iterator[dict]:
    """Chain of transformations — no intermediate lists loaded into memory."""
    valid = filter(lambda r: r.get("status") == "active", records)
    enriched = map(lambda r: {**r, "score": r.get("value", 0) * 1.1}, valid)
    high_value = filter(lambda r: r["score"] > 100, enriched)
    return high_value

# groupby — sort first!
from itertools import groupby

sales_data = sorted([
    {"region": "us", "amount": 100},
    {"region": "eu", "amount": 200},
    {"region": "us", "amount": 150},
    {"region": "eu", "amount": 300},
], key=lambda x: x["region"])

by_region = {
    region: sum(r["amount"] for r in records)
    for region, records in groupby(sales_data, key=lambda x: x["region"])
}
# {"eu": 500, "us": 250}

# accumulate for running totals
daily_revenue = [100, 150, 200, 175, 225]
running_total = list(accumulate(daily_revenue))  # [100, 250, 450, 625, 850]
running_max = list(accumulate(daily_revenue, max))  # [100, 150, 200, 200, 225]
```

### 5. Avoiding Mutation with Functional Data Pipelines
```python
# Immutable data transformation pipeline
from typing import Sequence
from decimal import Decimal

def transform_orders(orders: Sequence[dict]) -> tuple[dict, ...]:
    """
    Pure data pipeline — each step returns new data, nothing mutated.
    Tuple output makes the immutability explicit.
    """
    
    def add_total(order: dict) -> dict:
        total = sum(item["price"] * item["qty"] for item in order["items"])
        return {**order, "total": Decimal(str(total))}
    
    def add_tax(order: dict, rate: Decimal = Decimal("0.08")) -> dict:
        return {**order, "tax": order["total"] * rate, "grand_total": order["total"] * (1 + rate)}
    
    def add_status_label(order: dict) -> dict:
        labels = {"pending": "Awaiting Payment", "confirmed": "Processing", "shipped": "On Its Way"}
        return {**order, "status_label": labels.get(order["status"], order["status"])}
    
    return tuple(
        add_status_label(add_tax(add_total(order)))
        for order in orders
    )

# Functional aggregation without mutation
def summarize_by_status(orders: tuple[dict, ...]) -> dict[str, Decimal]:
    from functools import reduce
    
    def combine(acc: dict, order: dict) -> dict:
        status = order["status"]
        return {**acc, status: acc.get(status, Decimal("0")) + order["grand_total"]}
    
    return reduce(combine, orders, {})
```

## Key Commands Reference

```bash
# Install functional utilities
pip install returns toolz cytoolz

# returns library — production Result/Maybe/IO types
from returns.result import Result, Success, Failure
from returns.maybe import Maybe, Nothing, Some
from returns.pipeline import flow

# toolz for functional utilities
from toolz import pipe, compose, curry, memoize, juxt

# Type checking
mypy --strict your_module.py

# Test pure functions (no mocking needed)
pytest tests/ -v
```

## Common Patterns

### Pattern 1: Maybe/Option Type for Nullable Values
```python
from typing import Optional, TypeVar, Callable

T = TypeVar("T")
U = TypeVar("U")

class Maybe(Generic[T]):
    """Avoids None propagation through call chains."""
    
    def __init__(self, value: Optional[T]):
        self._value = value
    
    @classmethod
    def of(cls, value: Optional[T]) -> "Maybe[T]":
        return cls(value)
    
    def map(self, f: Callable[[T], U]) -> "Maybe[U]":
        if self._value is None:
            return Maybe(None)
        return Maybe(f(self._value))
    
    def get_or(self, default: T) -> T:
        return self._value if self._value is not None else default
    
    def __bool__(self):
        return self._value is not None

# Chain nullable operations without None checks
result = (
    Maybe.of(user_lookup("user_123"))
    .map(lambda u: u.get("preferences"))
    .map(lambda p: p.get("theme"))
    .get_or("light")
)
```

### Pattern 2: Memoization for Expensive Pure Functions
```python
from functools import lru_cache
import hashlib

# lru_cache works perfectly for pure functions
@lru_cache(maxsize=1000)
def calculate_fibonacci(n: int) -> int:
    if n < 2:
        return n
    return calculate_fibonacci(n-1) + calculate_fibonacci(n-2)

# For unhashable args, use explicit key
def memoize_with_key(key_fn: Callable):
    cache = {}
    def decorator(f: Callable) -> Callable:
        def wrapper(*args, **kwargs):
            key = key_fn(*args, **kwargs)
            if key not in cache:
                cache[key] = f(*args, **kwargs)
            return cache[key]
        return wrapper
    return decorator

@memoize_with_key(lambda items, discount: (tuple(items), discount))
def calculate_bulk_discount(items: list[dict], discount: Decimal) -> Decimal:
    total = sum(item["price"] * item["qty"] for item in items)
    return total * (1 - discount)
```

### Pattern 3: Transducers for Composable Transformations
```python
from typing import Callable, Iterable, TypeVar
from functools import reduce

def mapping(f: Callable) -> Callable:
    """Transducer: lazy map."""
    def xf(reducer):
        def step(acc, x):
            return reducer(acc, f(x))
        return step
    return xf

def filtering(pred: Callable) -> Callable:
    """Transducer: lazy filter."""
    def xf(reducer):
        def step(acc, x):
            return reducer(acc, x) if pred(x) else acc
        return step
    return xf

def transduce(xform, reducer, init, iterable):
    """Apply composed transducers to iterable."""
    return reduce(xform(reducer), iterable, init)

# Compose transducers (no intermediate collections)
xf = compose(
    filtering(lambda x: x > 0),
    mapping(lambda x: x * 2),
)

result = transduce(xf, lambda acc, x: acc + [x], [], [-1, 0, 1, 2, 3])
# [2, 4, 6]
```

## Pitfalls to Avoid

1. **Forcing functional style on inherently stateful problems**: Not everything should be functional. Database connections, file handles, network sockets — these are stateful by nature. Use functional style for data transformations and business logic, but don't fight Python's imperative strengths for I/O and state management. The `with` statement, context managers, and generators handle state well without being "impure."

2. **Overusing lambda for complex logic**: `lambda x: x.get("items", []) and sum(i["price"] for i in x["items"]) or 0` is not readable. Name your functions. Lambdas are for simple, obvious one-liners. Anything that requires reading twice should be a named function with a docstring. Functional doesn't mean anonymous.

3. **Exceptions vs. Result types — picking the wrong tool**: Don't return `Result` for every function — use it when the caller needs to handle both paths as equally likely business outcomes (payment declined = expected, not exceptional). Keep exceptions for truly unexpected errors (programming bugs, network failures in infrastructure). Mixing both creates confusion about which functions can fail "expectedly."

## Related Skills

- `async-python-patterns` — Async functional patterns with asyncio
- `data-quality-validation` — Functional validation pipelines
- `hexagonal-architecture` — Pure functions in the domain core
- `structured-generation` — Functional approach to LLM output parsing

## GitNexus Index

```json
{
  "skill": "functional-python",
  "category": "backend",
  "triggers": ["functional python", "pure functions", "result type python", "function composition python", "immutable data python", "itertools", "monadic python"],
  "outputs": ["pure function", "Result type", "compose pipe", "immutable dataclass", "lazy iterator"],
  "complexity": "medium",
  "tools": ["python", "returns", "toolz", "functools", "itertools", "mypy"]
}
```
