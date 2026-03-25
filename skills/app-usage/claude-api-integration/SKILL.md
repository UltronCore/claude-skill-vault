---
name: claude-api-integration
description: Integrate the Anthropic Claude API into any project using the official SDKs. Reference for Python, TypeScript, Go, PHP, and Ruby implementations. Use when building applications that call Claude directly via API. Trigger when users mention Anthropic API, Claude API, anthropic SDK, claude client, or API integration.
---

# Claude API Integration

Official SDK patterns for calling Claude across all major languages.

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

## Related skills
llm-routing-and-fallback, claude-usage-orchestrator, structured-output-extraction
