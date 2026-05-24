---
name: cloudflare-expert
description: >
  Cloudflare stack: Workers, Pages, D1 database, R2 storage, KV, and Durable Objects. Triggers on: Cloudflare Workers, wrangler, D1, R2 bucket, KV namespace, Durable Objects, cloudflare pages, wrangler.toml.
---

# Cloudflare Expert

## When to Use

Trigger when building or deploying on Cloudflare's developer platform: Workers serverless functions, Pages static hosting, D1 SQL database, R2 object storage, KV key-value cache, or Durable Objects for stateful coordination. Also covers migrating from Vercel.

---

## Core Rules

- Workers run on V8 isolates — no Node.js APIs; use Web APIs (`fetch`, `crypto`, `URL`)
- D1 uses SQLite syntax — not Postgres/MySQL
- R2 is S3-compatible but zero egress fees
- KV is eventually consistent (eventual ~60s propagation); D1 is strongly consistent
- `wrangler.toml` is the single config file for all bindings
- Workers have 10ms CPU time on free plan; 50ms on paid; use streaming for long operations
- Never use `process.env` in Workers — use `env.VARIABLE_NAME` from the context

---

## Setup

```bash
npm install wrangler -g
# or project-local:
npm install wrangler --save-dev

# Login
wrangler login

# Create new project
npm create cloudflare@latest my-project
```

---

## wrangler.toml Reference

```toml
name = "my-worker"
main = "src/index.ts"
compatibility_date = "2024-09-23"
node_compat = true   # enables Node.js compat shims

# Environment variables (non-secret)
[vars]
ENVIRONMENT = "production"
API_URL = "https://api.example.com"

# KV Namespace
[[kv_namespaces]]
binding = "CACHE"
id = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
preview_id = "yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy"

# D1 Database
[[d1_databases]]
binding = "DB"
database_name = "my-database"
database_id = "zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz"

# R2 Bucket
[[r2_buckets]]
binding = "STORAGE"
bucket_name = "my-bucket"

# Durable Objects
[[durable_objects.bindings]]
name = "COUNTER"
class_name = "Counter"

[[migrations]]
tag = "v1"
new_classes = ["Counter"]

# Routes (for non-Pages Workers)
[[routes]]
pattern = "api.yourdomain.com/*"
zone_name = "yourdomain.com"

# Per-environment overrides
[env.staging]
name = "my-worker-staging"
[env.staging.vars]
ENVIRONMENT = "staging"
```

---

## Workers Basics

### Basic Worker

```typescript
// src/index.ts
export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const url = new URL(request.url);

    if (url.pathname === "/api/hello") {
      return Response.json({ message: "Hello from Cloudflare Workers!" });
    }

    if (url.pathname === "/api/echo") {
      const body = await request.json();
      return Response.json(body);
    }

    return new Response("Not Found", { status: 404 });
  },
};

// Type the env bindings
interface Env {
  DB: D1Database;
  CACHE: KVNamespace;
  STORAGE: R2Bucket;
  ENVIRONMENT: string;
  API_SECRET: string;  // set via: wrangler secret put API_SECRET
}
```

### Routing (Hono — recommended)

```bash
npm install hono
```

```typescript
// src/index.ts
import { Hono } from "hono";
import { cors } from "hono/cors";
import { logger } from "hono/logger";

type Bindings = {
  DB: D1Database;
  CACHE: KVNamespace;
  API_SECRET: string;
};

const app = new Hono<{ Bindings: Bindings }>();

app.use("*", logger());
app.use("/api/*", cors({ origin: "https://yourdomain.com" }));

app.get("/", (c) => c.text("Hello World"));

app.get("/api/products", async (c) => {
  const products = await c.env.DB.prepare("SELECT * FROM products WHERE active = 1")
    .all();
  return c.json(products.results);
});

app.post("/api/products", async (c) => {
  const body = await c.req.json();
  const result = await c.env.DB.prepare(
    "INSERT INTO products (name, price) VALUES (?, ?) RETURNING *"
  ).bind(body.name, body.price).first();
  return c.json(result, 201);
});

export default app;
```

---

## D1 Database

### Create and migrate

```bash
# Create database
wrangler d1 create my-database

# Apply migration
wrangler d1 execute my-database --file ./migrations/0001_init.sql

# Execute SQL directly
wrangler d1 execute my-database --command "SELECT * FROM products LIMIT 5"

# Local dev (auto-creates local SQLite)
wrangler dev --local
```

### Migration files

```sql
-- migrations/0001_init.sql
CREATE TABLE IF NOT EXISTS products (
  id TEXT PRIMARY KEY DEFAULT (lower(hex(randomblob(16)))),
  slug TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  description TEXT,
  price INTEGER NOT NULL,   -- cents
  inventory INTEGER DEFAULT 0,
  active INTEGER DEFAULT 1, -- SQLite boolean
  created_at TEXT DEFAULT (datetime('now')),
  updated_at TEXT DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_products_slug ON products(slug);
CREATE INDEX IF NOT EXISTS idx_products_active ON products(active);
```

### D1 Query Patterns

```typescript
// Single row
const product = await env.DB.prepare(
  "SELECT * FROM products WHERE slug = ?"
).bind(slug).first<Product>();

if (!product) return c.json({ error: "Not found" }, 404);

// Multiple rows
const { results } = await env.DB.prepare(
  "SELECT * FROM products WHERE active = 1 ORDER BY created_at DESC LIMIT ? OFFSET ?"
).bind(limit, offset).all<Product>();

// Insert
const newProduct = await env.DB.prepare(
  "INSERT INTO products (slug, name, price) VALUES (?, ?, ?) RETURNING *"
).bind(slug, name, price).first<Product>();

// Update
await env.DB.prepare(
  "UPDATE products SET price = ?, updated_at = datetime('now') WHERE id = ?"
).bind(newPrice, id).run();

// Delete
await env.DB.prepare("DELETE FROM products WHERE id = ?").bind(id).run();

// Transaction (batch)
const batch = await env.DB.batch([
  env.DB.prepare("UPDATE inventory SET count = count - ? WHERE product_id = ?")
    .bind(quantity, productId),
  env.DB.prepare("INSERT INTO orders (product_id, quantity) VALUES (?, ?)")
    .bind(productId, quantity),
]);
```

### Using Drizzle ORM with D1

```bash
npm install drizzle-orm
npm install drizzle-kit --save-dev
```

```typescript
// db/schema.ts
import { sqliteTable, text, integer } from "drizzle-orm/sqlite-core";
import { sql } from "drizzle-orm";

export const products = sqliteTable("products", {
  id: text("id").primaryKey().default(sql`(lower(hex(randomblob(16))))`),
  slug: text("slug").notNull().unique(),
  name: text("name").notNull(),
  price: integer("price").notNull(),
  active: integer("active", { mode: "boolean" }).default(true),
  createdAt: text("created_at").default(sql`(datetime('now'))`),
});

// drizzle.config.ts
import { defineConfig } from "drizzle-kit";
export default defineConfig({
  schema: "./db/schema.ts",
  out: "./migrations",
  dialect: "sqlite",
  driver: "d1-http",
  dbCredentials: {
    accountId: process.env.CLOUDFLARE_ACCOUNT_ID!,
    databaseId: process.env.CLOUDFLARE_D1_DATABASE_ID!,
    token: process.env.CLOUDFLARE_API_TOKEN!,
  },
});

// Usage in Worker
import { drizzle } from "drizzle-orm/d1";
import { products } from "./db/schema";
import { eq } from "drizzle-orm";

const db = drizzle(env.DB);
const allProducts = await db.select().from(products).where(eq(products.active, true));
```

---

## KV (Key-Value Store)

Best for: session data, rate limiting counters, feature flags, caching API responses.

```typescript
// Write
await env.CACHE.put("user:123", JSON.stringify(userData));
await env.CACHE.put("product:abc", JSON.stringify(product), {
  expirationTtl: 3600,  // 1 hour in seconds
});

// Write with metadata
await env.CACHE.put("session:xyz", userId, {
  expirationTtl: 86400,
  metadata: { createdAt: Date.now(), ip: request.headers.get("CF-Connecting-IP") },
});

// Read
const raw = await env.CACHE.get("user:123");
const user = raw ? JSON.parse(raw) : null;

// Read with metadata
const { value, metadata } = await env.CACHE.getWithMetadata<{ createdAt: number }>("session:xyz");

// Read as JSON directly
const data = await env.CACHE.get("config", { type: "json" });

// Delete
await env.CACHE.delete("user:123");

// List keys
const { keys, list_complete, cursor } = await env.CACHE.list({ prefix: "user:", limit: 100 });
```

---

## R2 Object Storage

Best for: images, PDFs, user uploads, static assets, backups.

```typescript
// Upload
await env.STORAGE.put("images/product-abc.jpg", imageBuffer, {
  httpMetadata: {
    contentType: "image/jpeg",
    cacheControl: "public, max-age=31536000",
  },
  customMetadata: { productId: "abc", uploadedBy: "user-123" },
});

// Download
const object = await env.STORAGE.get("images/product-abc.jpg");
if (!object) return new Response("Not Found", { status: 404 });

return new Response(object.body, {
  headers: {
    "Content-Type": object.httpMetadata?.contentType ?? "application/octet-stream",
    "Cache-Control": "public, max-age=31536000",
    "ETag": object.httpEtag,
  },
});

// Delete
await env.STORAGE.delete("images/product-abc.jpg");

// List objects
const { objects, truncated, cursor } = await env.STORAGE.list({
  prefix: "images/",
  limit: 100,
});

// Multipart upload (large files)
const upload = await env.STORAGE.createMultipartUpload("large-file.zip");
// ... upload parts
await upload.complete(parts);
```

### Presigned URL for direct upload (using Workers as proxy)

```typescript
// Since R2 doesn't have presigned URLs natively, proxy uploads through Worker:
app.post("/api/upload", async (c) => {
  const formData = await c.req.formData();
  const file = formData.get("file") as File;

  if (!file) return c.json({ error: "No file" }, 400);

  const key = `uploads/${crypto.randomUUID()}-${file.name}`;
  const buffer = await file.arrayBuffer();

  await c.env.STORAGE.put(key, buffer, {
    httpMetadata: { contentType: file.type },
  });

  return c.json({ key, url: `https://cdn.yourdomain.com/${key}` });
});
```

---

## Cloudflare Pages

### Deploy Next.js to Pages

```bash
# Install Pages adapter
npm install @cloudflare/next-on-pages
npm install wrangler --save-dev

# package.json
{
  "scripts": {
    "pages:build": "npx @cloudflare/next-on-pages",
    "pages:deploy": "wrangler pages deploy .vercel/output/static",
    "preview": "npx @cloudflare/next-on-pages && wrangler pages dev .vercel/output/static"
  }
}
```

```toml
# wrangler.toml (for Pages with bindings)
[[d1_databases]]
binding = "DB"
database_name = "my-db"
database_id = "xxx"

pages_build_output_dir = ".vercel/output/static"
```

### Pages Functions (file-based routing)

```typescript
// functions/api/products.ts
import type { PagesFunction } from "@cloudflare/workers-types";

interface Env {
  DB: D1Database;
}

export const onRequest: PagesFunction<Env> = async (context) => {
  const { env, request } = context;
  const products = await env.DB.prepare("SELECT * FROM products").all();
  return Response.json(products.results);
};

// Dynamic route: functions/api/products/[id].ts
export const onRequestGet: PagesFunction<Env> = async ({ params, env }) => {
  const product = await env.DB.prepare("SELECT * FROM products WHERE id = ?")
    .bind(params.id).first();
  return product ? Response.json(product) : new Response("Not Found", { status: 404 });
};
```

---

## Secrets Management

```bash
# Set secrets (never in wrangler.toml)
wrangler secret put STRIPE_SECRET_KEY
wrangler secret put DATABASE_URL

# List secrets
wrangler secret list

# Delete
wrangler secret delete STRIPE_SECRET_KEY

# For Pages
wrangler pages secret put STRIPE_SECRET_KEY --project-name my-pages-project
```

---

## Local Development

```bash
# Start local dev server (uses Miniflare internally)
wrangler dev

# With local D1 (creates .wrangler/state/v3/d1/ SQLite)
wrangler dev --local

# Run D1 migrations locally
wrangler d1 execute my-database --local --file ./migrations/0001_init.sql

# Pages local dev
wrangler pages dev .vercel/output/static --d1 DB=my-database
```

---

## Migrating from Vercel

| Vercel | Cloudflare |
|--------|------------|
| Vercel Functions | Workers |
| Vercel Edge Functions | Workers (native edge) |
| Vercel KV (Upstash Redis) | KV |
| Vercel Postgres (Neon) | D1 |
| Vercel Blob | R2 |
| ISR | Workers Cache API + KV |
| Environment Variables | `wrangler.toml` vars + secrets |
| Preview Deployments | Pages branch deployments |

### ISR equivalent in Workers

```typescript
// Cache with stale-while-revalidate pattern
async function getWithCache(key: string, fetcher: () => Promise<unknown>, ttl = 60) {
  const cached = await env.CACHE.get(key, { type: "json" });
  if (cached) {
    // Refresh in background (stale-while-revalidate)
    ctx.waitUntil(
      fetcher().then((fresh) => env.CACHE.put(key, JSON.stringify(fresh), { expirationTtl: ttl }))
    );
    return cached;
  }
  const fresh = await fetcher();
  await env.CACHE.put(key, JSON.stringify(fresh), { expirationTtl: ttl });
  return fresh;
}
```

---

## Durable Objects (Stateful Workers)

Use for: real-time collaboration, rate limiting with strong consistency, counters, distributed locks.

```typescript
// src/counter.ts
export class Counter implements DurableObject {
  private state: DurableObjectState;
  private count: number = 0;

  constructor(state: DurableObjectState) {
    this.state = state;
    this.state.blockConcurrencyWhile(async () => {
      this.count = (await this.state.storage.get<number>("count")) ?? 0;
    });
  }

  async fetch(request: Request): Promise<Response> {
    const url = new URL(request.url);

    if (url.pathname === "/increment") {
      this.count++;
      await this.state.storage.put("count", this.count);
      return Response.json({ count: this.count });
    }

    if (url.pathname === "/value") {
      return Response.json({ count: this.count });
    }

    return new Response("Not Found", { status: 404 });
  }
}

// Access from a Worker
const id = env.COUNTER.idFromName("global-counter");
const stub = env.COUNTER.get(id);
const response = await stub.fetch(new Request("http://do/increment"));
const { count } = await response.json();
```

## GitNexus Index
This skill is indexed by GitNexus for knowledge graph traversal.
Index path: /Users/localuser/claude-skill-vault/skills/cloud-devops/cloudflare-expert/.gitnexus
Last indexed: 2026-05-23
