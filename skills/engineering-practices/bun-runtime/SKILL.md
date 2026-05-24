---
name: bun-runtime
description: >
  Bun JavaScript runtime for scripts, APIs, test runner, and bundler. Triggers on: bun, bun run, bun install, Bun.serve, Bun.file, bunx, bun test, bunfig.toml.
---

# Bun Runtime

## When to Use
Use Bun for scripts, standalone API servers, CLI tools, or any new Node-compatible project where startup speed and all-in-one tooling matter. Also use when migrating off Node/pnpm for performance gains.

---

## Core Rules
- Bun is Node-compatible — most npm packages work without changes
- Use `Bun.serve()` for HTTP servers (much faster than Node http)
- `Bun.file()` is lazy — it doesn't read the file until you call `.text()`, `.json()`, `.arrayBuffer()`
- `bun:sqlite` is built-in and fast — no driver needed for SQLite
- `prepare: false` is needed when using Bun with Supabase connection pooler (PgBouncer)
- Bun test runner uses Jest-compatible API — most Jest tests work as-is

---

## Bun vs Node.js Comparison

| Feature | Node.js | Bun |
|---|---|---|
| Runtime | V8 (Chrome) | JavaScriptCore (Safari) |
| Startup | ~50-100ms | ~5ms |
| Package manager | npm/pnpm/yarn | bun install |
| Test runner | jest/vitest | bun test (built-in) |
| Bundler | webpack/esbuild | bun build (built-in) |
| TypeScript | Needs ts-node/tsx | Native (no config) |
| .env loading | dotenv package | Built-in |
| SQLite | better-sqlite3 | bun:sqlite (built-in) |
| Watch mode | nodemon/--watch | --watch (built-in) |

---

## Install & Setup

```bash
# Install Bun
curl -fsSL https://bun.sh/install | bash

# Init project
bun init

# Run TypeScript directly (no transpile step)
bun run script.ts

# Watch mode
bun --watch run script.ts

# Install packages (much faster than npm)
bun install
bun add zod drizzle-orm
bun add -d typescript @types/bun

# Run package scripts
bun run dev
bun run build
```

### bunfig.toml
```toml
# bunfig.toml — Bun config file
[install]
# Use local registry
# registry = "http://localhost:4873"
production = false    # install devDependencies by default

[test]
timeout = 5000        # ms per test
coverage = true

[run]
# bun run --smol uses less memory
bun = ["--smol"]
```

---

## Bun.serve() — HTTP Server

```typescript
// server.ts
import { serve, type ServeOptions } from 'bun';

const server = serve({
  port: process.env.PORT ? parseInt(process.env.PORT) : 3000,

  // Single fetch handler (replaces Express routing)
  fetch(req: Request): Response | Promise<Response> {
    const url = new URL(req.url);

    // Router
    if (url.pathname === '/health') {
      return Response.json({ status: 'ok', uptime: process.uptime() });
    }

    if (url.pathname === '/api/users' && req.method === 'GET') {
      return handleGetUsers(req);
    }

    if (url.pathname.startsWith('/api/users/') && req.method === 'GET') {
      const id = url.pathname.split('/').at(-1)!;
      return handleGetUser(req, id);
    }

    return new Response('Not Found', { status: 404 });
  },

  error(err: Error): Response {
    console.error(err);
    return Response.json({ error: 'Internal Server Error' }, { status: 500 });
  },
} satisfies ServeOptions);

console.log(`Listening on http://localhost:${server.port}`);

// Handler function
async function handleGetUsers(req: Request): Promise<Response> {
  // Parse query params
  const url = new URL(req.url);
  const limit = parseInt(url.searchParams.get('limit') ?? '10');

  const users = await db.select().from(usersTable).limit(limit);
  return Response.json(users);
}
```

### Middleware Pattern
```typescript
// Compose middleware manually (no framework needed)
type Handler = (req: Request, ctx: RequestContext) => Promise<Response>;
type Middleware = (next: Handler) => Handler;

const withAuth: Middleware = (next) => async (req, ctx) => {
  const token = req.headers.get('authorization')?.replace('Bearer ', '');
  if (!token) return new Response('Unauthorized', { status: 401 });

  const user = verifyJwt(token);
  if (!user) return new Response('Forbidden', { status: 403 });

  return next(req, { ...ctx, user });
};

const withCors: Middleware = (next) => async (req, ctx) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization',
      },
    });
  }
  const response = await next(req, ctx);
  response.headers.set('Access-Control-Allow-Origin', '*');
  return response;
};

// Apply middleware (right-to-left)
const handler = withCors(withAuth(myHandler));
```

---

## Bun.file() — File I/O

```typescript
// Read file (lazy — doesn't load until awaited)
const file = Bun.file('./data/config.json');

const text = await file.text();
const json = await file.json<Config>();
const buffer = await file.arrayBuffer();
const size = file.size;
const type = file.type; // MIME type

// Write file
await Bun.write('./output/result.json', JSON.stringify(data, null, 2));
await Bun.write('./output/file.txt', 'Hello from Bun');

// Copy
await Bun.write(Bun.file('./copy.txt'), Bun.file('./original.txt'));

// Stream large file
const stream = Bun.file('./large-video.mp4').stream();
return new Response(stream, {
  headers: { 'Content-Type': 'video/mp4' },
});

// Check if file exists
const exists = await Bun.file('./config.json').exists();
```

---

## bun:sqlite — Built-in SQLite

```typescript
import { Database } from 'bun:sqlite';

const db = new Database('./app.db', { create: true });

// Migrations
db.run(`
  CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    email TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    created_at TEXT DEFAULT (datetime('now'))
  )
`);

// Prepared statements (fast — reuse for repeated queries)
const insertUser = db.prepare<{ email: string; name: string }, []>(
  'INSERT INTO users (email, name) VALUES ($email, $name) RETURNING *'
);

const getUser = db.prepare<{ id: number }, [number]>(
  'SELECT * FROM users WHERE id = ?'
);

// Execute
const user = insertUser.get({ email: 'user@example.com', name: 'Example User' });
const found = getUser.get(1);
const all = db.query('SELECT * FROM users').all();

// Transaction
const createUserWithPost = db.transaction((userData: { email: string; name: string; postTitle: string }) => {
  const user = insertUser.get({ email: userData.email, name: userData.name })!;
  db.run('INSERT INTO posts (title, author_id) VALUES (?, ?)', [userData.postTitle, user.id]);
  return user;
});

const newUser = createUserWithPost({ email: 'a@b.com', name: 'A', postTitle: 'First Post' });
```

---

## bun test — Test Runner

```typescript
// user.test.ts
import { describe, it, expect, beforeAll, afterAll, mock, spyOn } from 'bun:test';

describe('UserService', () => {
  let service: UserService;

  beforeAll(() => {
    service = new UserService(testDb);
  });

  it('creates a user', async () => {
    const user = await service.create({ email: 'test@test.com', name: 'Test' });
    expect(user.id).toBeDefined();
    expect(user.email).toBe('test@test.com');
  });

  it('throws on duplicate email', async () => {
    await service.create({ email: 'dup@test.com', name: 'Dup' });
    expect(service.create({ email: 'dup@test.com', name: 'Dup 2' })).rejects.toThrow();
  });

  it('mocks external calls', async () => {
    const mockSend = mock(() => Promise.resolve({ id: 'email-1' }));
    const emailer = { send: mockSend };

    await service.createAndNotify({ email: 'n@test.com', name: 'N' }, emailer);

    expect(mockSend).toHaveBeenCalledTimes(1);
    expect(mockSend).toHaveBeenCalledWith(expect.objectContaining({ to: 'n@test.com' }));
  });
});

// Run
// bun test
// bun test --watch
// bun test --coverage
// bun test user.test.ts
```

---

## bun build — Bundler

```bash
# Bundle for browser
bun build ./src/index.ts --outdir ./dist --target browser --minify

# Bundle for Bun/Node (no bundling of externals)
bun build ./src/server.ts --outdir ./dist --target bun --external 'drizzle-orm' --external 'postgres'

# With sourcemaps
bun build ./src/index.ts --outdir ./dist --sourcemap=external

# Compile to single executable (no runtime needed!)
bun build ./src/cli.ts --compile --outfile ./bin/mycli
```

---

## Shell Scripting with Bun

```typescript
// scripts/deploy.ts
import { $ } from 'bun'; // Bun shell — available in Bun 1.0.24+

// Run commands
await $`git pull origin main`;
await $`bun install --frozen-lockfile`;
await $`bun run build`;

// Capture output
const { stdout } = await $`git log --oneline -5`.text();
console.log('Recent commits:', stdout);

// With error handling
try {
  await $`npm run test`;
} catch (err) {
  console.error('Tests failed:', err.stderr.toString());
  process.exit(1);
}

// Bun.spawnSync for synchronous use
const result = Bun.spawnSync(['git', 'status', '--short']);
const output = new TextDecoder().decode(result.stdout);
```

---

## Migrating from Node.js / pnpm

```bash
# Replace package manager
rm -rf node_modules package-lock.json yarn.lock pnpm-lock.yaml
bun install   # generates bun.lockb

# Replace scripts (package.json stays the same)
# "scripts": { "dev": "ts-node src/index.ts" }
# → bun run dev (Bun runs TypeScript natively)

# Replace dotenv
# remove: import 'dotenv/config'  (Bun loads .env automatically)

# Replace nodemon
# "dev": "nodemon src/index.ts"
# → "dev": "bun --watch run src/index.ts"
```

### Common Gotchas
```typescript
// ✗ __dirname not available in ESM (same as Node ESM)
// ✓ Use:
import.meta.dir   // directory of current file
import.meta.file  // full path of current file

// ✗ require() in .ts files
// ✓ Use import statements

// Bun loads .env automatically — no dotenv needed
// But: only in the main entry, not in workers
```

---

## Quick Reference

| Task | Command / API |
|---|---|
| Run TypeScript | `bun run file.ts` |
| Install packages | `bun install` / `bun add pkg` |
| Dev server | `bun --watch run server.ts` |
| Tests | `bun test` |
| Build | `bun build src/index.ts --outdir dist` |
| Compile binary | `bun build --compile --outfile app` |
| HTTP server | `Bun.serve({ fetch(req) {} })` |
| Read file | `await Bun.file('path').text()` |
| Write file | `await Bun.write('path', data)` |
| SQLite | `import { Database } from 'bun:sqlite'` |
| Shell command | `await $\`command\`` (Bun shell) |
| Current dir | `import.meta.dir` |

## Related Skills
- `typescript-expert` — TypeScript with Bun
- `fastapi-expert` — alternative backend
- `edge-computing-patterns` — edge deployment

## GitNexus Index
This skill is indexed by GitNexus for knowledge graph traversal.
Index path: /Users/localuser/.claude/skills/bun-runtime/.gitnexus
Last indexed: 2026-05-23
