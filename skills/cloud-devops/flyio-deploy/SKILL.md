---
name: flyio-deploy
description: >
  Fly.io deployment: flyctl, fly.toml, secrets, volumes, Postgres, and scaling. Triggers on: Fly.io, flyctl, fly.toml, fly deploy, fly secrets, fly volumes, Fly Postgres, fly machine.
---

# Fly.io Deploy

## When to Use
Use Fly.io for deploying Node.js/Bun/Next.js apps and APIs when you want fast global edge deployment, built-in Postgres, auto-scaling to zero, and simpler ops than AWS/GCP.

---

## Core Rules
- Always set `[env]` for non-secret config and `fly secrets set` for secrets — never commit secrets
- Use volumes for any data that must persist across deploys (SQLite, uploads)
- Set `min_machines_running = 0` to scale to zero (saves cost), `1` for always-on
- `fly deploy` = build + push + rolling deploy — it's safe for production
- Health checks prevent bad deploys from going live — always configure them

---

## Install flyctl

```bash
# macOS
brew install flyctl

# Or
curl -L https://fly.io/install.sh | sh

# Authenticate
fly auth login
```

---

## App Setup

```bash
# Launch new app (interactive — creates fly.toml, Dockerfile if needed)
fly launch

# Deploy existing app
fly deploy

# Deploy with specific Dockerfile
fly deploy -f Dockerfile.production

# Deploy without cache (full rebuild)
fly deploy --no-cache

# Status
fly status
fly logs
fly logs --app my-app-name
```

---

## fly.toml Structure

```toml
# fly.toml — complete reference for Next.js / Node.js / Bun app

app = "my-next-app"
primary_region = "ord"     # Chicago; also: iad (DC), lax (LA), fra (Frankfurt), nrt (Tokyo)
kill_signal = "SIGINT"
kill_timeout = "5s"

[build]
  # Uses Dockerfile by default
  # Or specify build args:
  # [build.args]
  #   NODE_VERSION = "20"

# Non-secret environment variables
[env]
  PORT = "3000"
  NODE_ENV = "production"
  NEXT_TELEMETRY_DISABLED = "1"

# HTTP service config
[http_service]
  internal_port = 3000          # port your app listens on
  force_https = true            # redirect HTTP → HTTPS
  auto_stop_machines = true     # scale to zero when no traffic
  auto_start_machines = true    # wake up on request
  min_machines_running = 0      # 0 = scale to zero, 1 = always-on

  [http_service.concurrency]
    type = "requests"           # or "connections"
    hard_limit = 200            # max concurrent requests before refusing
    soft_limit = 150            # start new machine at this threshold

# Health check — prevents bad deploys
[[http_service.checks]]
  grace_period = "5s"           # wait before first check
  interval = "15s"
  restart_limit = 3             # restart machine after N consecutive failures
  timeout = "2s"
  path = "/api/health"          # your health endpoint
  method = "GET"
  protocol = "http"

# Machine specs
[[vm]]
  memory = "512mb"              # 256mb, 512mb, 1gb, 2gb
  cpu_kind = "shared"           # "shared" or "performance"
  cpus = 1

# Persistent volume (for SQLite, uploaded files, etc.)
# [[mounts]]
#   source = "my_app_data"
#   destination = "/data"
```

---

## Dockerfile (Node.js / Next.js)

```dockerfile
# Dockerfile — optimized for Next.js
FROM node:20-alpine AS base
RUN apk add --no-cache libc6-compat
WORKDIR /app

# Dependencies
FROM base AS deps
COPY package.json package-lock.json* ./
RUN npm ci

# Build
FROM base AS builder
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN npm run build

# Production runner (minimal image)
FROM base AS runner
ENV NODE_ENV=production
ENV PORT=3000

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

COPY --from=builder /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs
EXPOSE 3000

CMD ["node", "server.js"]
```

### next.config.js for standalone output
```javascript
/** @type {import('next').NextConfig} */
const nextConfig = {
  output: 'standalone',  // required for Docker deployment
};
module.exports = nextConfig;
```

### Dockerfile (Bun)
```dockerfile
FROM oven/bun:1 AS builder
WORKDIR /app
COPY package.json bun.lockb ./
RUN bun install --frozen-lockfile
COPY . .
RUN bun run build

FROM oven/bun:1-slim AS runner
WORKDIR /app
ENV NODE_ENV=production
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules

EXPOSE 3000
CMD ["bun", "run", "dist/server.js"]
```

---

## Secrets Management

```bash
# Set secrets (environment variables, encrypted at rest)
fly secrets set DATABASE_URL="postgres://..." SUPABASE_SERVICE_ROLE_KEY="..."

# Set from stdin (for long values)
echo "my-secret-value" | fly secrets set MY_SECRET=-

# Set from .env file
cat .env.production | fly secrets import

# List secret names (values are never shown)
fly secrets list

# Remove a secret
fly secrets unset OLD_SECRET_NAME

# Secrets are available as regular env vars in your app
# process.env.DATABASE_URL
```

---

## Volumes (Persistent Storage)

```bash
# Create volume (in same region as app)
fly volumes create my_app_data --size 1   # 1 GB
fly volumes create my_app_data --size 10  # 10 GB, region auto-detected

# List volumes
fly volumes list

# Extend volume size (can grow, cannot shrink)
fly volumes extend vol_abc123 --size 5

# Volume backups
fly volumes snapshots list vol_abc123
```

```toml
# fly.toml — mount volume
[[mounts]]
  source = "my_app_data"      # volume name
  destination = "/data"        # path inside container
```

```typescript
// Use volume path in app
const UPLOAD_DIR = process.env.UPLOAD_DIR ?? '/data/uploads';
const DB_PATH = process.env.DB_PATH ?? '/data/app.db';
```

---

## Fly Postgres

```bash
# Create Postgres cluster
fly postgres create --name my-app-db --region ord --vm-size shared-cpu-1x --volume-size 10

# Attach to app (sets DATABASE_URL secret automatically)
fly postgres attach my-app-db --app my-app

# Connect to Postgres directly (proxies connection locally)
fly postgres connect -a my-app-db

# Proxy to localhost:5432 (use with psql, TablePlus, etc.)
fly proxy 5432 -a my-app-db
# then: psql postgresql://postgres@localhost:5432/my_app_db

# Connection strings
# Internal (app to db, same org): postgresql://postgres:password@my-app-db.internal:5432/my_app_db
# External: postgresql://postgres:password@my-app-db.fly.dev:5432/my_app_db (through proxy)
```

### Running Migrations on Deploy
```bash
# In fly.toml — run migrations before app starts
[deploy]
  release_command = "npm run db:migrate"  # runs in a temp machine before new version goes live
```

```json
// package.json
{
  "scripts": {
    "db:migrate": "npx drizzle-kit migrate"
  }
}
```

---

## Scaling

```bash
# Show current machines
fly machines list

# Scale to N machines
fly scale count 2             # 2 machines (for HA)
fly scale count 1 --region ord

# Scale VM size
fly scale vm shared-cpu-1x   # smallest
fly scale vm shared-cpu-2x
fly scale vm performance-2x  # dedicated CPU

# Scale memory
fly scale memory 512          # MB

# Auto-scaling config (in fly.toml)
# auto_stop_machines = true
# auto_start_machines = true
# min_machines_running = 0    # scale-to-zero
```

---

## Multi-Region

```bash
# Add regions
fly regions add lax fra nrt

# Set primary region (where Postgres writes go)
fly regions set-primary iad

# Show regions
fly regions list
```

```toml
# fly.toml multi-region example
primary_region = "iad"

# Fly will run machines in all added regions
# Postgres write connections: always route to primary region
# Use DATABASE_URL for writes, READ_REPLICA_URL for reads
```

---

## Health Checks

```typescript
// app/api/health/route.ts
import { NextResponse } from 'next/server';

export async function GET() {
  try {
    // Optionally check DB connection
    await db.execute(sql`SELECT 1`);

    return NextResponse.json({
      status: 'ok',
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
    });
  } catch (err) {
    return NextResponse.json({ status: 'error', error: String(err) }, { status: 503 });
  }
}
```

---

## Common Commands

```bash
# App management
fly apps list
fly status --app my-app
fly logs --app my-app -n 100           # last 100 lines
fly logs --app my-app --tail           # stream live

# SSH into running machine
fly ssh console --app my-app
fly ssh console -s                     # select machine interactively

# Restart app
fly machines restart

# Deploy to specific region
fly deploy --region ord

# Rollback (deploy previous image)
fly releases list
fly deploy --image registry.fly.io/my-app:deployment-abc123

# Open app in browser
fly open

# Destroy app (irreversible)
fly apps destroy my-app
```

---

## Quick Reference

| Task | Command |
|---|---|
| First deploy | `fly launch` |
| Deploy | `fly deploy` |
| View logs | `fly logs` |
| Set secret | `fly secrets set KEY=value` |
| Create volume | `fly volumes create name --size 5` |
| Create Postgres | `fly postgres create` |
| Attach Postgres | `fly postgres attach db-name` |
| SSH in | `fly ssh console` |
| Proxy Postgres | `fly proxy 5432 -a db-name` |
| Scale machines | `fly scale count 2` |
| Scale to zero | `min_machines_running = 0` in fly.toml |
| Run migration | `release_command` in fly.toml `[deploy]` |

## GitNexus Index
This skill is indexed by GitNexus for knowledge graph traversal.
Index path: /Users/localuser/claude-skill-vault/skills/cloud-devops/flyio-deploy/.gitnexus
Last indexed: 2026-05-23
