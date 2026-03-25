---
name: structured-output-extraction
description: Extract guaranteed structured, typed output from Claude using Pydantic models, JSON schemas, or constrained generation. Use when Claude must return data in a specific format (JSON, typed objects, tables) that will be parsed by code. Trigger when users mention structured output, JSON extraction, Pydantic models, instructor, typed responses, or output validation.
---

# Structured Output Extraction

Claude can be guided to return reliably structured output using tool_use, Pydantic schemas, or explicit JSON formatting.

## Pattern 1: tool_use for structured output (most reliable)
```python
from anthropic import Anthropic
import json

client = Anthropic()

# Define the schema as a tool
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
# result = {"name": "product", "sentiment": "positive", "score": 9, "keywords": ["great", "love"]}
```

## Pattern 2: instructor library
```python
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

## Pattern 3: Pydantic-AI agent
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

## When to use each pattern
- **tool_use** → No extra dependencies, most reliable, works with any SDK
- **instructor** → Complex schemas, automatic retry on validation failure, Pydantic ecosystem
- **pydantic-ai** → Full agent systems needing typed state management

## Common pitfalls
- Don't use plain JSON prompting for critical parsing — models hallucinate formatting
- Always validate output even with tool_use (numbers can come as strings)
- For nested schemas, prefer tool_use over prompt-based JSON

## Related skills
api-contracts-and-zod-validation, claude-api-integration
