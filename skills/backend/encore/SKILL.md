---
name: encore
description: Build and deploy cloud-native backends with Encore — a development platform that auto-provisions infrastructure, generates API clients, and provides built-in observability. Use this skill whenever the user mentions Encore, wants a backend with zero-config cloud deployment, auto-generated API docs, or a Go/TypeScript backend that handles infrastructure automatically. Trigger for "encore.ts", "encore.dev", or "backend platform with auto-infra".
---

# Encore Backend Development Platform

Encore is a backend framework and cloud platform that lets you define infrastructure (services, databases, queues, caches) in code and automatically provisions it. It supports both Go and TypeScript/JavaScript.

## Installation

```bash
# macOS
brew install encoredev/tap/encore

# Linux
curl -L https://encore.dev/install.sh | bash

# Create new app
encore app create my-app --example=hello-world
cd my-app
encore run  # starts local dev environment
```

## TypeScript Backend

### Define a Service

```typescript
// user/user.ts
import { api, APIError } from 'encore.dev/api'
import { SQLDatabase } from 'encore.dev/storage/sqldb'

// Encore auto-provisions this Postgres database
const db = new SQLDatabase('userdb', {
  migrations: './migrations',
})

interface User {
  id: number
  name: string
  email: string
}

// Typed API endpoint — Encore auto-generates client and docs
export const getUser = api(
  { expose: true, method: 'GET', path: '/users/:id' },
  async ({ id }: { id: number }): Promise<User> => {
    const row = await db.queryRow<User>`
      SELECT id, name, email FROM users WHERE id = ${id}
    `
    if (!row) throw APIError.notFound('user not found')
    return row
  }
)

export const createUser = api(
  { expose: true, method: 'POST', path: '/users', auth: true },
  async ({ name, email }: { name: string; email: string }): Promise<User> => {
    const row = await db.queryRow<User>`
      INSERT INTO users (name, email)
      VALUES (${name}, ${email})
      RETURNING id, name, email
    `
    return row!
  }
)
```

### Auth Handler

```typescript
// auth/auth.ts
import { authHandler } from 'encore.dev/auth'
import { Header, APIError } from 'encore.dev/api'
import { jwtVerify } from 'jose'

interface AuthData {
  userID: string
  email: string
}

export const myAuthHandler = authHandler<Header<'Authorization'>, AuthData>(
  async (params) => {
    const token = params.authorization?.replace('Bearer ', '')
    if (!token) throw APIError.unauthenticated('missing token')
    
    try {
      const { payload } = await jwtVerify(
        token,
        new TextEncoder().encode(process.env.JWT_SECRET)
      )
      return { userID: payload.sub!, email: payload.email as string }
    } catch {
      throw APIError.unauthenticated('invalid token')
    }
  }
)
```

### Pub/Sub Messaging

```typescript
// orders/orders.ts
import { Topic, Subscription } from 'encore.dev/pubsub'

interface OrderEvent {
  orderId: string
  userId: string
  total: number
}

// Encore auto-provisions the message queue
export const OrderTopic = new Topic<OrderEvent>('order-placed', {
  deliveryGuarantee: 'at-least-once',
})

// Publisher
export const placeOrder = api(
  { expose: true, method: 'POST', path: '/orders' },
  async (order: Omit<OrderEvent, 'orderId'>): Promise<{ orderId: string }> => {
    const orderId = crypto.randomUUID()
    await OrderTopic.publish({ orderId, ...order })
    return { orderId }
  }
)

// Subscriber in a different service
const _ = new Subscription(OrderTopic, 'send-confirmation-email', {
  handler: async (event) => {
    console.log(`Processing order ${event.orderId} for user ${event.userId}`)
    // Send email, update inventory, etc.
  },
})
```

### Scheduled Tasks (Cron)

```typescript
// cleanup/cleanup.ts
import { CronJob } from 'encore.dev/cron'
import { api } from 'encore.dev/api'

// This endpoint runs every day at midnight
const dailyCleanup = new CronJob('daily-cleanup', {
  title: 'Clean up old sessions',
  every: '24h',
  endpoint: cleanSessions,
})

export const cleanSessions = api(
  { expose: false },
  async (): Promise<{ deleted: number }> => {
    // cleanup logic
    return { deleted: 0 }
  }
)
```

### Cache

```typescript
// products/cache.ts
import { CacheCluster, RedisCacheCluster } from 'encore.dev/storage/cache'

// Encore provisions Redis automatically
const cluster = new CacheCluster('products-cache', {
  eviction: 'allkeys-lru',
})

const ProductCache = cluster.newKeyspace<Product>('product', {
  defaultTTL: '1h',
})

export const getProduct = api(
  { expose: true, method: 'GET', path: '/products/:id' },
  async ({ id }: { id: string }): Promise<Product> => {
    // Check cache first
    const cached = await ProductCache.get(id)
    if (cached) return cached

    const product = await db.queryRow<Product>`SELECT * FROM products WHERE id = ${id}`
    if (!product) throw APIError.notFound('product not found')
    
    await ProductCache.set(id, product)
    return product
  }
)
```

## Go Backend

```go
// user/user.go
package user

import (
    "context"
    "encore.dev/storage/sqldb"
    "encore.dev/beta/errs"
)

// encore:service
type Service struct {
    db *sqldb.Database
}

type User struct {
    ID    int    `json:"id"`
    Name  string `json:"name"`
    Email string `json:"email"`
}

// encore:api public method=GET path=/users/:id
func (s *Service) GetUser(ctx context.Context, id int) (*User, error) {
    var u User
    err := s.db.QueryRow(ctx,
        "SELECT id, name, email FROM users WHERE id = $1", id,
    ).Scan(&u.ID, &u.Name, &u.Email)
    if err != nil {
        return nil, errs.NotFound("user not found", err)
    }
    return &u, nil
}
```

## Local Development

```bash
encore run          # start local dev with auto-provisioned infra
encore db shell     # connect to local database
encore logs --env=staging   # stream logs from staging
encore test ./...   # run tests with provisioned test DBs
```

## Deployment

```bash
encore app create   # link to Encore Cloud
git push encore     # auto-deploys to Encore Cloud
# or deploy to your own AWS/GCP/Azure
encore eject aws    # generates Terraform + Docker for self-hosting
```

## Key Features

- **Zero-config infra**: databases, queues, caches declared in code, auto-provisioned
- **Generated clients**: type-safe clients in TypeScript, Go, etc.
- **Built-in tracing**: distributed traces, logs, metrics out of the box
- **Local dev environment**: full infra locally without Docker Compose setup
- **API documentation**: auto-generated from type annotations
- **Service discovery**: services call each other by import, Encore handles networking

## GitNexus Index

This skill is indexed by GitNexus for knowledge graph traversal.
Index path: /Users/localuser/.claude/skills/encore/.gitnexus
Last indexed: 2026-05-24
