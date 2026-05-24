---
name: trpc-expert
description: >
  tRPC v11 end-to-end type-safe APIs with Next.js App Router, Zod input validation, and React Query integration. Triggers on: tRPC, trpc, createTRPCRouter, publicProcedure, protectedProcedure, t.router, useQuery trpc.
---

# tRPC Expert (v11)

## When to Use

Use tRPC when your Next.js app owns both the frontend and backend and you want end-to-end type safety without generating types from a schema. tRPC shares types directly — no codegen, no REST contracts to maintain.

---

## Project Setup

```bash
npm install @trpc/server @trpc/client @trpc/react-query @tanstack/react-query zod
```

---

## Core tRPC Instance (`server/trpc.ts`)

```typescript
// server/trpc.ts
import { initTRPC, TRPCError } from '@trpc/server'
import { type CreateNextContextOptions } from '@trpc/server/adapters/next'
import { ZodError } from 'zod'
import superjson from 'superjson'
import { getServerSession } from 'next-auth'
import { authOptions } from '@/lib/auth'
import { db } from '@/lib/db'

// Context — available in every procedure
export async function createTRPCContext(opts: CreateNextContextOptions) {
  const session = await getServerSession(authOptions)
  return {
    db,
    session,
    req: opts.req,
  }
}

export type Context = Awaited<ReturnType<typeof createTRPCContext>>

// Initialize tRPC with transformer (required for Dates, Maps, Sets)
const t = initTRPC.context<Context>().create({
  transformer: superjson,
  errorFormatter({ shape, error }) {
    return {
      ...shape,
      data: {
        ...shape.data,
        // Surface Zod validation errors in a structured way
        zodError:
          error.cause instanceof ZodError ? error.cause.flatten() : null,
      },
    }
  },
})

// Reusable building blocks
export const router = t.router
export const publicProcedure = t.procedure
export const middleware = t.middleware
```

---

## Auth Middleware + Protected Procedure

```typescript
// server/trpc.ts (continued)
const isAuthenticated = middleware(({ ctx, next }) => {
  if (!ctx.session?.user) {
    throw new TRPCError({
      code: 'UNAUTHORIZED',
      message: 'You must be logged in to access this resource',
    })
  }
  // Type-narrow: session is non-null after this check
  return next({
    ctx: {
      ...ctx,
      session: ctx.session,
      user: ctx.session.user,
    },
  })
})

const isAdmin = middleware(({ ctx, next }) => {
  if (!ctx.session?.user || ctx.session.user.role !== 'admin') {
    throw new TRPCError({ code: 'FORBIDDEN', message: 'Admins only' })
  }
  return next({ ctx: { ...ctx, session: ctx.session } })
})

export const protectedProcedure = t.procedure.use(isAuthenticated)
export const adminProcedure = t.procedure.use(isAdmin)
```

---

## Router Setup

```typescript
// server/routers/users.ts
import { z } from 'zod'
import { router, publicProcedure, protectedProcedure } from '../trpc'
import { TRPCError } from '@trpc/server'

const CreateUserSchema = z.object({
  name: z.string().min(1, 'Name is required').max(100),
  email: z.string().email(),
  role: z.enum(['admin', 'user', 'guest']).default('user'),
})

const UpdateUserSchema = z.object({
  id: z.string().uuid(),
  name: z.string().min(1).optional(),
  email: z.string().email().optional(),
})

export const usersRouter = router({
  // Query — GET-style, cacheable
  getAll: publicProcedure.query(async ({ ctx }) => {
    return ctx.db.user.findMany({ orderBy: { createdAt: 'desc' } })
  }),

  getById: publicProcedure
    .input(z.string().uuid())
    .query(async ({ ctx, input }) => {
      const user = await ctx.db.user.findUnique({ where: { id: input } })
      if (!user) throw new TRPCError({ code: 'NOT_FOUND', message: 'User not found' })
      return user
    }),

  // Mutation — POST-style, not cached
  create: protectedProcedure
    .input(CreateUserSchema)
    .mutation(async ({ ctx, input }) => {
      const existing = await ctx.db.user.findUnique({ where: { email: input.email } })
      if (existing) throw new TRPCError({ code: 'CONFLICT', message: 'Email already in use' })

      return ctx.db.user.create({ data: input })
    }),

  update: protectedProcedure
    .input(UpdateUserSchema)
    .mutation(async ({ ctx, input }) => {
      const { id, ...data } = input
      return ctx.db.user.update({ where: { id }, data })
    }),

  delete: protectedProcedure
    .input(z.string().uuid())
    .mutation(async ({ ctx, input }) => {
      // Extra check: only allow deleting own account (or admin can delete anyone)
      if (ctx.user.id !== input && ctx.user.role !== 'admin') {
        throw new TRPCError({ code: 'FORBIDDEN' })
      }
      return ctx.db.user.delete({ where: { id: input } })
    }),
})

// server/routers/posts.ts
export const postsRouter = router({
  getInfinite: publicProcedure
    .input(z.object({
      limit: z.number().min(1).max(100).default(20),
      cursor: z.string().optional(),
    }))
    .query(async ({ ctx, input }) => {
      const { limit, cursor } = input
      const posts = await ctx.db.post.findMany({
        take: limit + 1,
        cursor: cursor ? { id: cursor } : undefined,
        orderBy: { createdAt: 'desc' },
      })
      const nextCursor = posts.length > limit ? posts.pop()!.id : undefined
      return { posts, nextCursor }
    }),
})
```

---

## Root Router

```typescript
// server/root.ts
import { router } from './trpc'
import { usersRouter } from './routers/users'
import { postsRouter } from './routers/posts'

export const appRouter = router({
  users: usersRouter,
  posts: postsRouter,
})

export type AppRouter = typeof appRouter
```

---

## Next.js App Router Adapter

```typescript
// app/api/trpc/[trpc]/route.ts
import { fetchRequestHandler } from '@trpc/server/adapters/fetch'
import { appRouter } from '@/server/root'
import { createTRPCContext } from '@/server/trpc'

const handler = (req: Request) =>
  fetchRequestHandler({
    endpoint: '/api/trpc',
    req,
    router: appRouter,
    createContext: () => createTRPCContext({ req } as any),
    onError:
      process.env.NODE_ENV === 'development'
        ? ({ path, error }) => {
            console.error(`tRPC error on ${path ?? '<no-path>'}:`, error)
          }
        : undefined,
  })

export { handler as GET, handler as POST }
```

---

## Client Setup

```typescript
// lib/trpc.ts
import { createTRPCReact } from '@trpc/react-query'
import type { AppRouter } from '@/server/root'

export const trpc = createTRPCReact<AppRouter>()

// app/providers.tsx
'use client'
import { useState } from 'react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { httpBatchLink, loggerLink } from '@trpc/client'
import superjson from 'superjson'
import { trpc } from '@/lib/trpc'

function getBaseUrl() {
  if (typeof window !== 'undefined') return ''                      // browser
  if (process.env.VERCEL_URL) return `https://${process.env.VERCEL_URL}`
  return `http://localhost:${process.env.PORT ?? 3000}`
}

export function TRPCProviders({ children }: { children: React.ReactNode }) {
  const [queryClient] = useState(() => new QueryClient({
    defaultOptions: { queries: { staleTime: 60_000 } },
  }))

  const [trpcClient] = useState(() =>
    trpc.createClient({
      links: [
        loggerLink({
          enabled: (opts) =>
            process.env.NODE_ENV === 'development' ||
            (opts.direction === 'down' && opts.result instanceof Error),
        }),
        httpBatchLink({
          url: `${getBaseUrl()}/api/trpc`,
          transformer: superjson,
          headers: () => ({
            // Add auth headers here if needed
          }),
        }),
      ],
    })
  )

  return (
    <trpc.Provider client={trpcClient} queryClient={queryClient}>
      <QueryClientProvider client={queryClient}>
        {children}
      </QueryClientProvider>
    </trpc.Provider>
  )
}
```

---

## React Client Usage

```typescript
'use client'
import { trpc } from '@/lib/trpc'

// Query — same as useQuery but fully typed
function UserList() {
  const { data, isLoading } = trpc.users.getAll.useQuery()

  if (isLoading) return <Skeleton />
  return <ul>{data?.map(u => <li key={u.id}>{u.name}</li>)}</ul>
}

// Query with input
function UserProfile({ id }: { id: string }) {
  const { data, isError } = trpc.users.getById.useQuery(id, {
    enabled: !!id,
    staleTime: 5 * 60_000,
  })

  if (isError) return <div>User not found</div>
  return <div>{data?.name}</div>
}

// Mutation with invalidation
function CreateUserForm() {
  const utils = trpc.useUtils()  // tRPC's wrapper around queryClient

  const createUser = trpc.users.create.useMutation({
    onSuccess: async () => {
      // Invalidate the users list to trigger a refetch
      await utils.users.getAll.invalidate()
    },
    onError: (err) => {
      // err.data?.zodError gives structured Zod errors
      const zodErrors = err.data?.zodError?.fieldErrors
      if (zodErrors?.email) toast.error(zodErrors.email[0])
    },
  })

  return (
    <form onSubmit={(e) => {
      e.preventDefault()
      createUser.mutate({ name: 'Example User', email: 'test@example.com' })
    }}>
      <button disabled={createUser.isPending}>
        {createUser.isPending ? 'Creating...' : 'Create User'}
      </button>
    </form>
  )
}

// Infinite query
function PostFeed() {
  const { data, fetchNextPage, hasNextPage, isFetchingNextPage } =
    trpc.posts.getInfinite.useInfiniteQuery(
      { limit: 20 },
      { getNextPageParam: (lastPage) => lastPage.nextCursor }
    )

  const posts = data?.pages.flatMap(p => p.posts) ?? []

  return (
    <div>
      {posts.map(p => <PostCard key={p.id} post={p} />)}
      <button onClick={() => fetchNextPage()} disabled={!hasNextPage}>
        Load more
      </button>
    </div>
  )
}
```

---

## Server-Side Caller (RSC / Server Actions)

```typescript
// For direct server-side usage without HTTP (RSC, Server Actions)
import { appRouter } from '@/server/root'
import { createCallerFactory } from '@trpc/server'
import { db } from '@/lib/db'
import { getServerSession } from 'next-auth'

const createCaller = createCallerFactory(appRouter)

// In a React Server Component
export default async function UsersPage() {
  const session = await getServerSession(authOptions)
  const caller = createCaller({ db, session, req: null as any })

  // Direct call — no HTTP overhead
  const users = await caller.users.getAll()

  return <UserList initialData={users} />
}
```

---

## Error Handling

```typescript
import { TRPCError } from '@trpc/server'

// Available error codes (map to HTTP status codes)
// NOT_FOUND → 404
// UNAUTHORIZED → 401
// FORBIDDEN → 403
// BAD_REQUEST → 400
// CONFLICT → 409
// INTERNAL_SERVER_ERROR → 500
// TOO_MANY_REQUESTS → 429
// PARSE_ERROR → 400

// Throwing errors in procedures
throw new TRPCError({
  code: 'NOT_FOUND',
  message: 'User not found',
  cause: originalError,  // wraps underlying error
})

// Catching on client
const mutation = trpc.users.create.useMutation({
  onError: (err) => {
    if (err.data?.code === 'CONFLICT') {
      setError('email', { message: 'Email already taken' })
    } else {
      toast.error(err.message)
    }
  },
})
```

---

## Batching

tRPC automatically batches multiple concurrent queries into a single HTTP request via `httpBatchLink`. No additional configuration needed — if your component mounts and calls 3 queries simultaneously, they go out as one POST.

```typescript
// These 3 queries will be batched into one HTTP request automatically:
function Dashboard() {
  const userQuery = trpc.users.getById.useQuery(userId)
  const postsQuery = trpc.posts.getInfinite.useQuery({ limit: 5 })
  const statsQuery = trpc.stats.getSummary.useQuery()
  // ...
}

// To disable batching for a specific client:
httpBatchLink({ url: '/api/trpc', maxURLLength: 2083 })
// Or use httpLink for no batching:
// import { httpLink } from '@trpc/client'
```

## Related Skills
- `graphql-expert` — alternative API layer
- `react-best-practices` — React + tRPC
- `server-actions-vs-api-optimizer` — API vs actions

## GitNexus Index
This skill is indexed by GitNexus for knowledge graph traversal.
Index path: /Users/localuser/.claude/skills/trpc-expert/.gitnexus
Last indexed: 2026-05-23
