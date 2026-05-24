---
name: guidance
description: Microsoft's structured generation library for constrained LLM outputs using Handlebars-style templates
version: 1.0.0
tags: [llm, structured-generation, constrained-decoding, microsoft, templates]
---

# Guidance — Structured LLM Generation (Microsoft)

## Overview

Guidance (by Microsoft) is a Python library for constrained LLM generation that interleaves generation with control flow. Unlike prompt engineering, Guidance programs interleave text generation with Python logic, enabling token-level constraints (regex, grammars, selects), JSON schema enforcement, and stateful multi-turn generation. Works with local models (llama.cpp, transformers) and cloud APIs (OpenAI, Anthropic).

GitHub: https://github.com/guidance-ai/guidance (19k+ stars)

## When to Use

- Enforcing strict output formats (JSON, XML, code) at the token level
- Building structured extraction pipelines without post-processing
- Constrained decoding for classification, slot-filling, or form completion
- Multi-turn agentic loops with guaranteed schema conformance
- When regex or grammar constraints on generation are needed

## Installation

```bash
pip install guidance

# For local llama.cpp support
pip install guidance[llamacpp]

# For transformers support
pip install guidance[transformers]
```

## Key Patterns / Usage

### Basic Template Generation
```python
import guidance
from guidance import models, gen

# Use OpenAI
lm = models.OpenAI("gpt-4o-mini")

# Or local llama.cpp
# lm = models.LlamaCpp("path/to/model.gguf")

# Simple generation
lm += "The capital of France is " + gen("capital", stop=".")
print(lm["capital"])  # → "Paris"
```

### Select (Classification)
```python
from guidance import select

lm = models.OpenAI("gpt-4o-mini")

lm += f"""Classify the sentiment of this review:
Review: "The product was amazing and exceeded expectations!"
Sentiment: """ + select(["positive", "negative", "neutral"], name="sentiment")

print(lm["sentiment"])  # → "positive" (guaranteed)
```

### JSON Schema Enforcement
```python
from guidance import json as guidance_json
from pydantic import BaseModel
from typing import List

class Person(BaseModel):
    name: str
    age: int
    hobbies: List[str]

lm = models.OpenAI("gpt-4o-mini")
lm += "Extract person info: John is 30 and loves hiking and cooking.\n"
lm += guidance_json(name="person", schema=Person)

import json
person = json.loads(lm["person"])
print(person)  # {"name": "John", "age": 30, "hobbies": ["hiking", "cooking"]}
```

### Regex Constraints
```python
from guidance import regex

lm = models.OpenAI("gpt-4o-mini")

# Extract phone number in exact format
lm += "Customer phone: " + regex(r"\(\d{3}\) \d{3}-\d{4}", name="phone")
print(lm["phone"])  # → "(555) 123-4567"

# Extract date
lm += "\nDate of birth: " + regex(r"\d{4}-\d{2}-\d{2}", name="dob")
```

### Multi-Step Conditional Generation
```python
from guidance import system, user, assistant, gen, select

@guidance
def analyze_code(lm, code):
    lm += system("You are a code reviewer.")
    lm += user(f"Review this code:\n```python\n{code}\n```")
    lm += assistant(
        "Severity: " + select(["low", "medium", "high", "critical"], name="severity") + "\n"
        "Issues found: " + gen("issues", max_tokens=200) + "\n"
        "Suggested fix: " + gen("fix", max_tokens=300)
    )
    return lm

lm = models.OpenAI("gpt-4o-mini")
result = analyze_code(lm, "x = input(); eval(x)")
print(result["severity"])  # → "critical"
print(result["issues"])
```

### Grammar-Constrained Generation
```python
from guidance import grammar

# Define a simple grammar for arithmetic expressions
arithmetic_grammar = r"""
expression: term (('+' | '-') term)*
term: factor (('*' | '/') factor)*
factor: NUMBER | '(' expression ')'
NUMBER: /\d+(\.\d+)?/
"""

lm = models.OpenAI("gpt-4o-mini")
lm += "Compute 2+3*4: " + grammar(arithmetic_grammar, name="result")
```

### Stateful Chat with Variables
```python
from guidance import system, user, assistant, gen

@guidance
def chat_with_extraction(lm, messages):
    lm += system("Extract key info from conversations.")
    for msg in messages:
        lm += user(msg)
        lm += assistant(gen("response", max_tokens=100))
    
    lm += user("Summarize the key topics discussed.")
    lm += assistant(
        "Topics: " + gen("topics", stop="\n") + "\n"
        "Action items: " + gen("actions", stop="\n")
    )
    return lm

lm = models.OpenAI("gpt-4o-mini")
result = chat_with_extraction(lm, ["Tell me about Python", "What about async?"])
print(result["topics"])
print(result["actions"])
```

### Token Healing
```python
# Guidance handles token boundary issues automatically
# Tokens at boundaries are "healed" for consistent generation
lm = models.LlamaCpp("model.gguf")
lm += 'The color of the sky is "' + gen("color", stop='"')
# Works correctly even at quotation mark token boundaries
```

## Common Pitfalls

- **API vs local behavior**: JSON schema and grammar constraints work best with local models (llama.cpp/transformers); cloud APIs may fall back to prompt-based guidance
- **Context accumulation**: the `lm +=` pattern is additive — the context grows with each operation; manage token limits manually
- **OpenAI function calling**: for OpenAI, use tool_choice/response_format instead of guidance for better performance
- **Streaming**: guidance streams tokens but final variables are only available after generation completes
- **Select case sensitivity**: `select(["Yes", "No"])` — the options must exactly match what the model would generate
- **Version compatibility**: guidance API changed significantly between 0.0.x and 0.1.x — always check docs for your version

## Related Skills

- `outlines` — alternative structured generation library (JSON schema, regex)
- `structured-output-extraction` — general structured extraction patterns
- `instructor` — Pydantic-based structured output for OpenAI/Anthropic
- `structured-generation` — overview of constrained decoding approaches

## GitNexus Index

```
tool: guidance
category: structured-generation
tier: library
interface: python-api
platform: cross-platform
stars: 19000+
```
