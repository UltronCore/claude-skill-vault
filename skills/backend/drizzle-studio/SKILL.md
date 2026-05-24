---
name: drizzle-studio
description: Set up and use Drizzle Studio — a visual database browser for Drizzle ORM projects. Use this skill whenever the user wants to browse, edit, or inspect their database visually while using Drizzle ORM, or wants to set up Drizzle Kit with a GUI. Also covers Drizzle ORM schema definition, migrations with drizzle-kit, and the full Drizzle + Studio workflow. Trigger for "drizzle studio", "drizzle orm gui", "visual database browser drizzle", or "drizzle-kit studio".
---

# Drizzle Studio: Visual Database Browser for Drizzle ORM

Drizzle Studio is a web-based GUI that comes with Drizzle Kit. It lets you browse tables, run queries, edit records, and inspect your schema — all without leaving your dev environment.

## Installation

```bash
# Install Drizzle ORM + Kit
npm install drizzle-orm
npm install -D drizzle-kit

# For specific database drivers
npm install pg           # PostgreSQL
npm install better-sqlite3   # SQLite
npm install mysql2       # MySQL
```

## Setup: drizzle.config.ts

```typescript
// drizzle.config.ts
import { defineConfig } from 'drizzle-kit'

export default defineConfig({
  schema: './src/db/schema.ts',
  out: './drizzle',         // migrations output directory
  dialect: 'postgresql',   // 'postgresql' | 'mysql' | 'sqlite' | 'turso'
  dbCredentials: {
    url: process.env.DATABASE_URL!,
  },
  verbose: true,
  strict: true,
})
```

## Schema Definition

```typescript
// src/db/schema.ts
import { pgTable, serial, varchar, text, timestamp, integer, boolean, uuid, index, uniqueIndex } from 'drizzle-orm/pg-core'
import { relations } from 'drizzle-orm'

export const users = pgTable('users', {
  id: uuid('id').primaryKey().defaultRandom(),
  name: varchar('name', { length: 255 }).notNull(),
  email: varchar('email', { length: 255 }).notNull().unique(),
  passwordHash: text('password_hash').notNull(),
  role: varchar('role', { length: 50 }).notNull().default('user'),
  emailVerified: boolean('email_verified').notNull().default(false),
  createdAt: timestamp('created_at').notNull().defaultNow(),
  updatedAt: timestamp('updated_at').notNull().defaultNow(),
}, (table) => ({
  emailIdx: uniqueIndex('users_email_idx').on(table.email),
  roleIdx: index('users_role_idx').on(table.role),
}))

export const posts = pgTable('posts', {
  id: serial('id').primaryKey(),
  title: varchar('title', { length: 255 }).notNull(),
  content: text('content'),
  authorId: uuid('author_id').notNull().references(() => users.id, { onDelete: 'cascade' }),
  published: boolean('published').notNull().default(false),
  createdAt: timestamp('created_at').notNull().defaultNow(),
})

// Define relations
export const usersRelations = relations(users, ({ many }) => ({
  posts: many(posts),
}))

export const postsRelations = relations(posts, ({ one }) => ({
  author: one(users, {
    fields: [posts.authorId],
    references: [users.id],
  }),
}))
```

## Database Connection

```typescript
// src/db/index.ts
import { drizzle } from 'drizzle-orm/node-postgres'
import { Pool } from 'pg'
import * as schema from './schema'

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
})

export const db = drizzle(pool, { schema })
export type DB = typeof db
```

## Migrations

```bash
# Generate migration files from schema changes
npx drizzle-kit generate

# Apply pending migrations to database
npx drizzle-kit migrate

# Push schema directly (dev only — no migration files)
npx drizzle-kit push

# Check migration status
npx drizzle-kit check

# Drop all tables (destructive — dev only)
npx drizzle-kit drop
```

## Launch Drizzle Studio

```bash
# Start Studio (opens at https://local.drizzle.studio)
npx drizzle-kit studio

# Custom port
npx drizzle-kit studio --port 4983

# With verbose logging
npx drizzle-kit studio --verbose
```

Studio opens at `https://local.drizzle.studio` with:
- Table browser — view all tables and their data
- Record editor — create, update, delete rows
- SQL editor — run raw queries
- Schema viewer — see column types, constraints, indexes
- Relations — visualize foreign key relationships

## Querying with Drizzle ORM

```typescript
import { db } from './db'
import { users, posts } from './db/schema'
import { eq, and, like, desc, count, sql } from 'drizzle-orm'

// Select
const allUsers = await db.select().from(users)

// Filtered
const admins = await db
  .select({ id: users.id, name: users.name, email: users.email })
  .from(users)
  .where(and(eq(users.role, 'admin'), eq(users.emailVerified, true)))
  .orderBy(desc(users.createdAt))
  .limit(10)

// With relations
const usersWithPosts = await db.query.users.findMany({
  with: {
    posts: {
      where: eq(posts.published, true),
      orderBy: desc(posts.createdAt),
    },
  },
  limit: 20,
})

// Insert
const [newUser] = await db
  .insert(users)
  .values({ name: 'Alice', email: 'alice@example.com', passwordHash: '...' })
  .returning()

// Update
await db
  .update(users)
  .set({ emailVerified: true, updatedAt: new Date() })
  .where(eq(users.id, userId))

// Delete
await db.delete(posts).where(eq(posts.authorId, userId))

// Aggregate
const [{ total }] = await db
  .select({ total: count() })
  .from(users)
  .where(eq(users.role, 'user'))
```

## Seeding

```typescript
// src/db/seed.ts
import { db } from './index'
import { users, posts } from './schema'

async function seed() {
  console.log('Seeding database...')

  const [alice, bob] = await db
    .insert(users)
    .values([
      { name: 'Alice', email: 'alice@example.com', passwordHash: 'hash1', role: 'admin' },
      { name: 'Bob', email: 'bob@example.com', passwordHash: 'hash2' },
    ])
    .returning()

  await db.insert(posts).values([
    { title: 'Hello World', content: 'First post!', authorId: alice.id, published: true },
    { title: 'Draft Post', content: 'Not published yet', authorId: bob.id },
  ])

  console.log('Done!')
  process.exit(0)
}

seed().catch((e) => { console.error(e); process.exit(1) })
```

```bash
npx tsx src/db/seed.ts
# or add to package.json: "seed": "tsx src/db/seed.ts"
```

## SQLite Setup (for local/embedded databases)

```typescript
// drizzle.config.ts
import { defineConfig } from 'drizzle-kit'
export default defineConfig({
  schema: './src/db/schema.ts',
  out: './drizzle',
  dialect: 'sqlite',
  dbCredentials: { url: './local.db' },
})

// src/db/index.ts
import { drizzle } from 'drizzle-orm/better-sqlite3'
import Database from 'better-sqlite3'
import * as schema from './schema'

const sqlite = new Database('./local.db')
export const db = drizzle(sqlite, { schema })
```

## package.json Scripts

```json
{
  "scripts": {
    "db:generate": "drizzle-kit generate",
    "db:migrate": "drizzle-kit migrate",
    "db:push": "drizzle-kit push",
    "db:studio": "drizzle-kit studio",
    "db:seed": "tsx src/db/seed.ts",
    "db:check": "drizzle-kit check"
  }
}
```

## Turso (Edge SQLite) Setup

```typescript
import { defineConfig } from 'drizzle-kit'
export default defineConfig({
  dialect: 'turso',
  schema: './src/db/schema.ts',
  out: './drizzle',
  dbCredentials: {
    url: process.env.TURSO_URL!,
    authToken: process.env.TURSO_AUTH_TOKEN,
  },
})
```

## GitNexus Index

This skill is indexed by GitNexus for knowledge graph traversal.
Index path: /Users/localuser/.claude/skills/drizzle-studio/.gitnexus
Last indexed: 2026-05-24
