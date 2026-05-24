---
name: react-query-tanstack
description: >
  TanStack Query v5 for server state management: queries, mutations, invalidation, optimistic updates, and infinite queries. Triggers on: useQuery, useMutation, QueryClient, invalidateQueries, TanStack Query, React Query, @tanstack/react-query.
---

# TanStack Query (React Query v5)

## When to Use

Use this skill for all server state — data that lives on a server and must be fetched, cached, synchronized, and updated. TanStack Query replaces manual `useState`/`useEffect` data fetching patterns entirely.

---

## Setup

```typescript
// lib/query-client.ts
import { QueryClient } from '@tanstack/react-query'

export const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 60 * 1000,       // 1 minute — data fresh without refetch
      gcTime: 5 * 60 * 1000,      // 5 minutes — cache retained after unmount
      retry: 2,
      refetchOnWindowFocus: true,
    },
  },
})

// app/providers.tsx  (Next.js App Router)
'use client'
import { QueryClientProvider } from '@tanstack/react-query'
import { ReactQueryDevtools } from '@tanstack/react-query-devtools'
import { useState } from 'react'
import { QueryClient } from '@tanstack/react-query'

export function Providers({ children }: { children: React.ReactNode }) {
  // useState ensures each request gets its own QueryClient in SSR
  const [queryClient] = useState(() => new QueryClient({
    defaultOptions: {
      queries: { staleTime: 60 * 1000 },
    },
  }))

  return (
    <QueryClientProvider client={queryClient}>
      {children}
      <ReactQueryDevtools initialIsOpen={false} />
    </QueryClientProvider>
  )
}

// app/layout.tsx
import { Providers } from './providers'

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html>
      <body>
        <Providers>{children}</Providers>
      </body>
    </html>
  )
}
```

---

## Query Key Conventions

```typescript
// keys.ts — centralize all query keys to avoid typos and enable targeted invalidation
export const queryKeys = {
  users: {
    all: ['users'] as const,
    lists: () => [...queryKeys.users.all, 'list'] as const,
    list: (filters: UserFilters) => [...queryKeys.users.lists(), filters] as const,
    details: () => [...queryKeys.users.all, 'detail'] as const,
    detail: (id: string) => [...queryKeys.users.details(), id] as const,
  },
  posts: {
    all: ['posts'] as const,
    byUser: (userId: string) => [...queryKeys.posts.all, 'byUser', userId] as const,
    detail: (slug: string) => [...queryKeys.posts.all, 'detail', slug] as const,
  },
} as const

// Usage in queries
useQuery({ queryKey: queryKeys.users.detail(userId), queryFn: ... })

// Targeted invalidation — invalidates all user queries
queryClient.invalidateQueries({ queryKey: queryKeys.users.all })

// Targeted invalidation — only user detail queries
queryClient.invalidateQueries({ queryKey: queryKeys.users.details() })
```

---

## `useQuery`

```typescript
import { useQuery } from '@tanstack/react-query'

// API function (plain async function — no TanStack imports needed here)
async function fetchUser(id: string): Promise<User> {
  const res = await fetch(`/api/users/${id}`)
  if (!res.ok) throw new Error('Failed to fetch user')
  return res.json()
}

// Component usage
function UserProfile({ userId }: { userId: string }) {
  const {
    data,          // User | undefined
    isLoading,     // true during first fetch (no cached data)
    isFetching,    // true during any fetch (incl. background refetch)
    isError,
    error,
    refetch,
    isSuccess,
  } = useQuery({
    queryKey: queryKeys.users.detail(userId),
    queryFn: () => fetchUser(userId),
    enabled: !!userId,               // only run when userId exists
    staleTime: 5 * 60 * 1000,       // override global: fresh for 5 min
    select: (data) => ({             // transform/select without extra state
      fullName: `${data.firstName} ${data.lastName}`,
      initials: data.firstName[0] + data.lastName[0],
    }),
    placeholderData: (prev) => prev, // keep previous data while refetching
  })

  if (isLoading) return <UserSkeleton />
  if (isError) return <ErrorBanner error={error} />
  return <div>{data?.fullName}</div>
}
```

---

## `useMutation` + Invalidation

```typescript
import { useMutation, useQueryClient } from '@tanstack/react-query'

async function updateUser(id: string, body: Partial<User>): Promise<User> {
  const res = await fetch(`/api/users/${id}`, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  })
  if (!res.ok) throw new Error('Update failed')
  return res.json()
}

function EditUserForm({ user }: { user: User }) {
  const queryClient = useQueryClient()

  const mutation = useMutation({
    mutationFn: (data: Partial<User>) => updateUser(user.id, data),

    // Invalidate after success — triggers background refetch
    onSuccess: (updatedUser) => {
      // Invalidate the list (may have changed)
      queryClient.invalidateQueries({ queryKey: queryKeys.users.lists() })
      // Update the specific user's cache directly (avoids extra network request)
      queryClient.setQueryData(queryKeys.users.detail(user.id), updatedUser)
    },

    onError: (error) => {
      toast.error(`Failed to update: ${error.message}`)
    },

    onSettled: () => {
      // Runs after both success and error
    },
  })

  return (
    <form onSubmit={(e) => {
      e.preventDefault()
      mutation.mutate({ name: 'New Name' })
    }}>
      <button
        type="submit"
        disabled={mutation.isPending}
      >
        {mutation.isPending ? 'Saving...' : 'Save'}
      </button>
      {mutation.isError && <p>{mutation.error.message}</p>}
    </form>
  )
}
```

---

## Optimistic Updates

```typescript
function TodoList() {
  const queryClient = useQueryClient()

  const toggleTodo = useMutation({
    mutationFn: (todo: Todo) =>
      fetch(`/api/todos/${todo.id}`, {
        method: 'PATCH',
        body: JSON.stringify({ completed: !todo.completed }),
      }).then(r => r.json()),

    // 1. Snapshot old data and apply optimistic update
    onMutate: async (todo) => {
      // Cancel any outgoing refetches to avoid race conditions
      await queryClient.cancelQueries({ queryKey: queryKeys.todos.all })

      // Snapshot the previous value for rollback
      const previous = queryClient.getQueryData<Todo[]>(queryKeys.todos.all)

      // Optimistically update the cache
      queryClient.setQueryData<Todo[]>(queryKeys.todos.all, (old = []) =>
        old.map(t => t.id === todo.id ? { ...t, completed: !t.completed } : t)
      )

      return { previous }  // returned context passed to onError
    },

    // 2. Roll back on error
    onError: (_err, _todo, context) => {
      if (context?.previous) {
        queryClient.setQueryData(queryKeys.todos.all, context.previous)
      }
      toast.error('Failed to update todo')
    },

    // 3. Sync with server response (always refetch to confirm)
    onSettled: () => {
      queryClient.invalidateQueries({ queryKey: queryKeys.todos.all })
    },
  })

  return (/* ... */)
}
```

---

## Infinite Queries

```typescript
import { useInfiniteQuery } from '@tanstack/react-query'

interface PostsPage {
  posts: Post[]
  nextCursor: string | null
  total: number
}

async function fetchPosts({ pageParam }: { pageParam: string | null }): Promise<PostsPage> {
  const params = new URLSearchParams({ limit: '20' })
  if (pageParam) params.set('cursor', pageParam)
  const res = await fetch(`/api/posts?${params}`)
  return res.json()
}

function PostFeed() {
  const {
    data,
    fetchNextPage,
    hasNextPage,
    isFetchingNextPage,
    isLoading,
  } = useInfiniteQuery({
    queryKey: queryKeys.posts.all,
    queryFn: fetchPosts,
    initialPageParam: null as string | null,
    getNextPageParam: (lastPage) => lastPage.nextCursor,  // null stops fetching
    getPreviousPageParam: (firstPage) => firstPage.nextCursor,
  })

  // data.pages is an array of PostsPage
  const posts = data?.pages.flatMap(page => page.posts) ?? []

  return (
    <div>
      {posts.map(post => <PostCard key={post.id} post={post} />)}

      <button
        onClick={() => fetchNextPage()}
        disabled={!hasNextPage || isFetchingNextPage}
      >
        {isFetchingNextPage ? 'Loading more...' : hasNextPage ? 'Load more' : 'No more posts'}
      </button>

      {isLoading && <Skeleton />}
    </div>
  )
}
```

---

## Prefetching

```typescript
// Server-side prefetch in Next.js App Router (RSC)
// app/users/page.tsx
import { dehydrate, HydrationBoundary, QueryClient } from '@tanstack/react-query'

export default async function UsersPage() {
  const queryClient = new QueryClient()

  // Prefetch on the server — data available immediately on client
  await queryClient.prefetchQuery({
    queryKey: queryKeys.users.lists(),
    queryFn: () => fetchUsers(),
  })

  return (
    <HydrationBoundary state={dehydrate(queryClient)}>
      <UserList />  {/* useQuery here will find prefetched data */}
    </HydrationBoundary>
  )
}

// Client-side prefetch on hover
function UserLink({ userId }: { userId: string }) {
  const queryClient = useQueryClient()

  return (
    <Link
      href={`/users/${userId}`}
      onMouseEnter={() => {
        // Prefetch before navigation — data ready when page loads
        queryClient.prefetchQuery({
          queryKey: queryKeys.users.detail(userId),
          queryFn: () => fetchUser(userId),
          staleTime: 10_000,  // don't refetch if already cached for < 10s
        })
      }}
    >
      View Profile
    </Link>
  )
}
```

---

## Suspense Integration

```typescript
// Enable Suspense mode — query throws a Promise until data is ready
function UserCard({ userId }: { userId: string }) {
  const { data } = useSuspenseQuery({
    queryKey: queryKeys.users.detail(userId),
    queryFn: () => fetchUser(userId),
  })
  // data is always User here — no undefined check needed
  return <div>{data.name}</div>
}

// Wrap with Suspense + ErrorBoundary
function UserPage({ userId }: { userId: string }) {
  return (
    <ErrorBoundary fallback={<ErrorMessage />}>
      <Suspense fallback={<UserSkeleton />}>
        <UserCard userId={userId} />
      </Suspense>
    </ErrorBoundary>
  )
}

// Parallel Suspense queries
function Dashboard() {
  return (
    <Suspense fallback={<DashboardSkeleton />}>
      <UserStats />    {/* useSuspenseQuery for stats */}
      <RecentPosts />  {/* useSuspenseQuery for posts — fetched in parallel */}
    </Suspense>
  )
}
```

---

## staleTime vs gcTime

```typescript
// staleTime: how long data is considered "fresh" — no refetch during this window
// gcTime (formerly cacheTime): how long INACTIVE cached data is retained

// Rarely changing data: long staleTime
useQuery({
  queryKey: ['config'],
  queryFn: fetchConfig,
  staleTime: Infinity,      // never refetch automatically
})

// Real-time data: short staleTime + frequent refetch
useQuery({
  queryKey: ['notifications'],
  queryFn: fetchNotifications,
  staleTime: 0,             // always consider stale (refetch on focus/reconnect)
  refetchInterval: 30_000,  // poll every 30 seconds
})

// User profile: medium cache, long retention
useQuery({
  queryKey: queryKeys.users.detail(userId),
  queryFn: () => fetchUser(userId),
  staleTime: 5 * 60_000,   // fresh for 5 minutes
  gcTime: 30 * 60_000,     // keep in cache 30 minutes after unmount
})
```

---

## Devtools Setup

```bash
npm install @tanstack/react-query-devtools
```

```typescript
// Add to providers.tsx (already shown above)
import { ReactQueryDevtools } from '@tanstack/react-query-devtools'

// Inside QueryClientProvider:
<ReactQueryDevtools
  initialIsOpen={false}
  buttonPosition="bottom-right"
/>

// Only include in development
{process.env.NODE_ENV === 'development' && (
  <ReactQueryDevtools initialIsOpen={false} />
)}
```

## Related Skills
- `react-best-practices` — React patterns
- `react-server-components` — RSC data patterns
- `revalidation-strategy-planner` — cache revalidation

## GitNexus Index
This skill is indexed by GitNexus for knowledge graph traversal.
Index path: /Users/localuser/.claude/skills/react-query-tanstack/.gitnexus
Last indexed: 2026-05-23
