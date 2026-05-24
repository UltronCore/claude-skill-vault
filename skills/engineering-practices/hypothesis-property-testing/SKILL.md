---
name: hypothesis-property-testing
version: 1.0.0
description: Property-based testing in Python with Hypothesis — automatically generate test cases to find edge cases your examples miss
tools: [Bash, Read, Write, Edit]
category: testing
tags: [hypothesis, property-based-testing, python, pytest, fuzzing, generative-testing]
author: claude-skill-vault
created: 2026-05-24
---

# Hypothesis — Property-Based Testing for Python

## Overview

Hypothesis is a property-based testing library for Python. Instead of writing specific example inputs, you describe the *shape* of valid inputs using strategies, and Hypothesis generates hundreds of random inputs to try to falsify your invariants. When it finds a failure, it shrinks the input to the minimal failing example and saves it as a regression case.

## When to Use

- Catching edge cases in parsing, serialization, numeric, and string functions
- Testing properties that should hold for all valid inputs (round-trips, monotonicity, invariants)
- Replacing or augmenting example-based tests that only cover happy paths
- Finding off-by-one errors, unicode corner cases, and overflow bugs
- Regression testing — Hypothesis remembers and replays past failures

## Installation

```bash
pip install hypothesis

# Optional integrations
pip install hypothesis[pandas]   # Pandas strategies
pip install hypothesis[numpy]    # NumPy strategies
pip install hypothesis[django]   # Django ORM strategies
pip install hypothesis[cli]      # hypothesis write CLI (generates tests)
```

## Key Patterns

### Basic property test

```python
# tests/test_codec.py
from hypothesis import given, settings, HealthCheck
from hypothesis import strategies as st

from myapp.codec import encode, decode

# Property: decode(encode(x)) == x for all valid strings
@given(st.text())
def test_encode_decode_roundtrip(text: str) -> None:
    assert decode(encode(text)) == text

# Property: sorted list is always non-decreasing
@given(st.lists(st.integers()))
def test_sort_is_nondecreasing(lst: list[int]) -> None:
    result = sorted(lst)
    for a, b in zip(result, result[1:]):
        assert a <= b

# Property: addition is commutative
@given(st.integers(), st.integers())
def test_add_commutative(a: int, b: int) -> None:
    assert a + b == b + a
```

### Constrained strategies

```python
from hypothesis import given
from hypothesis import strategies as st
from hypothesis.strategies import composite

# Bounded integers
@given(st.integers(min_value=0, max_value=100))
def test_percentage(pct: int) -> None:
    assert 0 <= pct <= 100

# Filtered strategies
@given(st.integers().filter(lambda x: x % 2 == 0))
def test_even_numbers(n: int) -> None:
    assert n % 2 == 0

# Mapped strategies
positive_floats = st.floats(min_value=0.01, max_value=1000.0, allow_nan=False)

@given(amount=positive_floats)
def test_price_format(amount: float) -> None:
    formatted = f"${amount:.2f}"
    assert formatted.startswith("$")

# Composite strategy (build complex objects)
@composite
def user_strategy(draw):
    name = draw(st.text(min_size=1, max_size=50, alphabet=st.characters(whitelist_categories=("L",))))
    age = draw(st.integers(min_value=18, max_value=120))
    email = draw(st.emails())
    return {"name": name, "age": age, "email": email}

@given(user_strategy())
def test_create_user(user: dict) -> None:
    result = create_user(**user)
    assert result["name"] == user["name"]
    assert result["age"] == user["age"]
```

### Testing with dataclasses / Pydantic

```python
from hypothesis import given
from hypothesis import strategies as st
from hypothesis.strategies import builds
from pydantic import BaseModel

class Order(BaseModel):
    product_id: str
    quantity: int
    unit_price: float

# Build strategy from Pydantic model
order_strategy = builds(
    Order,
    product_id=st.text(min_size=1, max_size=20),
    quantity=st.integers(min_value=1, max_value=100),
    unit_price=st.floats(min_value=0.01, max_value=10000.0, allow_nan=False),
)

@given(order_strategy)
def test_order_total(order: Order) -> None:
    total = order.quantity * order.unit_price
    assert total >= 0
    assert total == order.quantity * order.unit_price  # exact, no rounding
```

### Stateful testing (multiple steps)

```python
from hypothesis.stateful import RuleBasedStateMachine, rule, invariant, initialize
from hypothesis import strategies as st

class ShoppingCartMachine(RuleBasedStateMachine):
    """Stateful test: apply rules (add, remove, clear) and check invariants."""

    @initialize()
    def init_cart(self):
        self.cart = {}
        self.expected_count = 0

    @rule(item=st.text(min_size=1), qty=st.integers(min_value=1, max_value=10))
    def add_item(self, item: str, qty: int):
        self.cart[item] = self.cart.get(item, 0) + qty
        self.expected_count += qty

    @rule(item=st.text(min_size=1))
    def remove_item(self, item: str):
        if item in self.cart:
            self.expected_count -= self.cart.pop(item)

    @rule()
    def clear(self):
        self.cart.clear()
        self.expected_count = 0

    @invariant()
    def total_matches(self):
        assert sum(self.cart.values()) == self.expected_count

CartTest = ShoppingCartMachine.TestCase
```

### Settings and profiles

```python
from hypothesis import given, settings, HealthCheck
from hypothesis import strategies as st

# Increase examples for thorough testing
@settings(max_examples=1000, suppress_health_check=[HealthCheck.too_slow])
@given(st.binary())
def test_binary_parse(data: bytes) -> None:
    # Should never raise — parser must handle any input
    try:
        result = parse_binary(data)
        assert isinstance(result, dict)
    except ValueError:
        pass  # Invalid input → ValueError is OK

# CI profile (fewer examples, faster)
# In conftest.py:
# settings.register_profile("ci", max_examples=50)
# settings.register_profile("dev", max_examples=200)
# settings.load_profile(os.getenv("HYPOTHESIS_PROFILE", "dev"))
```

### pytest integration

```bash
# Run hypothesis tests with pytest
pytest tests/ -v

# Show statistics (how many examples were tried)
pytest tests/ --hypothesis-show-statistics

# Re-run only failing examples (from database)
pytest tests/ --hypothesis-seed=0

# Set examples count via env var
HYPOTHESIS_MAX_EXAMPLES=500 pytest tests/
```

## Common Pitfalls

1. **`@given` wraps `@settings`**: The order matters — put `@settings` above `@given`, not below.
2. **Mutable default strategies**: Don't share mutable strategy objects between tests — define them inline or use `@composite`.
3. **Filtering too aggressively**: `st.integers().filter(lambda x: x == 42)` is extremely slow. Use bounded strategies instead.
4. **Assuming float precision**: `st.floats()` includes NaN and infinity by default. Use `allow_nan=False, allow_infinity=False` unless your code handles them.
5. **Database replay**: Hypothesis saves failing examples to `.hypothesis/` — commit this directory so CI replays known regressions.

## Related Skills

- vitest-testing — unit tests for TypeScript/JavaScript projects
- pytest-asyncio — async test support for Python coroutines
- msw-api-mocking — network-level mocking for integration tests

## GitNexus Index

```
domain: testing
maturity: stable
complexity: medium
language: python
integrates-with: pytest, django, numpy, pandas
config-file: pyproject.toml ([tool.hypothesis])
database: .hypothesis/
```
