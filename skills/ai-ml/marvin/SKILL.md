---
name: marvin
description: AI functions and classifiers using LLMs as pure Python functions with type annotations
version: 1.0.0
tags: [llm, classification, extraction, python, functions, ai-functions]
---

# Marvin — AI Functions and Classifiers

## Overview

Marvin is a Python library that turns LLMs into typed Python functions. Use `@marvin.fn` to write a function signature and docstring — Marvin handles the prompt engineering and response parsing automatically. Includes `marvin.classify()` for multi-class classification, `marvin.extract()` for structured extraction, `marvin.cast()` for type conversion, and `marvin.generate()` for data synthesis.

GitHub: https://github.com/PrefectHQ/marvin (5k+ stars)

## When to Use

- Quick LLM-backed classification without prompt engineering overhead
- Typed structured extraction from unstructured text
- Building AI functions that behave like normal Python functions
- Data cleaning and normalization pipelines
- Generating synthetic test data with schema constraints

## Installation

```bash
pip install marvin

# Set API key
export OPENAI_API_KEY=your-key

# Or configure in code
import marvin
marvin.settings.openai.api_key = "your-key"
```

## Key Patterns / Usage

### classify() — Multi-Class Classification
```python
import marvin
from enum import Enum

class Sentiment(Enum):
    POSITIVE = "positive"
    NEGATIVE = "negative"
    NEUTRAL = "neutral"

# Single classification
result = marvin.classify("I absolutely love this product!", labels=Sentiment)
print(result)  # Sentiment.POSITIVE

# With string labels (no enum required)
result = marvin.classify(
    "The service was okay, nothing special",
    labels=["excellent", "good", "average", "poor"],
)
print(result)  # "average"

# Batch classification
texts = [
    "Best purchase ever!",
    "Terrible quality, broke on day 1",
    "It arrived on time",
]
results = [marvin.classify(t, labels=Sentiment) for t in texts]
```

### extract() — Structured Extraction
```python
import marvin
from pydantic import BaseModel
from typing import List

class Person(BaseModel):
    name: str
    age: int | None = None
    role: str | None = None

# Extract list of entities
people = marvin.extract(
    "Alice (32) is the CTO and Bob is a senior engineer reporting to her.",
    target=Person,
)
for person in people:
    print(f"{person.name}: {person.role}, age={person.age}")

# Extract simple types
emails = marvin.extract(
    "Contact us at support@company.com or sales@company.com",
    target=str,
    instructions="Extract email addresses",
)
print(emails)  # ["support@company.com", "sales@company.com"]

# Extract numbers
prices = marvin.extract(
    "The item costs $29.99 normally but is on sale for $19.99",
    target=float,
    instructions="Extract all prices in USD",
)
print(prices)  # [29.99, 19.99]
```

### cast() — Type Conversion
```python
import marvin
from pydantic import BaseModel

class Address(BaseModel):
    street: str
    city: str
    state: str
    zip_code: str

# Convert unstructured text to typed object
address = marvin.cast(
    "123 Main St, Springfield, IL 62701",
    target=Address,
)
print(address.city)    # "Springfield"
print(address.state)   # "IL"

# Cast to bool
is_positive = marvin.cast(
    "The results were quite disappointing overall.",
    target=bool,
    instructions="Is this text expressing a positive sentiment?",
)
print(is_positive)  # False

# Normalize data
normalized_date = marvin.cast(
    "third of March, twenty twenty-four",
    target=str,
    instructions="Convert to ISO 8601 date format (YYYY-MM-DD)",
)
print(normalized_date)  # "2024-03-03"
```

### @marvin.fn — AI Functions
```python
import marvin

@marvin.fn
def suggest_variable_name(description: str) -> str:
    """Suggest a Pythonic snake_case variable name for the given description."""

@marvin.fn
def detect_language(text: str) -> str:
    """Return the ISO 639-1 language code for the language of the given text."""

@marvin.fn
def rate_code_quality(code: str) -> int:
    """Rate the quality of this Python code on a scale of 1-10, where 10 is best."""

# Use like normal Python functions
print(suggest_variable_name("number of retries before failing"))  # "max_retry_count"
print(detect_language("Bonjour le monde"))  # "fr"
print(rate_code_quality("x=1+1;print(x)"))  # 2
```

### generate() — Synthetic Data
```python
import marvin
from pydantic import BaseModel
from typing import List

class Product(BaseModel):
    name: str
    price: float
    category: str
    description: str

# Generate multiple examples
products = marvin.generate(
    target=Product,
    n=5,
    instructions="Generate realistic e-commerce product listings for tech gadgets",
)
for product in products:
    print(f"${product.price:.2f} — {product.name}")
```

### Async Support
```python
import marvin
import asyncio

async def main():
    result = await marvin.classify_async(
        "Great customer support!",
        labels=["positive", "negative", "neutral"],
    )
    print(result)

    entities = await marvin.extract_async(
        "John Smith called about order #12345",
        target=str,
        instructions="Extract person names",
    )
    print(entities)

asyncio.run(main())
```

### Configuration for Different Models
```python
import marvin
from marvin.settings import settings

# Use a different model
settings.openai.chat.completions.model = "gpt-4o"

# Use Anthropic
import anthropic
# Marvin primarily uses OpenAI; for Anthropic use instructor or litellm
```

## Common Pitfalls

- **OpenAI only by default**: Marvin v2 primarily uses OpenAI; switching providers requires extra config
- **No streaming**: Marvin functions return complete results, not streams
- **Costs can stack up**: classifying thousands of items calls the API thousands of times; batch if possible
- **Instructions are key**: vague instructions = vague results; be specific about what to extract
- **Pydantic required**: `extract()` and `cast()` with complex types require Pydantic models
- **Rate limiting**: no built-in retry; wrap in tenacity or similar for production

## Related Skills

- `instructor` — alternative structured extraction with retry logic
- `outlines` — token-level constrained generation for classification
- `structured-output-extraction` — general structured extraction patterns
- `guidance` — Microsoft's alternative for constrained generation

## GitNexus Index

```
tool: marvin
category: llm-functions
tier: library
interface: python-sdk
platform: cross-platform
stars: 5000+
```
