---
name: mirascope
description: Clean, type-safe LLM API wrapper with structured outputs, streaming, and provider-agnostic interface
version: 1.0.0
tags: [llm, wrapper, python, structured-output, type-safe, provider-agnostic]
---

# Mirascope — Clean LLM API Wrapper

## Overview

Mirascope is a Python library that provides a clean, decorator-based interface to LLM APIs (OpenAI, Anthropic, Google, Groq, Cohere, etc.) with first-class Pydantic integration, streaming support, and automatic structured extraction. Its philosophy is to stay close to the provider APIs while eliminating boilerplate. Works with async, sync, streaming, and structured output with zero extra configuration.

GitHub: https://github.com/Mirascope/mirascope (1k+ stars)

## When to Use

- Clean, minimal LLM wrapper without heavy framework overhead
- Provider-agnostic code that can switch between OpenAI/Anthropic/Groq
- Structured extraction with Pydantic without manual JSON parsing
- Streaming LLM responses in sync or async Python
- Function calling/tool use across multiple providers uniformly

## Installation

```bash
pip install mirascope[openai]
# Or
pip install mirascope[anthropic]
pip install mirascope[google-generativeai]
pip install mirascope[groq]
```

## Key Patterns / Usage

### Basic Chat Completion
```python
from mirascope.core import openai, prompt_template

@openai.call("gpt-4o-mini")
@prompt_template("What is the capital of {country}?")
def get_capital(country: str): ...

response = get_capital(country="France")
print(response.content)  # "The capital of France is Paris."
```

### System Prompt + User Message
```python
from mirascope.core import openai, Messages

@openai.call("gpt-4o-mini")
def summarize(text: str) -> Messages.Type:
    return [
        Messages.System("You are a concise summarizer. Reply in 1-2 sentences."),
        Messages.User(f"Summarize: {text}"),
    ]

result = summarize("Long article text here...")
print(result.content)
```

### Anthropic Provider
```python
from mirascope.core import anthropic

@anthropic.call("claude-3-5-haiku-20241022")
@prompt_template("Explain {concept} simply")
def explain(concept: str): ...

response = explain(concept="quantum entanglement")
print(response.content)
```

### Structured Extraction with Pydantic
```python
from mirascope.core import openai
from pydantic import BaseModel

class BookInfo(BaseModel):
    title: str
    author: str
    year: int
    genre: str

@openai.call("gpt-4o-mini", response_model=BookInfo)
@prompt_template("Extract book info: {text}")
def extract_book(text: str): ...

book = extract_book(text="The Great Gatsby by F. Scott Fitzgerald, published 1925, a literary classic.")
print(book.title)   # "The Great Gatsby"
print(book.year)    # 1925
print(type(book))   # <class 'BookInfo'>
```

### Streaming
```python
from mirascope.core import openai, prompt_template

@openai.call("gpt-4o-mini", stream=True)
@prompt_template("Write a short story about {topic}")
def stream_story(topic: str): ...

for chunk, _ in stream_story(topic="a robot learning to paint"):
    print(chunk.content, end="", flush=True)
print()
```

### Async Support
```python
import asyncio
from mirascope.core import openai, prompt_template

@openai.call("gpt-4o-mini")
@prompt_template("Translate '{text}' to {language}")
async def translate(text: str, language: str): ...

async def main():
    result = await translate(text="Hello world", language="Spanish")
    print(result.content)  # "Hola mundo"

asyncio.run(main())
```

### Tool Use / Function Calling
```python
from mirascope.core import openai, BaseTool

class SearchWeb(BaseTool):
    """Search the web for information."""
    query: str
    
    def call(self) -> str:
        return f"Search results for: {self.query}"

@openai.call("gpt-4o", tools=[SearchWeb])
@prompt_template("Answer: {question}")
def answer_with_tools(question: str): ...

response = answer_with_tools(question="What happened in AI news today?")
if response.tool:
    tool = response.tool
    result = tool.call()
    print(result)
```

### Multi-Turn Conversation
```python
from mirascope.core import openai, Messages
from mirascope.core.openai import OpenAIMessageParam

@openai.call("gpt-4o-mini")
def chat(history: list[OpenAIMessageParam], user_message: str) -> Messages.Type:
    return [
        *history,
        Messages.User(user_message),
    ]

history = []
while True:
    user_input = input("You: ")
    response = chat(history=history, user_message=user_input)
    print(f"AI: {response.content}")
    history += response.message_param_stack
```

### Provider Switching
```python
# Switch providers by changing the decorator — same function body
from mirascope.core import openai, anthropic, groq

# OpenAI
@openai.call("gpt-4o-mini")
@prompt_template("What is {x} + {y}?")
def add_openai(x: int, y: int): ...

# Anthropic
@anthropic.call("claude-3-5-haiku-20241022")
@prompt_template("What is {x} + {y}?")
def add_anthropic(x: int, y: int): ...

# Same logic, different provider
```

## Common Pitfalls

- **Provider-specific features**: some features (extended thinking, Anthropic system prompts) need provider-specific handling
- **Response model validation**: Pydantic validation errors bubble up — add try/except for production
- **Streaming + structured output**: streaming with `response_model` is supported but returns partial objects; use carefully
- **Tool call handling**: always check `response.tool` before calling; it's None if model didn't call a tool
- **History management**: conversation history grows indefinitely; implement truncation for long conversations

## Related Skills

- `instructor` — alternative for structured extraction (more retry logic)
- `litellm-proxy` — unified proxy with provider switching
- `structured-output-extraction` — general structured extraction patterns
- `claude-api-skill` — direct Anthropic SDK usage

## GitNexus Index

```
tool: mirascope
category: llm-client
tier: library
interface: python-sdk
platform: cross-platform
stars: 1000+
```
