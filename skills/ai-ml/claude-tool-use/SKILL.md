---
name: claude-tool-use
description: >
  Advanced Claude tool/function calling patterns: tool definitions, parallel tool use, tool result chaining, and agentic loops. Triggers on: tool_use, tools=, ToolUseBlock, ToolResultBlock, function calling, tool result, agentic loop.
---

# Claude Tool Use

## When to Use
- Defining tools/functions for Claude to call
- Handling `ToolUseBlock` in API responses
- Sending tool results back to continue the conversation
- Building agentic loops that run until Claude stops using tools
- Implementing parallel tool calls
- Debugging tool use errors or unexpected stop reasons

## Core Rules
1. Always check `response.stop_reason == "tool_use"` — this is the signal to execute tools and continue.
2. Every `ToolUseBlock` needs a corresponding `ToolResultBlock` in the next user message.
3. Pass the entire `response.content` (including any `TextBlock`s) back as the assistant message in the loop.
4. Tool input schemas use JSON Schema — use `type: "object"` at root with `properties` and `required`.
5. A tool result with `is_error: true` tells Claude the tool failed — Claude will decide how to recover.
6. Use `tool_choice={"type": "any"}` to force Claude to call at least one tool.
7. Use `tool_choice={"type": "tool", "name": "specific_tool"}` to force a specific tool.
8. Parallel tool calls are native — Claude may call multiple tools in one response; handle all of them.
9. Set a max iteration limit on agentic loops to prevent runaway execution.
10. Tools with side effects (write, delete, send) should confirm with the user before executing in production.

## Tool Definition Schema

```python
tools = [
    {
        "name": "get_weather",
        "description": "Get current weather for a city. Returns temperature and conditions.",
        "input_schema": {
            "type": "object",
            "properties": {
                "city": {
                    "type": "string",
                    "description": "City name, e.g. 'San Francisco, CA'"
                },
                "unit": {
                    "type": "string",
                    "enum": ["celsius", "fahrenheit"],
                    "description": "Temperature unit. Defaults to fahrenheit."
                }
            },
            "required": ["city"]
        }
    },
    {
        "name": "search_web",
        "description": "Search the web and return top results with snippets.",
        "input_schema": {
            "type": "object",
            "properties": {
                "query": {"type": "string", "description": "Search query"},
                "num_results": {"type": "integer", "description": "Number of results, 1-10", "default": 3}
            },
            "required": ["query"]
        }
    }
]
```

## Basic Tool Use (Python)

```python
import anthropic
import json

client = anthropic.Anthropic()

def run_tool(tool_name: str, tool_input: dict) -> str:
    """Execute a tool and return the result as a string."""
    if tool_name == "get_weather":
        # Replace with real implementation
        return json.dumps({"temperature": 72, "conditions": "sunny", "city": tool_input["city"]})
    elif tool_name == "search_web":
        return json.dumps({"results": [{"title": "Example", "snippet": "..."}]})
    else:
        raise ValueError(f"Unknown tool: {tool_name}")

def chat_with_tools(user_message: str) -> str:
    messages = [{"role": "user", "content": user_message}]

    response = client.messages.create(
        model="claude-opus-4-5",
        max_tokens=4096,
        tools=tools,
        messages=messages,
    )

    # Handle tool use in a loop
    while response.stop_reason == "tool_use":
        # Collect all tool calls from the response
        tool_use_blocks = [b for b in response.content if b.type == "tool_use"]

        # Add assistant's response (including TextBlocks) to messages
        messages.append({"role": "assistant", "content": response.content})

        # Execute all tool calls and collect results
        tool_results = []
        for tool_use in tool_use_blocks:
            try:
                result = run_tool(tool_use.name, tool_use.input)
                tool_results.append({
                    "type": "tool_result",
                    "tool_use_id": tool_use.id,
                    "content": result,
                })
            except Exception as e:
                tool_results.append({
                    "type": "tool_result",
                    "tool_use_id": tool_use.id,
                    "content": str(e),
                    "is_error": True,
                })

        # Add tool results as user message
        messages.append({"role": "user", "content": tool_results})

        # Continue the conversation
        response = client.messages.create(
            model="claude-opus-4-5",
            max_tokens=4096,
            tools=tools,
            messages=messages,
        )

    # Extract final text response
    return next(
        (b.text for b in response.content if hasattr(b, "text")), ""
    )

result = chat_with_tools("What's the weather in Tokyo and Paris?")
print(result)
```

## Agentic Loop with Max Iterations

```python
import anthropic
from typing import Callable

client = anthropic.Anthropic()

def agentic_loop(
    user_message: str,
    tools: list[dict],
    tool_executor: Callable[[str, dict], str],
    model: str = "claude-opus-4-5",
    max_iterations: int = 10,
    system: str = None,
) -> str:
    messages = [{"role": "user", "content": user_message}]
    kwargs = {"model": model, "max_tokens": 4096, "tools": tools, "messages": messages}
    if system:
        kwargs["system"] = system

    for iteration in range(max_iterations):
        response = client.messages.create(**kwargs)

        if response.stop_reason == "end_turn":
            # Claude is done
            return next((b.text for b in response.content if hasattr(b, "text")), "")

        if response.stop_reason == "max_tokens":
            raise RuntimeError("Hit max_tokens limit mid-response")

        if response.stop_reason != "tool_use":
            # Unexpected stop reason
            return next((b.text for b in response.content if hasattr(b, "text")), "")

        # Process tool calls
        messages.append({"role": "assistant", "content": response.content})
        tool_results = []

        for block in response.content:
            if block.type != "tool_use":
                continue
            try:
                print(f"[Tool] {block.name}({block.input})")
                result = tool_executor(block.name, block.input)
                tool_results.append({
                    "type": "tool_result",
                    "tool_use_id": block.id,
                    "content": result,
                })
            except Exception as e:
                tool_results.append({
                    "type": "tool_result",
                    "tool_use_id": block.id,
                    "content": f"Error: {e}",
                    "is_error": True,
                })

        messages.append({"role": "user", "content": tool_results})
        kwargs["messages"] = messages

    raise RuntimeError(f"Exceeded max iterations ({max_iterations})")
```

## TypeScript Tool Use

```typescript
import Anthropic from "@anthropic-ai/sdk";

const client = new Anthropic();

const tools: Anthropic.Tool[] = [
  {
    name: "read_file",
    description: "Read contents of a file by path",
    input_schema: {
      type: "object" as const,
      properties: {
        path: { type: "string", description: "File path to read" },
      },
      required: ["path"],
    },
  },
  {
    name: "write_file",
    description: "Write content to a file",
    input_schema: {
      type: "object" as const,
      properties: {
        path: { type: "string" },
        content: { type: "string" },
      },
      required: ["path", "content"],
    },
  },
];

async function executeTool(name: string, input: Record<string, unknown>): Promise<string> {
  if (name === "read_file") {
    const { readFileSync } = await import("fs");
    return readFileSync(input.path as string, "utf-8");
  }
  if (name === "write_file") {
    const { writeFileSync } = await import("fs");
    writeFileSync(input.path as string, input.content as string);
    return "File written successfully";
  }
  throw new Error(`Unknown tool: ${name}`);
}

async function agenticLoop(userMessage: string): Promise<string> {
  const messages: Anthropic.MessageParam[] = [
    { role: "user", content: userMessage },
  ];

  for (let i = 0; i < 10; i++) {
    const response = await client.messages.create({
      model: "claude-opus-4-5",
      max_tokens: 4096,
      tools,
      messages,
    });

    if (response.stop_reason === "end_turn") {
      return response.content
        .filter((b): b is Anthropic.TextBlock => b.type === "text")
        .map((b) => b.text)
        .join("");
    }

    messages.push({ role: "assistant", content: response.content });

    const toolResults: Anthropic.ToolResultBlockParam[] = [];
    for (const block of response.content) {
      if (block.type !== "tool_use") continue;
      try {
        const result = await executeTool(block.name, block.input as Record<string, unknown>);
        toolResults.push({ type: "tool_result", tool_use_id: block.id, content: result });
      } catch (e) {
        toolResults.push({
          type: "tool_result",
          tool_use_id: block.id,
          content: String(e),
          is_error: true,
        });
      }
    }

    messages.push({ role: "user", content: toolResults });
  }

  throw new Error("Max iterations exceeded");
}
```

## Tool Choice Options

```python
# Default: Claude decides whether/which tools to use
tool_choice = {"type": "auto"}

# Force Claude to use at least one tool
tool_choice = {"type": "any"}

# Force Claude to use a specific tool
tool_choice = {"type": "tool", "name": "search_web"}

# Disable tools entirely (even if tools= is set)
tool_choice = {"type": "none"}

response = client.messages.create(
    model="claude-opus-4-5",
    max_tokens=1024,
    tools=tools,
    tool_choice={"type": "any"},  # Must call a tool
    messages=messages,
)
```

## Parallel Tool Calls

Claude may call multiple tools in one response. Always handle all of them:

```python
# Response might have multiple ToolUseBlocks
response_content = [
    TextBlock(text="Let me check both cities."),
    ToolUseBlock(id="tu_1", name="get_weather", input={"city": "Tokyo"}),
    ToolUseBlock(id="tu_2", name="get_weather", input={"city": "Paris"}),
]

# Correct: process ALL tool calls, return ALL results in one user message
tool_results = []
for block in response_content:
    if block.type == "tool_use":
        result = run_tool(block.name, block.input)
        tool_results.append({
            "type": "tool_result",
            "tool_use_id": block.id,  # Must match the id from the ToolUseBlock
            "content": result,
        })
# Send ALL results in one message (not one per turn)
messages.append({"role": "user", "content": tool_results})
```

## Multi-Content Tool Results

Tool results can contain text, images, or multiple parts:

```python
# Text result
{"type": "tool_result", "tool_use_id": "tu_1", "content": "72°F, sunny"}

# Structured JSON result
{"type": "tool_result", "tool_use_id": "tu_1", "content": json.dumps({"temp": 72, "unit": "F"})}

# Multi-part result (text + image)
{
    "type": "tool_result",
    "tool_use_id": "tu_1",
    "content": [
        {"type": "text", "text": "Here is the chart:"},
        {
            "type": "image",
            "source": {
                "type": "base64",
                "media_type": "image/png",
                "data": base64_chart_data,
            }
        }
    ]
}

# Error result
{"type": "tool_result", "tool_use_id": "tu_1", "content": "File not found", "is_error": True}
```

## Stop Reason Decision Table

| `stop_reason` | Meaning | Action |
|--------------|---------|--------|
| `"end_turn"` | Claude is done | Extract text, return to user |
| `"tool_use"` | Needs tool results | Execute tools, send results, continue loop |
| `"max_tokens"` | Hit token limit | Increase `max_tokens` or truncate context |
| `"stop_sequence"` | Hit a stop sequence | Extract text up to stop sequence |

## Computer Use Tool (Special)

```python
# Computer use requires a special beta header and specific tools
client = anthropic.Anthropic()

response = client.beta.messages.create(
    model="claude-opus-4-5",
    max_tokens=4096,
    tools=[
        {"type": "computer_20241022", "name": "computer", "display_width_px": 1280, "display_height_px": 800},
        {"type": "text_editor_20241022", "name": "str_replace_editor"},
        {"type": "bash_20241022", "name": "bash"},
    ],
    messages=[{"role": "user", "content": "Open the terminal and run ls -la"}],
    betas=["computer-use-2024-10-22"],
)
```

## Common Pitfalls

```python
# WRONG: Forgetting to include TextBlocks in the assistant message
messages.append({"role": "assistant", "content": [tool_use_block]})  # Missing TextBlock!

# CORRECT: Pass entire response.content
messages.append({"role": "assistant", "content": response.content})

# WRONG: Sending tool results in separate messages
messages.append({"role": "user", "content": [result_1]})
messages.append({"role": "user", "content": [result_2]})  # Error!

# CORRECT: All tool results in one user message
messages.append({"role": "user", "content": [result_1, result_2]})

# WRONG: Missing tool_use_id (must match ToolUseBlock.id exactly)
{"type": "tool_result", "tool_use_id": "made_up_id", "content": "..."}

# CORRECT
{"type": "tool_result", "tool_use_id": tool_use_block.id, "content": "..."}
```
