---
name: drizzle-orm
description: >
  Drizzle ORM type-safe SQL queries, schema definition, migrations, and Supabase/Postgres integration. Triggers on: drizzle-orm, drizzle, pgTable, mysqlTable, eq(), and(), drizzle migrate, drizzle-kit, schema.ts drizzle.
---

# Drizzle ORM

## When to Use
Use when you need type-safe SQL with full TypeScript inference, want explicit control over queries (no magic), or are integrating with Supabase Postgres.

---

## Core Rules
- Schema is the single source of truth — infer all types from it, never duplicate
- Always use `drizzle-kit` for migrations — never write raw SQL migration files by hand
- Use `.returning()` after insert/update to get the full row back
- Transactions for multi-table writes — always
- Prefer `.select({ col: table.col })` for partial selects over fetching full rows

---

## Install

```bash
npm install drizzle-orm postgres
npm install -D drizzle-kit
```

---

## Schema Definition

```typescript
// src/db/schema.ts
import {
  pgTable, serial, text, varchar, integer, boolean,
  timestamp, uuid, index, uniqueIndex, foreignKey,
} from 'drizzle-orm/pg-core';
import { relations } from 'drizzle-orm';

export const users = pgTable(
  'users',
  {
    id: uuid('id').defaultRandom().primaryKey(),
    email: varchar('email', { length: 255 }).notNull().unique(),
    name: text('name').notNull(),
    role: text('role', { enum: ['admin', 'user', 'viewer'] }).default('user').notNull(),
    active: boolean('active').default(true).notNull(),
    createdAt: timestamp('created_at', { withTimezone: true }).defaultNow().notNull(),
    updatedAt: timestamp('updated_at', { withTimezone: true }).defaultNow().notNull(),
  },
  (table) => ({
    emailIdx: uniqueIndex('users_email_idx').on(table.email),
    createdAtIdx: index('users_created_at_idx').on(table.createdAt),
  })
);

export const posts = pgTable('posts', {
  id: uuid('id').defaultRandom().primaryKey(),
  title: text('title').notNull(),
  body: text('body'),
  published: boolean('published').default(false).notNull(),
  authorId: uuid('author_id')
    .notNull()
    .references(() => users.id, { onDelete: 'cascade' }),
  createdAt: timestamp('created_at', { withTimezone: true }).defaultNow().notNull(),
});

// Relations (for query builder joins)
export const usersRelations = relations(users, ({ many }) => ({
  posts: many(posts),
}));

export const postsRelations = relations(posts, ({ one }) => ({
  author: one(users, {
    fields: [posts.authorId],
    references: [users.id],
  }),
}));

// Type inference — derive types from schema
export type User = typeof users.$inferSelect;
export type NewUser = typeof users.$inferInsert;
export type Post = typeof posts.$inferSelect;
export type NewPost = typeof posts.$inferInsert;
```

---

## Database Connection

```typescript
// src/db/index.ts
import { drizzle } from 'drizzle-orm/postgres-js';
import postgres from 'postgres';
import * as schema from './schema';

const connectionString = process.env.DATABASE_URL!;

// For migrations — disable connection pooling
export const migrationClient = postgres(connectionString, { max: 1 });

// For queries — use pooling
const queryClient = postgres(connectionString);
export const db = drizzle(queryClient, { schema });
```

### Supabase Connection
```typescript
// Use Supabase connection pooler (port 6543) for serverless/edge
const connectionString = process.env.DATABASE_URL!;
// DATABASE_URL=postgresql://postgres.[ref]:[password]@aws-0-us-east-1.pooler.supabase.com:6543/postgres

const client = postgres(connectionString, { prepare: false }); // prepare: false required for pooler
export const db = drizzle(client, { schema });
```

---

## Query API

### Select
```typescript
import { eq, and, or, like, gte, lte, desc, asc, isNull, inArray } from 'drizzle-orm';

// All rows
const allUsers = await db.select().from(users);

// Partial select (typed — only fetches specified columns)
const emails = await db.select({ id: users.id, email: users.email }).from(users);

// Where clause
const user = await db
  .select()
  .from(users)
  .where(eq(users.email, 'user@example.com'))
  .limit(1);

// Compound conditions
const activeAdmins = await db
  .select()
  .from(users)
  .where(and(eq(users.active, true), eq(users.role, 'admin')));

// Pagination
const page = await db
  .select()
  .from(posts)
  .orderBy(desc(posts.createdAt))
  .limit(20)
  .offset(40);

// Like / ilike
const results = await db
  .select()
  .from(users)
  .where(like(users.name, '%Example User%'));   // case-sensitive
  // .where(ilike(users.name, '%bryan%')); // case-insensitive

// In array
const specific = await db
  .select()
  .from(users)
  .where(inArray(users.id, ['uuid-1', 'uuid-2', 'uuid-3']));
```

### Insert
```typescript
// Single insert with returning
const [newUser] = await db
  .insert(users)
  .values({
    email: 'user@example.com',
    name: 'Example User',
    role: 'admin',
  })
  .returning();

// Bulk insert
const newPosts = await db
  .insert(posts)
  .values([
    { title: 'First Post', authorId: newUser.id },
    { title: 'Second Post', authorId: newUser.id },
  ])
  .returning();

// Upsert (on conflict)
await db
  .insert(users)
  .values({ email: 'user@example.com', name: 'Example User' })
  .onConflictDoUpdate({
    target: users.email,
    set: { name: 'Example User Updated', updatedAt: new Date() },
  });
```

### Update
```typescript
const [updated] = await db
  .update(users)
  .set({ name: 'Example User F', updatedAt: new Date() })
  .where(eq(users.id, userId))
  .returning();

// Update with condition on multiple columns
await db
  .update(posts)
  .set({ published: true })
  .where(and(eq(posts.authorId, userId), eq(posts.published, false)));
```

### Delete
```typescript
const [deleted] = await db
  .delete(users)
  .where(eq(users.id, userId))
  .returning();

// Soft delete pattern
await db
  .update(users)
  .set({ active: false, updatedAt: new Date() })
  .where(eq(users.id, userId));
```

---

## Joins

```typescript
import { sql } from 'drizzle-orm';

// Inner join
const postsWithAuthors = await db
  .select({
    postId: posts.id,
    title: posts.title,
    authorName: users.name,
    authorEmail: users.email,
  })
  .from(posts)
  .innerJoin(users, eq(posts.authorId, users.id))
  .where(eq(posts.published, true))
  .orderBy(desc(posts.createdAt));

// Left join
const usersWithPosts = await db
  .select({
    user: users,
    postCount: sql<number>`count(${posts.id})::int`,
  })
  .from(users)
  .leftJoin(posts, eq(users.id, posts.authorId))
  .groupBy(users.id);
```

### Relational Query API (with relations defined)
```typescript
// Nested fetch using relations
const usersWithPosts = await db.query.users.findMany({
  where: eq(users.active, true),
  with: {
    posts: {
      where: eq(posts.published, true),
      orderBy: [desc(posts.createdAt)],
      limit: 5,
    },
  },
  limit: 10,
});
// Returns: User & { posts: Post[] }[]
```

---

## Transactions

```typescript
const result = await db.transaction(async (tx) => {
  // All queries inside use the same connection
  const [user] = await tx
    .insert(users)
    .values({ email: 'new@example.com', name: 'New User' })
    .returning();

  const [post] = await tx
    .insert(posts)
    .values({ title: 'First Post', authorId: user.id })
    .returning();

  // Rollback by throwing — transaction auto-rolls back
  if (!post) throw new Error('Post creation failed');

  return { user, post };
});
```

---

## Migrations (drizzle-kit)

### Config
```typescript
// drizzle.config.ts
import { defineConfig } from 'drizzle-kit';

export default defineConfig({
  schema: './src/db/schema.ts',
  out: './drizzle',
  dialect: 'postgresql',
  dbCredentials: {
    url: process.env.DATABASE_URL!,
  },
});
```

### Commands
```bash
# Generate migration file from schema changes
npx drizzle-kit generate

# Push schema directly to DB (dev only — skips migration files)
npx drizzle-kit push

# Run pending migrations
npx drizzle-kit migrate

# Open Drizzle Studio (GUI)
npx drizzle-kit studio

# Check diff between schema and DB
npx drizzle-kit check
```

### Run Migrations Programmatically
```typescript
// scripts/migrate.ts
import { migrate } from 'drizzle-orm/postgres-js/migrator';
import { drizzle } from 'drizzle-orm/postgres-js';
import postgres from 'postgres';

const client = postgres(process.env.DATABASE_URL!, { max: 1 });
const db = drizzle(client);

await migrate(db, { migrationsFolder: './drizzle' });
await client.end();
```

---

## Raw SQL When Needed

```typescript
import { sql } from 'drizzle-orm';

// Inline SQL expression
const result = await db
  .select({ count: sql<number>`count(*)::int` })
  .from(users);

// Full raw query
const rows = await db.execute(
  sql`SELECT * FROM users WHERE email ILIKE ${'%' + search + '%'} LIMIT 10`
);
```

---

## Type Inference Patterns

```typescript
// From schema
type User = typeof users.$inferSelect;     // full row
type NewUser = typeof users.$inferInsert;  // insert shape (all optional except notNull)

// Partial select — use z.infer or manual Pick
type UserPreview = Pick<User, 'id' | 'name' | 'email'>;

// With relations
type UserWithPosts = typeof users.$inferSelect & {
  posts: typeof posts.$inferSelect[];
};
```

---

## Quick Reference

| Task | Pattern |
|---|---|
| Insert + get row | `.insert().values().returning()` |
| Upsert | `.onConflictDoUpdate({ target, set })` |
| Pagination | `.limit(n).offset(n)` |
| Joins | `.innerJoin(table, eq(a.id, b.fk))` |
| Nested data | `db.query.table.findMany({ with: {} })` |
| Raw SQL | `sql\`...\`` template tag |
| Multi-table write | `db.transaction(async (tx) => { ... })` |
| Supabase pooler | `postgres(url, { prepare: false })` |
