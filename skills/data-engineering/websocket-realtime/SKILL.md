---
name: websocket-realtime
description: >
  Real-time features with WebSockets, Server-Sent Events, and Supabase Realtime. Triggers on: WebSocket, socket.io, SSE, ReadableStream, Supabase Realtime, .on('INSERT'), channel.subscribe, EventSource.
---

# WebSocket & Realtime

## When to Use
Use when building chat, live dashboards, collaborative editing, notifications, or any feature where the server pushes data to the client without polling.

---

## Core Rules
- SSE for server-to-client only (simpler, HTTP/2 friendly, auto-reconnect)
- WebSocket for bidirectional communication (chat, multiplayer, collaboration)
- Supabase Realtime for database change events — it's built-in and handles auth
- Always handle reconnection — assume connections drop
- Clean up subscriptions in useEffect return / component unmount

---

## Choose the Right Transport

| Feature | SSE | WebSocket | Supabase Realtime |
|---|---|---|---|
| Direction | Server → Client | Bidirectional | Server → Client |
| Protocol | HTTP | WS | WebSocket (managed) |
| Auto-reconnect | Yes (browser) | Manual | Yes (SDK) |
| Works through proxies | Yes | Sometimes | Yes |
| Best for | Feeds, notifications | Chat, collab | DB change events |
| Next.js Route Handler | Yes | Requires adapter | N/A |

---

## SSE from Next.js Route Handler

```typescript
// app/api/events/route.ts
import { NextRequest } from 'next/server';

export const runtime = 'nodejs'; // required — edge doesn't support long-lived streams

export async function GET(req: NextRequest) {
  const encoder = new TextEncoder();

  const stream = new ReadableStream({
    async start(controller) {
      // Send initial event
      const send = (data: unknown, event?: string) => {
        const lines = [
          event ? `event: ${event}` : '',
          `data: ${JSON.stringify(data)}`,
          '',
          '',
        ].filter(Boolean).join('\n');
        controller.enqueue(encoder.encode(lines));
      };

      send({ connected: true }, 'connected');

      // Example: poll DB every 2s and push changes
      const interval = setInterval(async () => {
        const data = await fetchLatestData();
        send(data, 'update');
      }, 2000);

      // Cleanup when client disconnects
      req.signal.addEventListener('abort', () => {
        clearInterval(interval);
        controller.close();
      });
    },
  });

  return new Response(stream, {
    headers: {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache, no-transform',
      Connection: 'keep-alive',
    },
  });
}
```

### SSE Client (React Hook)
```typescript
// hooks/useSSE.ts
import { useEffect, useState, useRef } from 'react';

export function useSSE<T>(url: string) {
  const [data, setData] = useState<T | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [connected, setConnected] = useState(false);
  const esRef = useRef<EventSource | null>(null);

  useEffect(() => {
    const connect = () => {
      const es = new EventSource(url);
      esRef.current = es;

      es.addEventListener('connected', () => setConnected(true));

      es.addEventListener('update', (e) => {
        setData(JSON.parse(e.data));
      });

      es.onerror = () => {
        setError('Connection lost');
        setConnected(false);
        es.close();
        // EventSource auto-reconnects — or manual:
        setTimeout(connect, 3000);
      };
    };

    connect();
    return () => esRef.current?.close();
  }, [url]);

  return { data, error, connected };
}

// Usage
const { data: feed } = useSSE<FeedItem[]>('/api/events');
```

---

## Supabase Realtime

### Postgres Changes (INSERT / UPDATE / DELETE)
```typescript
// lib/realtime.ts
import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
);

// Listen to INSERT on a table
const channel = supabase
  .channel('public:messages')
  .on(
    'postgres_changes',
    {
      event: 'INSERT',          // 'INSERT' | 'UPDATE' | 'DELETE' | '*'
      schema: 'public',
      table: 'messages',
      filter: 'channel_id=eq.123',  // optional row filter
    },
    (payload) => {
      console.log('New message:', payload.new);
    }
  )
  .subscribe((status) => {
    console.log('Realtime status:', status); // SUBSCRIBED | CHANNEL_ERROR | TIMED_OUT | CLOSED
  });

// Cleanup
channel.unsubscribe();
```

### Broadcast (Client-to-Client, no DB)
```typescript
// Useful for presence, typing indicators, ephemeral events
const channel = supabase.channel('room:123');

// Send
channel.send({
  type: 'broadcast',
  event: 'typing',
  payload: { userId: 'abc', typing: true },
});

// Receive
channel
  .on('broadcast', { event: 'typing' }, ({ payload }) => {
    console.log('Typing:', payload);
  })
  .subscribe();
```

### Presence (who's online)
```typescript
const channel = supabase.channel('room:123', {
  config: { presence: { key: userId } },
});

channel
  .on('presence', { event: 'sync' }, () => {
    const state = channel.presenceState();
    console.log('Online users:', Object.keys(state));
  })
  .on('presence', { event: 'join' }, ({ newPresences }) => {
    console.log('Joined:', newPresences);
  })
  .on('presence', { event: 'leave' }, ({ leftPresences }) => {
    console.log('Left:', leftPresences);
  })
  .subscribe(async (status) => {
    if (status === 'SUBSCRIBED') {
      await channel.track({ userId, name: 'Example User', online_at: new Date().toISOString() });
    }
  });
```

### React Hook for Supabase Realtime
```typescript
// hooks/useRealtimeTable.ts
import { useEffect, useState } from 'react';
import { supabase } from '@/lib/supabase';
import type { RealtimePostgresInsertPayload } from '@supabase/supabase-js';

export function useRealtimeInserts<T extends { id: string }>(
  table: string,
  filter?: string
) {
  const [items, setItems] = useState<T[]>([]);

  useEffect(() => {
    const channel = supabase
      .channel(`realtime:${table}`)
      .on<T>(
        'postgres_changes',
        { event: 'INSERT', schema: 'public', table, ...(filter ? { filter } : {}) },
        (payload: RealtimePostgresInsertPayload<T>) => {
          setItems((prev) => [payload.new, ...prev]);
        }
      )
      .subscribe();

    return () => { supabase.removeChannel(channel); };
  }, [table, filter]);

  return items;
}

// Usage
const messages = useRealtimeInserts<Message>('messages', 'channel_id=eq.123');
```

---

## Socket.io (Bidirectional)

### Server (Next.js with custom server)
```typescript
// server.ts
import { createServer } from 'http';
import { Server } from 'socket.io';
import next from 'next';

const app = next({ dev: process.env.NODE_ENV !== 'production' });
const handle = app.getRequestHandler();

app.prepare().then(() => {
  const httpServer = createServer(handle);
  const io = new Server(httpServer, {
    cors: { origin: process.env.NEXT_PUBLIC_SITE_URL },
  });

  io.on('connection', (socket) => {
    console.log('Client connected:', socket.id);

    // Join a room
    socket.on('join:room', (roomId: string) => {
      socket.join(roomId);
    });

    // Handle message
    socket.on('message:send', async ({ roomId, text, userId }) => {
      const message = await db.messages.create({ text, userId, roomId });
      // Broadcast to room (including sender)
      io.to(roomId).emit('message:new', message);
    });

    socket.on('disconnect', () => {
      console.log('Client disconnected:', socket.id);
    });
  });

  httpServer.listen(3000);
});
```

### Client Hook
```typescript
// hooks/useSocket.ts
import { useEffect, useRef, useCallback } from 'react';
import { io, Socket } from 'socket.io-client';

export function useSocket(url: string) {
  const socketRef = useRef<Socket | null>(null);

  useEffect(() => {
    const socket = io(url, {
      reconnectionAttempts: 5,
      reconnectionDelay: 1000,
    });

    socket.on('connect', () => console.log('Connected'));
    socket.on('connect_error', (err) => console.error('Socket error:', err));

    socketRef.current = socket;
    return () => { socket.disconnect(); };
  }, [url]);

  const emit = useCallback((event: string, data: unknown) => {
    socketRef.current?.emit(event, data);
  }, []);

  const on = useCallback((event: string, handler: (...args: unknown[]) => void) => {
    socketRef.current?.on(event, handler);
    return () => socketRef.current?.off(event, handler);
  }, []);

  return { emit, on };
}
```

---

## Connection Management & Reconnection

```typescript
// Generic reconnecting WebSocket hook
import { useEffect, useRef, useState, useCallback } from 'react';

type Status = 'connecting' | 'open' | 'closing' | 'closed';

export function useWebSocket(url: string) {
  const wsRef = useRef<WebSocket | null>(null);
  const [status, setStatus] = useState<Status>('closed');
  const [lastMessage, setLastMessage] = useState<unknown>(null);
  const reconnectRef = useRef<ReturnType<typeof setTimeout>>();
  const attempts = useRef(0);

  const connect = useCallback(() => {
    if (wsRef.current?.readyState === WebSocket.OPEN) return;

    setStatus('connecting');
    const ws = new WebSocket(url);
    wsRef.current = ws;

    ws.onopen = () => {
      setStatus('open');
      attempts.current = 0;
    };

    ws.onmessage = (e) => setLastMessage(JSON.parse(e.data));

    ws.onclose = () => {
      setStatus('closed');
      // Exponential backoff: 1s, 2s, 4s, 8s, max 30s
      const delay = Math.min(1000 * 2 ** attempts.current, 30000);
      attempts.current++;
      reconnectRef.current = setTimeout(connect, delay);
    };

    ws.onerror = () => ws.close();
  }, [url]);

  useEffect(() => {
    connect();
    return () => {
      clearTimeout(reconnectRef.current);
      wsRef.current?.close();
    };
  }, [connect]);

  const send = useCallback((data: unknown) => {
    if (wsRef.current?.readyState === WebSocket.OPEN) {
      wsRef.current.send(JSON.stringify(data));
    }
  }, []);

  return { status, lastMessage, send };
}
```

---

## Quick Reference

| Scenario | Best Choice |
|---|---|
| DB row inserted → update UI | Supabase Realtime postgres_changes |
| Typing indicators / presence | Supabase Realtime presence |
| Live activity feed | SSE from Next.js Route Handler |
| Chat with rooms | Socket.io |
| Collaborative editing | Socket.io or Liveblocks |
| Who's online in a room | Supabase presence or Socket.io rooms |
| One-way push to client | SSE (simpler than WebSocket) |

## GitNexus Index
This skill is indexed by GitNexus for knowledge graph traversal.
Index path: /Users/localuser/claude-skill-vault/skills/data-engineering/websocket-realtime/.gitnexus
Last indexed: 2026-05-23
