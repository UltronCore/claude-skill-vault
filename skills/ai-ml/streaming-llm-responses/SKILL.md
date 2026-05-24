---
name: streaming-llm-responses
description: Implement streaming LLM responses with server-sent events (SSE), WebSockets, and proper backpressure handling. Covers Anthropic/OpenAI streaming APIs, Next.js streaming routes, React streaming UI with useChat, and production patterns for real-time token delivery.
version: 1.0.0
tags: [streaming, llm, server-sent-events, sse, websocket, anthropic, openai, real-time, nextjs]
---

# Streaming LLM Responses

## Overview

Streaming LLM responses delivers tokens to the user as they're generated, dramatically improving perceived latency from 5-30 seconds (wait for full response) to instant feedback. This skill covers the Anthropic and OpenAI streaming APIs, building streaming HTTP endpoints with SSE, WebSocket-based streaming for bidirectional communication, React UI patterns for real-time rendering, and production concerns like connection timeouts, backpressure, and error handling mid-stream.

## When to Use

- Any LLM response longer than a sentence — streaming is always better for UX
- Chat interfaces where users need to see progress immediately
- Long-form generation (reports, code, essays) where users may want to stop early
- Real-time transcription or voice-to-text pipelines
- Agent workflows where streaming intermediate steps keeps users engaged

## Step-by-Step Workflow

### 1. Anthropic Streaming API
```python
import anthropic
import asyncio
from typing import AsyncIterator

client = anthropic.Anthropic()
async_client = anthropic.AsyncAnthropic()

# Synchronous streaming
def stream_response_sync(prompt: str) -> str:
    """Stream and collect full response."""
    full_text = ""
    
    with client.messages.stream(
        model="claude-sonnet-4-6",
        max_tokens=1024,
        messages=[{"role": "user", "content": prompt}],
    ) as stream:
        for text in stream.text_stream:
            print(text, end="", flush=True)
            full_text += text
    
    print()  # Newline after streaming complete
    return full_text

# Async streaming — preferred for production
async def stream_response_async(prompt: str) -> AsyncIterator[str]:
    """Yield tokens as they arrive."""
    async with async_client.messages.stream(
        model="claude-sonnet-4-6",
        max_tokens=2048,
        system="You are a helpful assistant.",
        messages=[{"role": "user", "content": prompt}],
    ) as stream:
        async for text in stream.text_stream:
            yield text
    
    # Access final message after stream completes
    final_message = await stream.get_final_message()
    print(f"\nTokens used: {final_message.usage.input_tokens} in, {final_message.usage.output_tokens} out")

# Stream with tool use
async def stream_with_tools(prompt: str):
    tools = [
        {
            "name": "search",
            "description": "Search the web",
            "input_schema": {
                "type": "object",
                "properties": {"query": {"type": "string"}},
                "required": ["query"],
            },
        }
    ]
    
    async with async_client.messages.stream(
        model="claude-sonnet-4-6",
        max_tokens=1024,
        tools=tools,
        messages=[{"role": "user", "content": prompt}],
    ) as stream:
        async for event in stream:
            match event.type:
                case "content_block_delta":
                    if event.delta.type == "text_delta":
                        print(event.delta.text, end="", flush=True)
                    elif event.delta.type == "input_json_delta":
                        print(event.delta.partial_json, end="", flush=True)
                case "content_block_start":
                    if event.content_block.type == "tool_use":
                        print(f"\n[Tool call: {event.content_block.name}]")
```

### 2. OpenAI Streaming API
```python
from openai import AsyncOpenAI
from typing import AsyncIterator

client = AsyncOpenAI()

async def stream_openai(messages: list[dict]) -> AsyncIterator[str]:
    stream = await client.chat.completions.create(
        model="gpt-4o",
        messages=messages,
        stream=True,
        stream_options={"include_usage": True},  # Get token counts at end
    )
    
    async for chunk in stream:
        delta = chunk.choices[0].delta if chunk.choices else None
        if delta and delta.content:
            yield delta.content
        
        # Last chunk has usage stats
        if chunk.usage:
            print(f"\nTokens: {chunk.usage.prompt_tokens} in, {chunk.usage.completion_tokens} out")

# Structured streaming with streaming=True
async def stream_json_openai(prompt: str):
    """Stream JSON object construction in real-time."""
    stream = await client.chat.completions.create(
        model="gpt-4o",
        messages=[{"role": "user", "content": prompt}],
        response_format={"type": "json_object"},
        stream=True,
    )
    
    json_buffer = ""
    async for chunk in stream:
        if chunk.choices[0].delta.content:
            json_buffer += chunk.choices[0].delta.content
            print(chunk.choices[0].delta.content, end="", flush=True)
    
    import json
    return json.loads(json_buffer)
```

### 3. FastAPI SSE Endpoint
```python
from fastapi import FastAPI, Request
from fastapi.responses import StreamingResponse
import anthropic
import asyncio
import json

app = FastAPI()
client = anthropic.AsyncAnthropic()

@app.post("/api/chat/stream")
async def chat_stream(request: Request):
    body = await request.json()
    messages = body.get("messages", [])
    
    async def generate():
        try:
            async with client.messages.stream(
                model="claude-sonnet-4-6",
                max_tokens=2048,
                messages=messages,
            ) as stream:
                async for text in stream.text_stream:
                    # SSE format: "data: <content>\n\n"
                    data = json.dumps({"type": "text", "content": text})
                    yield f"data: {data}\n\n"
                
                # Send final stats
                final = await stream.get_final_message()
                stats = json.dumps({
                    "type": "done",
                    "usage": {
                        "input_tokens": final.usage.input_tokens,
                        "output_tokens": final.usage.output_tokens,
                    }
                })
                yield f"data: {stats}\n\n"
        
        except asyncio.CancelledError:
            # Client disconnected — clean up
            print("Client disconnected")
        except anthropic.APIError as e:
            error_data = json.dumps({"type": "error", "message": str(e)})
            yield f"data: {error_data}\n\n"
    
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

### 4. Next.js App Router Streaming
```typescript
// app/api/chat/route.ts
import Anthropic from "@anthropic-ai/sdk";
import { NextRequest } from "next/server";

const anthropic = new Anthropic();

export async function POST(req: NextRequest) {
  const { messages } = await req.json();

  const stream = await anthropic.messages.stream({
    model: "claude-sonnet-4-6",
    max_tokens: 2048,
    messages,
  });

  // Return ReadableStream directly — Next.js handles SSE
  const encoder = new TextEncoder();
  
  const readable = new ReadableStream({
    async start(controller) {
      try {
        for await (const chunk of stream) {
          if (
            chunk.type === "content_block_delta" &&
            chunk.delta.type === "text_delta"
          ) {
            const data = JSON.stringify({ text: chunk.delta.text });
            controller.enqueue(encoder.encode(`data: ${data}\n\n`));
          }
        }
        controller.enqueue(encoder.encode("data: [DONE]\n\n"));
        controller.close();
      } catch (error) {
        controller.error(error);
      }
    },
    cancel() {
      // Client disconnected
      stream.controller.abort();
    },
  });

  return new Response(readable, {
    headers: {
      "Content-Type": "text/event-stream",
      "Cache-Control": "no-cache",
      Connection: "keep-alive",
    },
  });
}
```

### 5. React Streaming UI with useChat (Vercel AI SDK)
```typescript
// components/Chat.tsx
"use client";
import { useChat } from "ai/react";
import { useEffect, useRef } from "react";

export function Chat() {
  const { messages, input, handleInputChange, handleSubmit, isLoading, stop, error } = useChat({
    api: "/api/chat",
    onFinish: (message) => {
      console.log("Complete:", message.content);
    },
    onError: (error) => {
      console.error("Stream error:", error);
    },
  });

  const bottomRef = useRef<HTMLDivElement>(null);
  
  // Auto-scroll as tokens arrive
  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages]);

  return (
    <div className="flex flex-col h-full">
      <div className="flex-1 overflow-y-auto p-4 space-y-4">
        {messages.map((m) => (
          <div key={m.id} className={`flex ${m.role === "user" ? "justify-end" : "justify-start"}`}>
            <div className={`max-w-3xl p-3 rounded-lg ${
              m.role === "user" ? "bg-blue-500 text-white" : "bg-gray-100"
            }`}>
              {/* Render markdown with streaming-aware component */}
              <StreamingText content={m.content} isStreaming={isLoading && m === messages[messages.length - 1]} />
            </div>
          </div>
        ))}
        
        {isLoading && (
          <div className="flex justify-start">
            <div className="bg-gray-100 p-3 rounded-lg animate-pulse">
              <span className="text-gray-400">Thinking...</span>
            </div>
          </div>
        )}
        
        <div ref={bottomRef} />
      </div>
      
      <form onSubmit={handleSubmit} className="p-4 border-t flex gap-2">
        <input
          value={input}
          onChange={handleInputChange}
          placeholder="Ask anything..."
          className="flex-1 border rounded-lg px-4 py-2"
          disabled={isLoading}
        />
        {isLoading ? (
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

// Streaming text component with blinking cursor
function StreamingText({ content, isStreaming }: { content: string; isStreaming: boolean }) {
  return (
    <span>
      {content}
      {isStreaming && <span className="animate-blink">▊</span>}
    </span>
  );
}
```

### 6. Manual SSE Client (TypeScript)
```typescript
// utils/stream-client.ts
async function* fetchStream(url: string, body: object): AsyncGenerator<string> {
  const response = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });

  if (!response.ok) {
    throw new Error(`HTTP ${response.status}`);
  }

  const reader = response.body!.getReader();
  const decoder = new TextDecoder();
  let buffer = "";

  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;

      buffer += decoder.decode(value, { stream: true });
      const lines = buffer.split("\n");
      buffer = lines.pop() ?? "";

      for (const line of lines) {
        if (line.startsWith("data: ")) {
          const data = line.slice(6);
          if (data === "[DONE]") return;
          const parsed = JSON.parse(data);
          if (parsed.text) yield parsed.text;
        }
      }
    }
  } finally {
    reader.cancel();  // Clean up on early exit
  }
}

// Usage with abort controller
async function streamToElement(prompt: string, element: HTMLElement) {
  const controller = new AbortController();
  
  // Allow cancellation
  document.getElementById("stop-btn")?.addEventListener("click", () => controller.abort());
  
  let text = "";
  for await (const chunk of fetchStream("/api/chat", { prompt })) {
    text += chunk;
    element.textContent = text;
  }
}
```

## Key Commands Reference

```bash
# Vercel AI SDK — best for Next.js
npm install ai @ai-sdk/anthropic

# Test SSE endpoint
curl -N -X POST http://localhost:3000/api/chat/stream \
  -H "Content-Type: application/json" \
  -d '{"messages":[{"role":"user","content":"Hello"}]}'

# Watch token arrival timing
curl -N -w "\n%{time_total}s total\n" http://localhost:3000/api/stream

# Python async streaming test
python -c "
import asyncio
import anthropic

async def test():
    client = anthropic.AsyncAnthropic()
    async with client.messages.stream(model='claude-sonnet-4-6', max_tokens=100,
        messages=[{'role':'user','content':'Count to 10'}]) as s:
        async for t in s.text_stream:
            print(t, end='', flush=True)
asyncio.run(test())
"
```

## Common Patterns

### Pattern 1: Streaming with Context Window Awareness
```python
async def stream_with_limit_check(messages: list[dict], max_tokens: int = 2048):
    """Count tokens before streaming to avoid mid-stream token limit errors."""
    # Estimate tokens (rough: 4 chars ≈ 1 token)
    estimated_input = sum(len(m["content"]) // 4 for m in messages)
    if estimated_input > 180_000:  # Leave room for response
        yield "[Error: Context too long]"
        return
    
    async with async_client.messages.stream(
        model="claude-sonnet-4-6",
        max_tokens=max_tokens,
        messages=messages,
    ) as stream:
        async for text in stream.text_stream:
            yield text
```

### Pattern 2: Streaming with Retry and Backoff
```python
import asyncio
from typing import AsyncIterator

async def stream_with_retry(prompt: str, max_retries: int = 3) -> AsyncIterator[str]:
    for attempt in range(max_retries):
        try:
            async with async_client.messages.stream(
                model="claude-sonnet-4-6",
                max_tokens=1024,
                messages=[{"role": "user", "content": prompt}],
            ) as stream:
                async for text in stream.text_stream:
                    yield text
            return  # Success
        except anthropic.RateLimitError:
            if attempt == max_retries - 1:
                raise
            wait = 2 ** attempt
            await asyncio.sleep(wait)
        except anthropic.APIConnectionError:
            if attempt == max_retries - 1:
                raise
            await asyncio.sleep(1)
```

### Pattern 3: Streaming to Multiple Consumers (Fan-out)
```python
import asyncio
from typing import AsyncIterator

async def broadcast_stream(prompt: str, num_consumers: int = 3):
    """Stream once, fan out to multiple consumers."""
    queues = [asyncio.Queue() for _ in range(num_consumers)]
    
    async def produce():
        async with async_client.messages.stream(
            model="claude-sonnet-4-6",
            max_tokens=1024,
            messages=[{"role": "user", "content": prompt}],
        ) as stream:
            async for text in stream.text_stream:
                for q in queues:
                    await q.put(text)
        for q in queues:
            await q.put(None)  # Sentinel
    
    async def consume(queue: asyncio.Queue, consumer_id: int):
        while True:
            text = await queue.get()
            if text is None:
                break
            print(f"Consumer {consumer_id}: {text}", end="", flush=True)
    
    await asyncio.gather(
        produce(),
        *[consume(q, i) for i, q in enumerate(queues)],
    )
```

## Pitfalls to Avoid

1. **Buffering at the proxy/nginx layer**: Nginx buffers responses by default, defeating streaming. Add `X-Accel-Buffering: no` to your response headers and set `proxy_buffering off` in nginx config. AWS ALB adds ~40ms buffering — use ALB with HTTP/2 or switch to WebSockets for sub-second token delivery. Vercel, Fly.io, and Railway handle this correctly out of the box.

2. **Not handling client disconnection**: If the user closes the browser, your backend continues calling the LLM API and burning tokens. Detect disconnection: in FastAPI, catch `asyncio.CancelledError`; in Express, listen for `req.on('close', ...)`. Pass an `AbortController` signal to cancel the API call immediately when the client disconnects.

3. **Accumulating the full stream before yielding**: Code like `text = ""; for chunk in stream: text += chunk; yield text` yields the entire accumulated response on every chunk — exponential data transfer. Yield only the new token on each iteration: `yield chunk`. If you need the accumulated text for rendering, accumulate on the client side.

## Related Skills

- `websocket-realtime` — WebSocket alternative when bidirectional streaming is needed
- `prompt-chaining` — Chain streaming responses into multi-step pipelines
- `edge-computing-patterns` — Stream at the edge for global low-latency delivery
- `claude-api-integration` — Full Claude API integration patterns

## GitNexus Index

```json
{
  "skill": "streaming-llm-responses",
  "category": "ai-ml",
  "triggers": ["streaming llm", "sse streaming", "server sent events ai", "streaming chat", "real-time tokens", "anthropic streaming", "openai stream", "useChat"],
  "outputs": ["streaming endpoint", "SSE route", "ReadableStream", "useChat hook", "async generator"],
  "complexity": "medium",
  "tools": ["anthropic", "openai", "fastapi", "nextjs", "vercel-ai-sdk", "python", "typescript"]
}
```
