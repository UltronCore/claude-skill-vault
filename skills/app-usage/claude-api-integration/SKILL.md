---
name: claude-api-integration
description: Integrate the Anthropic Claude API into any project using the official SDKs, with structured output extraction patterns. Reference for Python, TypeScript, Go implementations, tool_use for guaranteed-structured JSON, instructor library, and pydantic-ai agents. Use when building applications that call Claude directly via API. Trigger when users mention Anthropic API, Claude API, anthropic SDK, claude client, API integration, structured output, or typed responses.
---

# Claude API Integration

Official SDK patterns for calling Claude across all major languages, plus structured output extraction.

## Python
```python
pip install anthropic

from anthropic import Anthropic

client = Anthropic()  # uses ANTHROPIC_API_KEY env var

# Basic call
response = client.messages.create(
    model="claude-sonnet-4-6",
    max_tokens=1024,
    messages=[{"role": "user", "content": "Hello"}]
)
print(response.content[0].text)

# Streaming
with client.messages.stream(
    model="claude-sonnet-4-6",
    max_tokens=1024,
    messages=[{"role": "user", "content": "Count to 5"}]
) as stream:
    for text in stream.text_stream:
        print(text, end="", flush=True)

# Tool use
tools = [{
    "name": "get_weather",
    "description": "Get weather for a city",
    "input_schema": {
        "type": "object",
        "properties": {"city": {"type": "string"}},
        "required": ["city"]
    }
}]
response = client.messages.create(
    model="claude-sonnet-4-6",
    max_tokens=1024,
    tools=tools,
    messages=[{"role": "user", "content": "What's the weather in NYC?"}]
)
```

## TypeScript
```typescript
import Anthropic from "@anthropic-ai/sdk";

const client = new Anthropic();

const response = await client.messages.create({
    model: "claude-sonnet-4-6",
    max_tokens: 1024,
    messages: [{ role: "user", content: "Hello" }],
});
console.log(response.content[0].text);
```

## Go
```go
import "github.com/anthropics/anthropic-sdk-go"

client := anthropic.NewClient()
message, err := client.Messages.New(ctx, anthropic.MessageNewParams{
    Model:     anthropic.F(anthropic.ModelClaudeSonnet46),
    MaxTokens: anthropic.F(int64(1024)),
    Messages: anthropic.F([]anthropic.MessageParam{
        anthropic.NewUserMessage(anthropic.NewTextBlock("Hello")),
    }),
})
```

## Models reference
| Model | Use case | Cost |
|---|---|---|
| claude-haiku-4-5-20251001 | Fast, simple tasks | Cheapest |
| claude-sonnet-4-6 | Balanced | Mid |
| claude-opus-4-6 | Complex, creative | Most expensive |

## Environment setup
```bash
export ANTHROPIC_API_KEY="sk-ant-..."
# Never hardcode — always use env vars
```

---

## Structured Output Extraction

Force Claude to return guaranteed-typed output for code that parses responses.

### Pattern 1: tool_use (most reliable, no extra deps)
```python
import json

tools = [{
    "name": "extract_data",
    "description": "Extract structured data from text",
    "input_schema": {
        "type": "object",
        "properties": {
            "name": {"type": "string"},
            "sentiment": {"type": "string", "enum": ["positive", "negative", "neutral"]},
            "score": {"type": "number", "minimum": 0, "maximum": 10},
            "keywords": {"type": "array", "items": {"type": "string"}}
        },
        "required": ["name", "sentiment", "score"]
    }
}]

response = client.messages.create(
    model="claude-sonnet-4-6",
    max_tokens=1024,
    tools=tools,
    tool_choice={"type": "tool", "name": "extract_data"},
    messages=[{"role": "user", "content": "Analyze: Great product, love it! Score: 9/10"}]
)

result = json.loads(response.content[0].input)
# result = {"name": "product", "sentiment": "positive", "score": 9, "keywords": [...]}
```

### Pattern 2: instructor library (Pydantic integration)
```python
pip install instructor anthropic

import anthropic
import instructor
from pydantic import BaseModel

client = instructor.from_anthropic(anthropic.Anthropic())

class SentimentAnalysis(BaseModel):
    sentiment: str
    score: float
    reasoning: str

result = client.messages.create(
    model="claude-sonnet-4-6",
    max_tokens=1024,
    messages=[{"role": "user", "content": "Analyze sentiment: Best product ever!"}],
    response_model=SentimentAnalysis
)
# result.sentiment, result.score, result.reasoning are all typed
```

### Pattern 3: pydantic-ai agent (full agent systems)
```python
from pydantic_ai import Agent
from pydantic import BaseModel

class ExtractedData(BaseModel):
    title: str
    summary: str
    tags: list[str]

agent = Agent("anthropic:claude-sonnet-4-6", result_type=ExtractedData)
result = agent.run_sync("Extract from: ...")
print(result.data.title)  # typed, validated
```

### When to use each
- **tool_use** → No extra deps, most reliable, works with any SDK
- **instructor** → Complex schemas, automatic retry on validation failure
- **pydantic-ai** → Full agent systems needing typed state management

### Common pitfalls
- Don't use plain JSON prompting for critical parsing — models hallucinate formatting
- Always validate output even with tool_use (numbers can come as strings)
- For nested schemas, prefer tool_use over prompt-based JSON

## Related skills
llm-routing-and-fallback, claude-usage-orchestrator, llm-observability
