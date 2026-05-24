---
name: remix
version: 1.0.0
description: Full-stack React framework built on web standards — loaders, actions, nested routes
tools: [Read, Edit, Write, Bash]
tags: [frontend, web, react, remix, ssr, fullstack, web-standards]
author: claude-skill-vault
created: 2026-05-24
---

# Remix — Full-Stack React Framework

## Overview
Remix is a full-stack React framework that embraces web platform fundamentals: HTTP, forms, the fetch API. It uses nested routes where each route owns its data loading and mutations. Every form submission is a progressive enhancement — Remix handles data flow without client-side JavaScript if needed. Runs on any JS runtime: Node, Deno, Cloudflare Workers, Bun.

## When to Use
- Full-stack React apps where progressive enhancement matters
- Apps with complex nested layouts each needing independent data
- Replacing Create React App or Vite SPAs with SSR
- High-traffic pages where streaming and concurrent rendering help
- APIs that rely on standard web Request/Response

## Installation / Setup

```bash
npx create-remix@latest my-app
cd my-app && npm install && npm run dev

# With a stack template
npx create-remix@latest --template remix-run/indie-stack
npx create-remix@latest --template remix-run/blues-stack
```

### vite.config.ts (Remix 2.x uses Vite)
```ts
import { vitePlugin as remix } from '@remix-run/dev';
import { defineConfig } from 'vite';
import tsconfigPaths from 'vite-tsconfig-paths';

export default defineConfig({
  plugins: [remix({ future: { v3_singleFetch: true } }), tsconfigPaths()],
});
```

## Key Patterns

### Loader (Server-Side Data)
```tsx
// app/routes/posts.$slug.tsx
import { json, type LoaderFunctionArgs } from '@remix-run/node';
import { useLoaderData } from '@remix-run/react';

export async function loader({ params, request }: LoaderFunctionArgs) {
  const post = await db.post.findUnique({ where: { slug: params.slug } });
  if (!post) throw new Response('Not Found', { status: 404 });
  return json({ post });
}

export default function PostPage() {
  const { post } = useLoaderData<typeof loader>();
  return <article><h1>{post.title}</h1><p>{post.body}</p></article>;
}
```

### Action (Form Mutations)
```tsx
// app/routes/contact.tsx
import { json, redirect, type ActionFunctionArgs } from '@remix-run/node';
import { Form, useActionData } from '@remix-run/react';

export async function action({ request }: ActionFunctionArgs) {
  const formData = await request.formData();
  const email = String(formData.get('email'));

  if (!email.includes('@')) {
    return json({ errors: { email: 'Invalid email' } }, { status: 400 });
  }

  await sendEmail(email);
  return redirect('/thanks');
}

export default function Contact() {
  const actionData = useActionData<typeof action>();
  return (
    <Form method="post">
      <input name="email" type="email" />
      {actionData?.errors?.email && <p>{actionData.errors.email}</p>}
      <button type="submit">Send</button>
    </Form>
  );
}
```

### Nested Routes & Layouts
```
app/routes/
  _layout.tsx               → Root layout (Outlet)
  _layout._index.tsx        → /
  _layout.dashboard.tsx     → /dashboard (nested layout)
  _layout.dashboard._index.tsx  → /dashboard
  _layout.dashboard.stats.tsx   → /dashboard/stats
  posts.$slug.tsx           → /posts/:slug
```

```tsx
// _layout.dashboard.tsx — owns its own loader
export async function loader({ request }: LoaderFunctionArgs) {
  const user = await requireAuth(request);
  return json({ user });
}

export default function DashboardLayout() {
  const { user } = useLoaderData<typeof loader>();
  return (
    <div>
      <nav>Hello, {user.name}</nav>
      <Outlet /> {/* child routes render here */}
    </div>
  );
}
```

### Streaming with defer
```tsx
import { defer } from '@remix-run/node';
import { Await, useLoaderData } from '@remix-run/react';
import { Suspense } from 'react';

export async function loader() {
  // Critical data — awaited (blocks navigation)
  const user = await getUser();
  // Slow data — deferred (streamed)
  const statsPromise = getHeavyStats();
  return defer({ user, statsPromise });
}

export default function Page() {
  const { user, statsPromise } = useLoaderData<typeof loader>();
  return (
    <div>
      <p>{user.name}</p>
      <Suspense fallback={<p>Loading stats...</p>}>
        <Await resolve={statsPromise}>
          {stats => <StatsChart data={stats} />}
        </Await>
      </Suspense>
    </div>
  );
}
```

### useFetcher (Non-Navigation Data)
```tsx
import { useFetcher } from '@remix-run/react';

function LikeButton({ postId }: { postId: string }) {
  const fetcher = useFetcher();
  const liked = fetcher.formData
    ? fetcher.formData.get('action') === 'like'
    : false;

  return (
    <fetcher.Form method="post" action="/api/like">
      <input type="hidden" name="postId" value={postId} />
      <button name="action" value={liked ? 'unlike' : 'like'}>
        {liked ? 'Unlike' : 'Like'}
      </button>
    </fetcher.Form>
  );
}
```

### Error Boundaries
```tsx
export function ErrorBoundary() {
  const error = useRouteError();
  if (isRouteErrorResponse(error)) {
    return <h1>{error.status} — {error.data}</h1>;
  }
  return <h1>Unexpected error: {String(error)}</h1>;
}
```

## Common Pitfalls
- **Loaders run on every navigation**: cache aggressively; avoid expensive queries without caching
- **FormData values are strings**: always cast `String(formData.get('field'))` — `get()` returns `FormDataEntryValue | null`
- **Parallel data loading per route segment**: sibling routes load in parallel; nested routes load sequentially with parent
- **`defer` requires streaming support**: static hosting (no Node server) cannot stream — check deployment target
- **`useLoaderData` type safety**: use `useLoaderData<typeof loader>()` not raw `useLoaderData()` for full TypeScript inference

## Related Skills
- `react-best-practices` — React patterns used inside Remix
- `prisma-patterns` — DB for Remix loaders
- `drizzle-orm` — lightweight alternative
- `zod-expert` — form validation in actions
- `tanstack-form` — enhanced form handling

## GitNexus Index
```
domain: frontend/web
tier: framework
runtime: node,edge,deno,bun
language: tsx,ts
bundler: vite
renders: ssr,streaming
```
