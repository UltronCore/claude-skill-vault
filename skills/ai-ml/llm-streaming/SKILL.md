---
name: llm-streaming
description: >
  Streaming LLM responses with server-sent events (SSE), React streaming UI patterns, and backend streaming APIs. Triggers on: stream=True, MessageStreamEvent, ReadableStream, SSE, text_delta, EventSource, streaming response.
---

# LLM Streaming

## When to Use
- Streaming Claude or other LLM responses to the client
- Building Next.js App Router API routes that stream
- Creating React components that render streaming text
- Handling `text_delta` events from the Anthropic SDK
- Setting up SSE (Server-Sent Events) endpoints
- Streaming responses that include tool use

## Core Rules
1. Always set the response `Content-Type` to `text/event-stream` for SSE; set `Cache-Control: no-cache` and `Connection: keep-alive`.
2. Each SSE message must end with `\n\n` (double newline) — single newline is continuation, not a message boundary.
3. Use `TransformStream` or `ReadableStream` in Next.js App Router — `res.write()` is Pages Router only.
4. Flush the stream on each chunk — buffering defeats the purpose of streaming.
5. Always handle stream errors and send a terminal event (`[DONE]` or a typed error event) so clients don't hang.
6. When streaming with tool use, buffer tool input JSON until the `input_json` delta is complete — never parse partial JSON.
7. Use `AbortController` on the client to cancel in-flight streams when the user navigates away.
8. Token counts are only available at stream end via `message_stop` event — not during stream.
9. In React, append chunks to state with a functional updater: `setText(prev => prev + chunk)` to avoid stale closure bugs.
10. Test streams locally with `curl -N` (no buffering) before wiring to a frontend.

## Anthropic SDK Streaming (Python)

```python
import anthropic

client = anthropic.Anthropic()

# Method 1: stream() context manager (recommended)
with client.messages.stream(
    model="claude-opus-4-5",
    max_tokens=1024,
    messages=[{"role": "user", "content": "Write a short story about a robot."}],
) as stream:
    for text in stream.text_stream:
        print(text, end="", flush=True)
    # Access final message after stream ends
    final_message = stream.get_final_message()
    print(f"\n\nInput tokens: {final_message.usage.input_tokens}")

# Method 2: raw event iteration
with client.messages.stream(
    model="claude-opus-4-5",
    max_tokens=1024,
    messages=[{"role": "user", "content": "Hello!"}],
) as stream:
    for event in stream:
        if event.type == "content_block_delta":
            if event.delta.type == "text_delta":
                print(event.delta.text, end="", flush=True)
        elif event.type == "message_stop":
            print("\n[Stream complete]")

# Method 3: async streaming
import asyncio
import anthropic

async def stream_async():
    client = anthropic.AsyncAnthropic()
    async with client.messages.stream(
        model="claude-opus-4-5",
        max_tokens=1024,
        messages=[{"role": "user", "content": "Tell me a joke."}],
    ) as stream:
        async for text in stream.text_stream:
            print(text, end="", flush=True)

asyncio.run(stream_async())
```

## Anthropic SDK Streaming (TypeScript)

```typescript
import Anthropic from "@anthropic-ai/sdk";

const client = new Anthropic();

// Method 1: stream() with text helper
const stream = client.messages.stream({
  model: "claude-opus-4-5",
  max_tokens: 1024,
  messages: [{ role: "user", content: "Write a haiku." }],
});

stream.on("text", (text) => {
  process.stdout.write(text);
});

const finalMessage = await stream.finalMessage();
console.log(`\nTokens used: ${finalMessage.usage.input_tokens}`);

// Method 2: async iteration over events
const stream2 = await client.messages.create({
  model: "claude-opus-4-5",
  max_tokens: 1024,
  stream: true,
  messages: [{ role: "user", content: "Hello!" }],
});

for await (const event of stream2) {
  if (
    event.type === "content_block_delta" &&
    event.delta.type === "text_delta"
  ) {
    process.stdout.write(event.delta.text);
  }
}
```

## Next.js App Router SSE Route Handler

```typescript
// app/api/chat/route.ts
import Anthropic from "@anthropic-ai/sdk";
import { NextRequest } from "next/server";

const client = new Anthropic();

export async function POST(req: NextRequest) {
  const { messages, system } = await req.json();

  const encoder = new TextEncoder();

  const stream = new ReadableStream({
    async start(controller) {
      try {
        const anthropicStream = client.messages.stream({
          model: "claude-opus-4-5",
          max_tokens: 2048,
          system: system ?? "You are a helpful assistant.",
          messages,
        });

        anthropicStream.on("text", (text) => {
          // SSE format: "data: <payload>\n\n"
          controller.enqueue(
            encoder.encode(`data: ${JSON.stringify({ text })}\n\n`)
          );
        });

        anthropicStream.on("error", (error) => {
          controller.enqueue(
            encoder.encode(
              `data: ${JSON.stringify({ error: error.message })}\n\n`
            )
          );
          controller.close();
        });

        await anthropicStream.finalMessage();
        controller.enqueue(encoder.encode(`data: [DONE]\n\n`));
        controller.close();
      } catch (error) {
        controller.enqueue(
          encoder.encode(`data: ${JSON.stringify({ error: String(error) })}\n\n`)
        );
        controller.close();
      }
    },
  });

  return new Response(stream, {
    headers: {
      "Content-Type": "text/event-stream",
      "Cache-Control": "no-cache",
      Connection: "keep-alive",
    },
  });
}
```

## React Streaming UI Hook

```typescript
// hooks/useStreamingChat.ts
import { useState, useCallback, useRef } from "react";

interface Message {
  role: "user" | "assistant";
  content: string;
}

export function useStreamingChat() {
  const [messages, setMessages] = useState<Message[]>([]);
  const [streamingText, setStreamingText] = useState("");
  const [isStreaming, setIsStreaming] = useState(false);
  const abortRef = useRef<AbortController | null>(null);

  const sendMessage = useCallback(async (userMessage: string) => {
    const newMessages: Message[] = [
      ...messages,
      { role: "user", content: userMessage },
    ];
    setMessages(newMessages);
    setStreamingText("");
    setIsStreaming(true);

    // Cancel any existing stream
    abortRef.current?.abort();
    abortRef.current = new AbortController();

    try {
      const response = await fetch("/api/chat", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ messages: newMessages }),
        signal: abortRef.current.signal,
      });

      if (!response.body) throw new Error("No response body");

      const reader = response.body.getReader();
      const decoder = new TextDecoder();
      let accumulated = "";

      while (true) {
        const { done, value } = await reader.read();
        if (done) break;

        const chunk = decoder.decode(value, { stream: true });
        // Parse SSE lines
        for (const line of chunk.split("\n")) {
          if (!line.startsWith("data: ")) continue;
          const data = line.slice(6);
          if (data === "[DONE]") break;

          try {
            const parsed = JSON.parse(data);
            if (parsed.text) {
              accumulated += parsed.text;
              // Functional updater avoids stale closure
              setStreamingText((prev) => prev + parsed.text);
            }
          } catch {
            // Ignore parse errors on incomplete chunks
          }
        }
      }

      // Commit streaming text to messages
      setMessages((prev) => [
        ...prev,
        { role: "assistant", content: accumulated },
      ]);
      setStreamingText("");
    } catch (error) {
      if ((error as Error).name !== "AbortError") {
        console.error("Stream error:", error);
      }
    } finally {
      setIsStreaming(false);
    }
  }, [messages]);

  const stop = useCallback(() => {
    abortRef.current?.abort();
    setIsStreaming(false);
  }, []);

  return { messages, streamingText, isStreaming, sendMessage, stop };
}
```

## React Streaming Chat Component

```typescript
// components/StreamingChat.tsx
"use client";
import { useStreamingChat } from "@/hooks/useStreamingChat";
import { useState } from "react";

export function StreamingChat() {
  const { messages, streamingText, isStreaming, sendMessage, stop } =
    useStreamingChat();
  const [input, setInput] = useState("");

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!input.trim() || isStreaming) return;
    sendMessage(input);
    setInput("");
  };

  return (
    <div className="flex flex-col h-screen max-w-2xl mx-auto p-4">
      <div className="flex-1 overflow-y-auto space-y-4 mb-4">
        {messages.map((msg, i) => (
          <div key={i} className={`p-3 rounded-lg ${msg.role === "user" ? "bg-blue-100 ml-auto" : "bg-gray-100"}`}>
            <p className="whitespace-pre-wrap">{msg.content}</p>
          </div>
        ))}
        {isStreaming && streamingText && (
          <div className="p-3 rounded-lg bg-gray-100">
            <p className="whitespace-pre-wrap">
              {streamingText}
              <span className="animate-pulse">▊</span>
            </p>
          </div>
        )}
      </div>

      <form onSubmit={handleSubmit} className="flex gap-2">
        <input
          value={input}
          onChange={(e) => setInput(e.target.value)}
          className="flex-1 border rounded-lg px-3 py-2"
          placeholder="Type a message..."
          disabled={isStreaming}
        />
        {isStreaming ? (
          <button onClick={stop} className="px-4 py-2 bg-red-500 text-white rounded-lg">
            Stop
          </button>
        ) : (
          <button type="submit" className="px-4 py-2 bg-blue-500 text-white rounded-lg">
            Send
          </button>
        )}
      </form>
    </div>
  );
}
```

## Python FastAPI Streaming Endpoint

```python
from fastapi import FastAPI
from fastapi.responses import StreamingResponse
import anthropic
import json

app = FastAPI()
client = anthropic.Anthropic()

@app.post("/api/chat")
async def chat_stream(body: dict):
    messages = body.get("messages", [])

    def generate():
        with client.messages.stream(
            model="claude-opus-4-5",
            max_tokens=2048,
            messages=messages,
        ) as stream:
            for text in stream.text_stream:
                # SSE format
                yield f"data: {json.dumps({'text': text})}\n\n"
            yield "data: [DONE]\n\n"

    return StreamingResponse(
        generate(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",  # Disable nginx buffering
        },
    )
```

## Streaming with Tool Use

```python
# Buffer tool input JSON — never parse partial JSON
tool_input_buffer = {}

with client.messages.stream(
    model="claude-opus-4-5",
    max_tokens=2048,
    tools=tools,
    messages=messages,
) as stream:
    current_tool_use_id = None
    current_tool_name = None
    input_json_buffer = ""

    for event in stream:
        if event.type == "content_block_start":
            if event.content_block.type == "tool_use":
                current_tool_use_id = event.content_block.id
                current_tool_name = event.content_block.name
                input_json_buffer = ""

        elif event.type == "content_block_delta":
            if event.delta.type == "text_delta":
                print(event.delta.text, end="", flush=True)
            elif event.delta.type == "input_json_delta":
                # Buffer — do NOT parse yet
                input_json_buffer += event.delta.partial_json

        elif event.type == "content_block_stop":
            if current_tool_use_id and input_json_buffer:
                # Now safe to parse complete JSON
                tool_input = json.loads(input_json_buffer)
                print(f"\n[Tool call] {current_tool_name}: {tool_input}")
                current_tool_use_id = None
                input_json_buffer = ""
```

## SSE Event Format Reference

```
# Standard SSE format:
data: {"text": "Hello"}\n\n

# With event type:
event: message\n
data: {"text": "Hello"}\n\n

# Keepalive (comment):
: ping\n\n

# Terminal signal:
data: [DONE]\n\n

# Multi-line data (rare):
data: line one\n
data: line two\n\n
```

## Token Counting During Stream

```python
# Tokens are only available at stream end
with client.messages.stream(...) as stream:
    for text in stream.text_stream:
        print(text, end="", flush=True)

    # Get final usage AFTER stream completes
    final = stream.get_final_message()
    print(f"\nInput: {final.usage.input_tokens} | Output: {final.usage.output_tokens}")
```

## Buffering Strategy for Smooth UI

```typescript
// Throttle state updates to avoid re-render thrashing
let buffer = "";
let rafId: number | null = null;

function flushBuffer() {
  setStreamingText((prev) => prev + buffer);
  buffer = "";
  rafId = null;
}

// In your stream reader loop:
buffer += chunk;
if (!rafId) {
  rafId = requestAnimationFrame(flushBuffer);
}
```

## Debugging Streams

```bash
# Test your SSE endpoint without a browser
curl -N -X POST http://localhost:3000/api/chat \
  -H "Content-Type: application/json" \
  -d '{"messages":[{"role":"user","content":"Hello"}]}'

# -N disables curl buffering so you see chunks as they arrive
```

## Related Skills
- `claude-api-skill` — streaming with Claude
- `websocket-realtime` — streaming over WebSockets
- `streaming-llm-responses` — response streaming patterns

## GitNexus Index
This skill is indexed by GitNexus for knowledge graph traversal.
Index path: /Users/localuser/.claude/skills/llm-streaming/.gitnexus
Last indexed: 2026-05-23
