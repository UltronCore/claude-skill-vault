---
name: outlines
description: Fast structured text generation from LLMs using regex and JSON schema constraints
version: 1.0.0
tags: [llm, structured-generation, regex, json-schema, constrained-decoding]
---

# Outlines — Structured Text Generation

## Overview

Outlines is a Python library for structured text generation with LLMs. It enforces output constraints (JSON schema, regex, Pydantic models, choice sets) at the token level using efficient finite-state machine (FSM) compilation. Much faster than post-processing validation — constraints are applied during generation, making invalid outputs structurally impossible. Works with transformers, llama.cpp, vLLM, and OpenAI.

GitHub: https://github.com/dottxt-ai/outlines (11k+ stars)

## When to Use

- Guaranteed JSON output matching a schema (no parsing errors)
- Enum/choice classification with no hallucinated options
- Regex-constrained generation (dates, phone numbers, codes)
- High-throughput structured generation pipelines
- When instructor/guidance are too slow or need exact token control

## Installation

```bash
pip install outlines

# For transformers backend
pip install outlines[transformers]

# For llama.cpp backend
pip install outlines[llamacpp]
```

## Key Patterns / Usage

### JSON Schema Generation
```python
import outlines
from pydantic import BaseModel
from typing import List, Optional

class Character(BaseModel):
    name: str
    age: int
    occupation: str
    skills: List[str]
    backstory: Optional[str] = None

model = outlines.models.transformers("mistralai/Mistral-7B-Instruct-v0.2")
generator = outlines.generate.json(model, Character)

character = generator(
    "Create a fantasy RPG character who is a skilled archer."
)
print(character)  # Character object with guaranteed schema
print(character.name)
print(character.skills)
```

### Using with OpenAI (structured mode)
```python
import outlines
from pydantic import BaseModel

class SentimentResult(BaseModel):
    sentiment: str
    confidence: float
    reasoning: str

model = outlines.models.openai("gpt-4o-mini")
generator = outlines.generate.json(model, SentimentResult)

result = generator(
    "Classify: 'This product is absolutely terrible and broke after one use.'"
)
print(result.sentiment)    # "negative"
print(result.confidence)   # 0.97
```

### Choice / Enum Generation
```python
import outlines

model = outlines.models.transformers("mistralai/Mistral-7B-Instruct-v0.2")
generator = outlines.generate.choice(model, ["positive", "negative", "neutral"])

sentiment = generator("Review: 'Best purchase I've ever made!'")
print(sentiment)  # "positive" — always one of the three choices
```

### Regex-Constrained Generation
```python
import outlines

model = outlines.models.transformers("mistralai/Mistral-7B-Instruct-v0.2")

# Phone number
phone_gen = outlines.generate.regex(model, r"\(\d{3}\) \d{3}-\d{4}")
phone = phone_gen("Generate a US phone number: ")
print(phone)  # "(555) 867-5309"

# ISO date
date_gen = outlines.generate.regex(model, r"\d{4}-\d{2}-\d{2}")
date = date_gen("What date did WWII end? Answer: ")
print(date)  # "1945-09-02"
```

### Free Text with Stop Conditions
```python
import outlines

model = outlines.models.transformers("mistralai/Mistral-7B-Instruct-v0.2")
generator = outlines.generate.text(model)

answer = generator(
    "What is the capital of Japan?",
    max_tokens=50,
    stop_at=[".", "\n"],
)
print(answer)  # "Tokyo"
```

### Complex Nested Schema
```python
import outlines
from pydantic import BaseModel, Field
from typing import List
from enum import Enum

class Priority(str, Enum):
    low = "low"
    medium = "medium"
    high = "high"
    critical = "critical"

class BugReport(BaseModel):
    title: str = Field(max_length=100)
    priority: Priority
    affected_components: List[str]
    steps_to_reproduce: List[str]
    expected_behavior: str
    actual_behavior: str

model = outlines.models.transformers("mistralai/Mistral-7B-Instruct-v0.2")
generator = outlines.generate.json(model, BugReport)

report = generator(
    "User report: The login button does nothing when clicked on mobile Safari. "
    "Other browsers work fine. This is blocking users from signing in."
)
print(report.priority)  # "high" or "critical"
print(report.affected_components)  # ["auth", "mobile", "safari"]
```

### Batch Generation
```python
import outlines
from pydantic import BaseModel

class Entity(BaseModel):
    name: str
    entity_type: str  # person, org, location

model = outlines.models.transformers("mistralai/Mistral-7B-Instruct-v0.2")
generator = outlines.generate.json(model, Entity)

texts = [
    "Apple Inc. announced new products today.",
    "Elon Musk tweeted about Mars colonization.",
    "The Eiffel Tower was completed in 1889.",
]

results = generator(texts)  # batch processing
for entity in results:
    print(f"{entity.name}: {entity.entity_type}")
```

### vLLM Backend for High Throughput
```python
import outlines

# Use vLLM for production serving
model = outlines.models.vllm("mistralai/Mistral-7B-Instruct-v0.2")
generator = outlines.generate.json(model, MySchema)
```

## Common Pitfalls

- **Schema complexity**: very deep nested schemas or large enums slow down FSM compilation; cache generators
- **Cache generators**: `outlines.generate.json(model, Schema)` compiles FSMs — reuse the generator, don't recreate it per call
- **Model compatibility**: regex constraints work best with local models; OpenAI support is limited to JSON mode
- **Max tokens**: always set `max_tokens` or generation may run indefinitely for some backends
- **Pydantic v1 vs v2**: Outlines supports both but behavior differs; use Pydantic v2 for best results
- **CUDA memory**: transformers backend loads full model into GPU; ensure sufficient VRAM

## Related Skills

- `guidance` — Microsoft's alternative structured generation with template syntax
- `instructor` — Pydantic-based structured output (retries, validation)
- `structured-generation` — overview of constrained decoding
- `vllm-serving` — high-throughput serving backend for Outlines
- `structured-output-extraction` — general structured extraction patterns

## GitNexus Index

```
tool: outlines
category: structured-generation
tier: library
interface: python-api
platform: cross-platform
stars: 11000+
```
