---
name: elysia
description: Build type-safe, high-performance web APIs with Elysia — a Bun-native TypeScript web framework with end-to-end type safety, automatic OpenAPI docs, and best-in-class performance. Use this skill whenever the user mentions Elysia, building a Bun API with end-to-end type safety, or wants a framework with built-in Eden client, schema validation, or lifecycle hooks. Trigger for "fast bun backend", "type-safe bun api", or any Elysia question.
---

# Elysia Web Framework

Elysia is a Bun-first TypeScript web framework with ergonomic API design, end-to-end type inference, and built-in OpenAPI documentation. It achieves extreme performance through Bun's native HTTP server and static analysis at startup.

## Installation

```bash
bun create elysia my-app
cd my-app && bun install
bun dev
```

## Core Concepts

### Basic App

```typescript
import { Elysia } from 'elysia'

const app = new Elysia()
  .get('/', () => 'Hello Elysia!')
  .get('/json', () => ({ message: 'hello', ts: Date.now() }))
  .listen(3000)

console.log(`Running at http://localhost:3000`)
```

### Schema Validation with t (TypeBox)

```typescript
import { Elysia, t } from 'elysia'

const app = new Elysia()
  .post('/users', 
    ({ body }) => ({ created: true, ...body }),
    {
      body: t.Object({
        name: t.String({ minLength: 1 }),
        email: t.String({ format: 'email' }),
        age: t.Optional(t.Number({ minimum: 0 })),
      }),
      response: t.Object({
        created: t.Boolean(),
        name: t.String(),
        email: t.String(),
      }),
    }
  )
  .listen(3000)
```

### Guards & Middleware

```typescript
import { Elysia, t } from 'elysia'

const app = new Elysia()
  // Global lifecycle hooks
  .onRequest(({ request }) => {
    console.log(`${request.method} ${new URL(request.url).pathname}`)
  })
  .onError(({ error, code }) => {
    if (code === 'VALIDATION') return new Response('Invalid input', { status: 422 })
    console.error(error)
  })
  // Route-level guard with schema
  .guard(
    {
      headers: t.Object({
        authorization: t.String({ pattern: '^Bearer .+' }),
      }),
    },
    (app) =>
      app
        .get('/me', ({ headers }) => {
          const token = headers.authorization.replace('Bearer ', '')
          return { token }
        })
  )
  .listen(3000)
```

### Plugins (modular architecture)

```typescript
import { Elysia, t } from 'elysia'

// Create a reusable plugin
const userPlugin = new Elysia({ prefix: '/users' })
  .get('/', () => [{ id: 1, name: 'Alice' }])
  .get('/:id', ({ params: { id } }) => ({ id }))
  .post('/', ({ body }) => ({ created: true, ...body }), {
    body: t.Object({ name: t.String(), email: t.String() }),
  })

const authPlugin = new Elysia({ name: 'auth' })
  .derive(({ headers }) => ({
    get userId() {
      // Parse JWT here
      const token = headers.authorization?.replace('Bearer ', '')
      return token ? 'user_123' : null
    },
  }))
  .macro(({ onBeforeHandle }) => ({
    isSignIn(value: boolean) {
      if (!value) return
      onBeforeHandle(({ userId, error }) => {
        if (!userId) return error(401, 'Unauthorized')
      })
    },
  }))

const app = new Elysia()
  .use(userPlugin)
  .use(authPlugin)
  .get('/protected', ({ userId }) => ({ userId }), { isSignIn: true })
  .listen(3000)
```

### Eden Treaty (end-to-end type-safe client)

```typescript
// server.ts — export the app type
import { Elysia, t } from 'elysia'

const app = new Elysia()
  .get('/posts', () => [{ id: 1, title: 'Hello' }])
  .post('/posts', ({ body }) => ({ created: true, ...body }), {
    body: t.Object({ title: t.String(), content: t.String() }),
  })
  .listen(3000)

export type App = typeof app

// client.ts — fully typed, no codegen
import { treaty } from '@elysiajs/eden'
import type { App } from './server'

const client = treaty<App>('localhost:3000')

// Fully typed — autocomplete, error checking, response types
const { data, error } = await client.posts.get()
const { data: created } = await client.posts.post({
  title: 'New post',
  content: 'Content here',
})
```

### OpenAPI / Swagger (auto-generated)

```typescript
import { Elysia, t } from 'elysia'
import { swagger } from '@elysiajs/swagger'

const app = new Elysia()
  .use(swagger({
    documentation: {
      info: { title: 'My API', version: '1.0.0' },
    },
  }))
  .get('/users', () => [], {
    detail: {
      summary: 'List users',
      tags: ['users'],
    },
    response: t.Array(t.Object({ id: t.Number(), name: t.String() })),
  })
  .listen(3000)
// Visit http://localhost:3000/swagger for docs
```

### WebSockets

```typescript
import { Elysia, t } from 'elysia'

const app = new Elysia()
  .ws('/chat', {
    message(ws, message) {
      ws.send(`Echo: ${message}`)
      ws.publish('room', message) // broadcast
    },
    open(ws) {
      ws.subscribe('room')
      console.log('Client connected:', ws.id)
    },
    close(ws) {
      console.log('Client disconnected:', ws.id)
    },
    body: t.String(),
  })
  .listen(3000)
```

### Lifecycle Hooks

```typescript
import { Elysia } from 'elysia'

const app = new Elysia()
  .onRequest(({ request }) => { /* before routing */ })
  .onBeforeHandle(({ params }) => { /* before handler, can return early */ })
  .onAfterHandle(({ response }) => { /* transform response */ })
  .onError(({ error, code }) => { /* handle errors */ })
  .onResponse(({ response }) => { /* after response sent */ })
```

## Official Plugins

| Plugin | Package | Purpose |
|---|---|---|
| Swagger | `@elysiajs/swagger` | Auto OpenAPI docs |
| Eden | `@elysiajs/eden` | Type-safe client |
| JWT | `@elysiajs/jwt` | JWT auth |
| Cookie | `@elysiajs/cookie` | Cookie management |
| CORS | `@elysiajs/cors` | CORS middleware |
| Static | `@elysiajs/static` | Serve static files |
| Bearer | `@elysiajs/bearer` | Bearer token extraction |
| HTML | `@elysiajs/html` | JSX HTML rendering |
| Rate Limit | `@elysiajs/rate-limit` | Rate limiting |

## Testing

```typescript
import { describe, expect, it } from 'bun:test'
import { Elysia } from 'elysia'
import app from './index'

describe('Users API', () => {
  it('GET /users returns array', async () => {
    const response = await app.handle(
      new Request('http://localhost/users')
    )
    expect(response.status).toBe(200)
    const body = await response.json()
    expect(Array.isArray(body)).toBe(true)
  })
})
```

## Performance Tips

- Define schemas at startup — Elysia compiles validators once
- Use `derive` not closures for reusable context properties
- Prefer `plugin` pattern for code splitting — Elysia deduplicates plugins by name
- Use `macro` for reusable route decorators instead of repetitive `guard` calls

## GitNexus Index

This skill is indexed by GitNexus for knowledge graph traversal.
Index path: /Users/localuser/.claude/skills/elysia/.gitnexus
Last indexed: 2026-05-24
