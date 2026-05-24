---
name: prisma-patterns
description: >
  Prisma ORM advanced patterns: schema design, migrations, relation queries, transactions, and performance. Triggers on: Prisma, prisma.client, PrismaClient, schema.prisma, prisma migrate, include, select, createMany, transaction.
---

# Prisma Patterns

## When to Use

Use this skill for Prisma schema design, writing efficient queries, handling migrations, managing transactions, and integrating Prisma with Supabase in Next.js apps.

---

## PrismaClient Singleton (Next.js)

```typescript
// lib/db.ts — prevent multiple instances in Next.js dev (hot reload)
import { PrismaClient } from '@prisma/client'

const globalForPrisma = globalThis as unknown as { prisma: PrismaClient }

export const db =
  globalForPrisma.prisma ??
  new PrismaClient({
    log: process.env.NODE_ENV === 'development' ? ['query', 'warn', 'error'] : ['error'],
  })

if (process.env.NODE_ENV !== 'production') globalForPrisma.prisma = db
```

---

## Schema Design Best Practices

```prisma
// schema.prisma

generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider  = "postgresql"
  url       = env("DATABASE_URL")
  directUrl = env("DIRECT_URL")  // required for Supabase (bypasses pooler for migrations)
}

// ─── NAMING CONVENTIONS ────────────────────────────────────────────────────────
// Models: PascalCase singular (User, Post, Comment)
// Fields: camelCase (firstName, createdAt)
// DB columns: snake_case mapped via @map
// Tables: snake_case via @@map

model User {
  id        String   @id @default(cuid())   // cuid() for shorter IDs, uuid() for standards
  email     String   @unique
  name      String
  role      Role     @default(USER)
  createdAt DateTime @default(now()) @map("created_at")
  updatedAt DateTime @updatedAt       @map("updated_at")

  // Relations
  posts     Post[]
  profile   Profile?
  sessions  Session[]

  @@map("users")  // actual table name in DB
  @@index([email])  // add indexes for frequent query fields
}

enum Role {
  ADMIN
  USER
  GUEST
}

model Post {
  id          String    @id @default(cuid())
  title       String
  slug        String    @unique
  content     String?   @db.Text         // for long text
  published   Boolean   @default(false)
  publishedAt DateTime?
  createdAt   DateTime  @default(now()) @map("created_at")
  updatedAt   DateTime  @updatedAt       @map("updated_at")

  // Foreign key
  authorId    String    @map("author_id")
  author      User      @relation(fields: [authorId], references: [id], onDelete: Cascade)

  // Many-to-many via explicit join table
  tags        PostTag[]

  @@index([authorId])
  @@index([published, publishedAt])  // composite index for filtered + sorted queries
  @@map("posts")
}

// Explicit many-to-many join table (use when you need extra fields on the relation)
model PostTag {
  postId    String   @map("post_id")
  tagId     String   @map("tag_id")
  createdAt DateTime @default(now())

  post      Post @relation(fields: [postId], references: [id], onDelete: Cascade)
  tag       Tag  @relation(fields: [tagId], references: [id], onDelete: Cascade)

  @@id([postId, tagId])  // composite primary key
  @@map("post_tags")
}

model Tag {
  id    String    @id @default(cuid())
  name  String    @unique
  slug  String    @unique
  posts PostTag[]

  @@map("tags")
}

// One-to-one relation
model Profile {
  id        String  @id @default(cuid())
  bio       String? @db.Text
  avatarUrl String? @map("avatar_url")
  website   String?

  userId    String  @unique @map("user_id")
  user      User    @relation(fields: [userId], references: [id], onDelete: Cascade)

  @@map("profiles")
}
```

---

## Migrations

```bash
# Development workflow
npx prisma migrate dev --name add_user_role      # creates migration + applies + regenerates client
npx prisma migrate dev --name "add post tags"    # spaces OK in migration names
npx prisma generate                               # regenerate client only (no migration)
npx prisma db push                                # push schema directly without migration (prototyping only)

# Production
npx prisma migrate deploy                         # applies pending migrations (use in CI/CD)

# Reset dev database (destructive)
npx prisma migrate reset

# Inspect database
npx prisma studio                                 # visual DB browser
npx prisma db pull                                # introspect existing DB into schema

# Supabase-specific — run in postinstall for Vercel deploys
# package.json
"scripts": {
  "postinstall": "prisma generate"
}
```

---

## `select` vs `include`

```typescript
// include — adds related records to the result (JOIN)
// select — specify exactly which fields to return (both scalar and relations)
// NEVER use findMany without select/include in production — avoids over-fetching

// ✗ Over-fetches all fields including sensitive ones
const users = await db.user.findMany()

// ✓ select specific scalar fields
const users = await db.user.findMany({
  select: {
    id: true,
    name: true,
    email: true,
    // password, internalNotes etc. are excluded automatically
  },
})

// ✓ include relation with nested select
const posts = await db.post.findMany({
  where: { published: true },
  select: {
    id: true,
    title: true,
    slug: true,
    publishedAt: true,
    author: {
      select: {
        name: true,
        profile: {
          select: { avatarUrl: true },
        },
      },
    },
    tags: {
      select: {
        tag: {
          select: { name: true, slug: true },
        },
      },
    },
  },
  orderBy: { publishedAt: 'desc' },
  take: 20,
})

// Type inference — Prisma infers exact return type from select
type PostWithAuthor = Prisma.PostGetPayload<{
  select: {
    id: true
    title: true
    author: { select: { name: true } }
  }
}>
```

---

## Nested Create / Connect / Disconnect

```typescript
// Create with nested relations
const user = await db.user.create({
  data: {
    name: 'Example User',
    email: 'user@example.com',
    // Create related record simultaneously
    profile: {
      create: {
        bio: 'Web developer',
        website: 'https://example.dev',
      },
    },
  },
  include: { profile: true },
})

// Create post and connect existing tags
const post = await db.post.create({
  data: {
    title: 'New Post',
    slug: 'new-post',
    authorId: userId,
    // Connect existing tags by ID
    tags: {
      create: [
        { tag: { connect: { id: 'existing-tag-id' } } },
        { tag: { connectOrCreate: {
          where: { slug: 'nextjs' },
          create: { name: 'Next.js', slug: 'nextjs' },
        }}},
      ],
    },
  },
})

// Update: replace tag list entirely
await db.post.update({
  where: { id: postId },
  data: {
    tags: {
      deleteMany: {},                        // remove all existing
      create: newTagIds.map(tagId => ({      // add new ones
        tag: { connect: { id: tagId } },
      })),
    },
  },
})

// Disconnect without deleting
await db.user.update({
  where: { id: userId },
  data: {
    team: { disconnect: true },  // one-to-one disconnect
  },
})
```

---

## Transactions

```typescript
// Sequential operations — use $transaction for atomicity
async function transferCredits(fromId: string, toId: string, amount: number) {
  return db.$transaction(async (tx) => {
    // All operations in tx share a single DB transaction
    // If any throws, entire transaction rolls back

    const sender = await tx.user.findUnique({ where: { id: fromId } })
    if (!sender || sender.credits < amount) {
      throw new Error('Insufficient credits')
    }

    const [updated] = await Promise.all([
      tx.user.update({
        where: { id: fromId },
        data: { credits: { decrement: amount } },
      }),
      tx.user.update({
        where: { id: toId },
        data: { credits: { increment: amount } },
      }),
      tx.creditTransfer.create({
        data: { fromId, toId, amount },
      }),
    ])

    return updated
  })
}

// Simple atomic batch — interactive transaction not needed
await db.$transaction([
  db.post.updateMany({ where: { authorId: userId }, data: { published: false } }),
  db.user.update({ where: { id: userId }, data: { active: false } }),
])

// Transaction with timeout + isolation level
await db.$transaction(
  async (tx) => { /* ... */ },
  {
    maxWait: 5000,                   // max time to wait for connection (ms)
    timeout: 10000,                  // max transaction duration (ms)
    isolationLevel: 'Serializable',  // strongest isolation — use when reading + writing same data
  }
)
```

---

## Upsert Patterns

```typescript
// upsert — create if not exists, update if exists
const user = await db.user.upsert({
  where: { email: 'user@example.com' },
  create: {
    email: 'user@example.com',
    name: 'Example User',
    role: 'USER',
  },
  update: {
    name: 'Example User',  // update name if user already exists
    updatedAt: new Date(),
  },
})

// Sync tags — upsert each tag in a batch
async function syncTags(tags: { name: string; slug: string }[]) {
  return db.$transaction(
    tags.map(tag =>
      db.tag.upsert({
        where: { slug: tag.slug },
        create: tag,
        update: { name: tag.name },
      })
    )
  )
}

// createMany with skipDuplicates
await db.post.createMany({
  data: posts,
  skipDuplicates: true,  // ignore rows that violate unique constraints
})
```

---

## Soft Deletes

```typescript
// schema.prisma — add deletedAt field
model Post {
  // ...
  deletedAt DateTime? @map("deleted_at")
  @@map("posts")
}

// Prisma middleware for automatic soft delete filtering
db.$use(async (params, next) => {
  // Automatically exclude soft-deleted records
  if (params.model === 'Post') {
    if (params.action === 'findUnique' || params.action === 'findFirst') {
      params.action = 'findFirst'
      params.args.where = { ...params.args.where, deletedAt: null }
    }
    if (params.action === 'findMany') {
      params.args.where = { ...params.args.where, deletedAt: null }
    }
    // Intercept delete → convert to update
    if (params.action === 'delete') {
      params.action = 'update'
      params.args.data = { deletedAt: new Date() }
    }
    if (params.action === 'deleteMany') {
      params.action = 'updateMany'
      params.args.data = { deletedAt: new Date() }
    }
  }
  return next(params)
})

// Manual soft delete (without middleware)
await db.post.update({
  where: { id: postId },
  data: { deletedAt: new Date() },
})

// Query including soft-deleted
const allPosts = await db.post.findMany({
  where: {
    OR: [
      { deletedAt: null },
      { deletedAt: { not: null } },
    ],
  },
})
```

---

## Pagination: Cursor vs Offset

```typescript
// CURSOR-BASED — use for feeds, infinite scroll (stable, efficient)
async function getCursorPage(cursor?: string, limit = 20) {
  const posts = await db.post.findMany({
    take: limit + 1,  // fetch one extra to check if there's a next page
    skip: cursor ? 1 : 0,  // skip the cursor item itself
    cursor: cursor ? { id: cursor } : undefined,
    orderBy: { createdAt: 'desc' },
    select: { id: true, title: true, createdAt: true },
  })

  const hasNextPage = posts.length > limit
  const items = hasNextPage ? posts.slice(0, -1) : posts
  const nextCursor = hasNextPage ? items[items.length - 1].id : null

  return { items, nextCursor, hasNextPage }
}

// OFFSET-BASED — use for paginated tables with page numbers
async function getOffsetPage(page = 1, pageSize = 20) {
  const [items, total] = await db.$transaction([
    db.post.findMany({
      skip: (page - 1) * pageSize,
      take: pageSize,
      orderBy: { createdAt: 'desc' },
    }),
    db.post.count(),
  ])

  return {
    items,
    total,
    totalPages: Math.ceil(total / pageSize),
    currentPage: page,
    hasNextPage: page * pageSize < total,
  }
}
```

---

## Raw Queries

```typescript
// Use when Prisma's query builder can't express what you need
// Full-text search, complex aggregations, window functions, etc.

// $queryRaw — returns typed results
const results = await db.$queryRaw<Array<{ id: string; rank: number }>>`
  SELECT id, ts_rank(search_vector, plainto_tsquery('english', ${searchTerm})) as rank
  FROM posts
  WHERE search_vector @@ plainto_tsquery('english', ${searchTerm})
  ORDER BY rank DESC
  LIMIT ${limit}
`

// $executeRaw — for INSERT/UPDATE/DELETE that don't return rows
await db.$executeRaw`
  UPDATE users SET last_seen_at = NOW() WHERE id = ${userId}
`

// Parameterize ALWAYS — never interpolate user input directly
// ✓ Safe — Prisma uses prepared statements
await db.$queryRaw`SELECT * FROM users WHERE email = ${userEmail}`

// ✗ DANGEROUS — SQL injection risk
await db.$queryRawUnsafe(`SELECT * FROM users WHERE email = '${userEmail}'`)
```

---

## Prisma with Supabase

```bash
# .env
DATABASE_URL="postgresql://postgres.[project-ref]:[password]@aws-0-us-east-1.pooler.supabase.com:6543/postgres?pgbouncer=true"
DIRECT_URL="postgresql://postgres.[project-ref]:[password]@aws-0-us-east-1.pooler.supabase.com:5432/postgres"
```

```prisma
datasource db {
  provider  = "postgresql"
  url       = env("DATABASE_URL")   // transaction pooler — for app queries
  directUrl = env("DIRECT_URL")     // direct connection — for migrations
}
```

```typescript
// RLS (Row Level Security) — Prisma bypasses RLS by default (uses service role)
// To use RLS with user context, set the JWT and use Supabase client for user-scoped queries
// Use Prisma for admin/server operations, Supabase client for user-scoped operations

// Supabase storage + Prisma metadata pattern
async function createPostWithImage(data: CreatePostData, imageFile: File, userId: string) {
  // 1. Upload to Supabase Storage
  const { data: upload, error } = await supabase.storage
    .from('post-images')
    .upload(`${userId}/${Date.now()}-${imageFile.name}`, imageFile)

  if (error) throw error

  const { data: { publicUrl } } = supabase.storage
    .from('post-images')
    .getPublicUrl(upload.path)

  // 2. Save metadata to DB via Prisma
  return db.post.create({
    data: {
      ...data,
      imageUrl: publicUrl,
      authorId: userId,
    },
  })
}
```

## Related Skills
- `drizzle-orm` — alternative ORM
- `database-schema-designer` — schema design
- `supabase-prisma-database-management` — Supabase + Prisma

## GitNexus Index
This skill is indexed by GitNexus for knowledge graph traversal.
Index path: /Users/localuser/.claude/skills/prisma-patterns/.gitnexus
Last indexed: 2026-05-23
