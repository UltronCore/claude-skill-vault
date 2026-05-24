---
name: hono
description: Build ultra-fast web APIs and full-stack apps with Hono — a lightweight, multi-runtime web framework that runs on Bun, Cloudflare Workers, Deno, Node.js, and AWS Lambda. Use this skill whenever the user mentions Hono, building a fast REST API, Edge API, Cloudflare Worker API, or wants a minimal TypeScript web framework. Trigger even if they just say "fast API with Bun" or "edge-compatible web server" without naming Hono explicitly.
---

# Hono Web Framework

Hono is a small (~14kB), fast, and multi-runtime web framework built on Web Standards. It runs on Bun, Cloudflare Workers, Deno, Node.js, Fastly, Vercel, Netlify, and AWS Lambda with identical code.

## Installation

```bash
# Bun
bun create hono my-app
cd my-app && bun install

# Node.js
npm create hono@latest my-app

# Cloudflare Workers
npm create hono@latest my-worker -- --template cloudflare-workers
```

## Core Concepts

### Basic App

```typescript
import { Hono } from 'hono'

const app = new Hono()

app.get('/', (c) => c.text('Hello Hono!'))
app.get('/json', (c) => c.json({ message: 'hello', ts: Date.now() }))

// Path params
app.get('/users/:id', (c) => {
  const id = c.req.param('id')
  return c.json({ id })
})

// Query params
app.get('/search', (c) => {
  const q = c.req.query('q')
  return c.json({ results: [], query: q })
})

export default app
```

### Middleware

```typescript
import { Hono } from 'hono'
import { logger } from 'hono/logger'
import { cors } from 'hono/cors'
import { bearerAuth } from 'hono/bearer-auth'
import { zValidator } from '@hono/zod-validator'
import { z } from 'zod'

const app = new Hono()

// Built-in middleware
app.use('*', logger())
app.use('/api/*', cors({ origin: 'https://myapp.com' }))
app.use('/admin/*', bearerAuth({ token: process.env.ADMIN_TOKEN! }))

// Input validation with Zod
const createUserSchema = z.object({
  name: z.string().min(1),
  email: z.string().email(),
})

app.post('/users', zValidator('json', createUserSchema), async (c) => {
  const data = c.req.valid('json') // fully typed
  return c.json({ created: true, ...data }, 201)
})
```

### Route Groups & Chaining

```typescript
import { Hono } from 'hono'

const app = new Hono()

// Route groups
const api = new Hono().basePath('/api')

const users = new Hono()
users.get('/', (c) => c.json({ users: [] }))
users.post('/', (c) => c.json({ created: true }))
users.get('/:id', (c) => c.json({ id: c.req.param('id') }))

api.route('/users', users)
app.route('/', api)

export default app
```

### Context & Env

```typescript
// Type-safe env bindings (Cloudflare Workers or .env)
type Env = {
  Bindings: {
    DATABASE_URL: string
    JWT_SECRET: string
  }
  Variables: {
    userId: string
  }
}

const app = new Hono<Env>()

// Auth middleware that sets context variable
app.use('/protected/*', async (c, next) => {
  const token = c.req.header('Authorization')?.replace('Bearer ', '')
  if (!token) return c.json({ error: 'Unauthorized' }, 401)
  c.set('userId', 'user_123') // set typed variable
  await next()
})

app.get('/protected/profile', (c) => {
  const userId = c.get('userId') // typed retrieval
  return c.json({ userId })
})
```

### RPC Mode (type-safe client)

```typescript
// server.ts
import { Hono } from 'hono'

const app = new Hono()
  .get('/api/posts', (c) => c.json({ posts: [{ id: 1, title: 'Hello' }] }))
  .post('/api/posts', async (c) => {
    const body = await c.req.json()
    return c.json({ created: true, ...body }, 201)
  })

export type AppType = typeof app
export default app

// client.ts (share types — no codegen needed)
import { hc } from 'hono/client'
import type { AppType } from './server'

const client = hc<AppType>('http://localhost:3000')
const res = await client.api.posts.$get()
const data = await res.json() // fully typed!
```

### Streaming Responses

```typescript
import { streamText, stream } from 'hono/streaming'

app.get('/stream', (c) => {
  return streamText(c, async (stream) => {
    for (const chunk of ['Hello', ' ', 'World']) {
      await stream.write(chunk)
      await stream.sleep(100)
    }
  })
})
```

## Runtime-Specific Setup

### Bun

```typescript
// index.ts
import { Hono } from 'hono'

const app = new Hono()
app.get('/', (c) => c.text('Running on Bun!'))

export default {
  port: 3000,
  fetch: app.fetch,
}
```

### Cloudflare Workers

```typescript
// src/index.ts
import { Hono } from 'hono'

const app = new Hono<{ Bindings: Env }>()
app.get('/', (c) => c.text('Running on Workers!'))

export default app
```

### Node.js

```typescript
import { serve } from '@hono/node-server'
import { Hono } from 'hono'

const app = new Hono()
app.get('/', (c) => c.text('Running on Node!'))

serve({ fetch: app.fetch, port: 3000 })
```

## Testing

```typescript
import { describe, it, expect } from 'bun:test'
import app from './index'

describe('API', () => {
  it('GET / returns 200', async () => {
    const res = await app.request('/')
    expect(res.status).toBe(200)
    expect(await res.text()).toBe('Hello Hono!')
  })

  it('POST /users validates body', async () => {
    const res = await app.request('/users', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ name: 'Alice', email: 'alice@example.com' }),
    })
    expect(res.status).toBe(201)
  })
})
```

## Key Built-in Middleware

| Middleware | Import | Purpose |
|---|---|---|
| `logger` | `hono/logger` | Request logging |
| `cors` | `hono/cors` | CORS headers |
| `bearerAuth` | `hono/bearer-auth` | Bearer token auth |
| `basicAuth` | `hono/basic-auth` | HTTP Basic auth |
| `jwt` | `hono/jwt` | JWT verification |
| `cache` | `hono/cache` | Response caching |
| `compress` | `hono/compress` | Gzip/Brotli compression |
| `etag` | `hono/etag` | ETag support |
| `secureHeaders` | `hono/secure-headers` | Security headers |
| `rateLimiter` | `@hono/rate-limiter` | Rate limiting |

## Common Patterns

- **Error handling**: use `app.onError((err, c) => c.json({ error: err.message }, 500))`
- **404 handler**: use `app.notFound((c) => c.json({ error: 'Not found' }, 404))`
- **File uploads**: use `c.req.parseBody()` for multipart
- **Cookie**: use `getCookie`/`setCookie` from `hono/cookie`
- **HTML rendering**: use JSX with `hono/jsx` for server-side HTML

## GitNexus Index

This skill is indexed by GitNexus for knowledge graph traversal.
Index path: /Users/localuser/.claude/skills/hono/.gitnexus
Last indexed: 2026-05-24
