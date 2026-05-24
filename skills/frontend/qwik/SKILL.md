---
name: qwik
version: 1.0.0
description: Resumability framework — instant loading with zero hydration cost
tools: [Read, Edit, Write, Bash]
tags: [frontend, web, qwik, resumability, performance, ssr]
author: claude-skill-vault
created: 2026-05-24
---

# Qwik — Resumability Framework

## Overview
Qwik achieves instant page load by replacing hydration with resumability. The server serializes application state into HTML; the browser resumes exactly where the server left off with zero replay of component code. JavaScript is lazy-loaded only when user interactions actually require it. QwikCity is its meta-framework with file-based routing.

## When to Use
- E-commerce, marketing, and content sites where Time-to-Interactive is critical
- Replacing SSR React apps with massive hydration cost
- Apps targeting poor network/device conditions
- When Google PageSpeed scores are a business requirement

## Installation / Setup

```bash
npm create qwik@latest
cd my-app && npm install && npm run dev

# Add integrations
npm run qwik add
# → choose: Tailwind, Prisma, Supabase, Clerk, etc.
```

## Key Patterns

### Components with $ (Lazy Boundaries)
```tsx
import { component$, useSignal, $ } from '@builder.io/qwik';

// component$ creates a lazy boundary — code only downloads on interaction
export const Counter = component$(() => {
  const count = useSignal(0);

  // $() marks handler as lazy — not downloaded until clicked
  const increment = $(() => {
    count.value++;
  });

  return (
    <div>
      <p>Count: {count.value}</p>
      <button onClick$={increment}>Increment</button>
    </div>
  );
});
```

### useStore (Reactive State)
```tsx
import { component$, useStore } from '@builder.io/qwik';

interface AppState {
  user: { name: string; email: string } | null;
  loading: boolean;
}

export const App = component$(() => {
  const state = useStore<AppState>({ user: null, loading: false });

  return (
    <div>
      {state.loading ? <p>Loading...</p> : <p>Hello {state.user?.name}</p>}
    </div>
  );
});
```

### Resource (Server + Client Data)
```tsx
import { component$, useResource$, Resource } from '@builder.io/qwik';

export const UserList = component$(() => {
  const users = useResource$<User[]>(async ({ cleanup }) => {
    const controller = new AbortController();
    cleanup(() => controller.abort());

    const res = await fetch('/api/users', { signal: controller.signal });
    return res.json();
  });

  return (
    <Resource
      value={users}
      onPending={() => <p>Loading...</p>}
      onRejected={err => <p>Error: {err.message}</p>}
      onResolved={users => (
        <ul>
          {users.map(u => <li key={u.id}>{u.name}</li>)}
        </ul>
      )}
    />
  );
});
```

### QwikCity Routing & Loaders
```tsx
// src/routes/blog/[slug]/index.tsx
import { component$ } from '@builder.io/qwik';
import { routeLoader$, type DocumentHead } from '@builder.io/qwik-city';

export const usePost = routeLoader$(async ({ params, status }) => {
  const post = await db.posts.findUnique({ where: { slug: params.slug } });
  if (!post) { status(404); return null; }
  return post;
});

export default component$(() => {
  const post = usePost();
  return (
    <article>
      <h1>{post.value?.title}</h1>
      <p>{post.value?.body}</p>
    </article>
  );
});

export const head: DocumentHead = ({ resolveValue }) => {
  const post = resolveValue(usePost);
  return { title: post?.title ?? 'Not Found' };
};
```

### Route Actions (Forms)
```tsx
import { component$ } from '@builder.io/qwik';
import { routeAction$, Form, zod$, z } from '@builder.io/qwik-city';

export const useSignup = routeAction$(
  async (data, { redirect }) => {
    await createUser(data);
    throw redirect(303, '/dashboard');
  },
  zod$({ email: z.string().email(), password: z.string().min(8) })
);

export default component$(() => {
  const signup = useSignup();

  return (
    <Form action={signup}>
      <input name="email" type="email" />
      <input name="password" type="password" />
      {signup.value?.failed && <p>{signup.value.fieldErrors?.email}</p>}
      <button type="submit">Sign Up</button>
    </Form>
  );
});
```

### Context (Shared State)
```tsx
import { createContextId, useContext, useContextProvider } from '@builder.io/qwik';

export const ThemeContext = createContextId<{ dark: boolean }>('theme');

export const ThemeProvider = component$(() => {
  const theme = useStore({ dark: false });
  useContextProvider(ThemeContext, theme);
  return <Slot />;
});

export const ThemedButton = component$(() => {
  const theme = useContext(ThemeContext);
  return <button class={theme.dark ? 'bg-black text-white' : ''}>Click</button>;
});
```

## Common Pitfalls
- **`$` suffix is required**: `onClick$`, `useTask$`, `component$` — the dollar sign marks serialization boundaries
- **Closures must be serializable**: captured variables in `$()` must be JSON-serializable; DOM elements and class instances cannot cross boundaries
- **`useVisibleTask$` vs `useTask$`**: `useTask$` runs on server+client; `useVisibleTask$` runs only in browser when visible
- **No direct DOM manipulation**: use signals/stores; direct `document.getElementById` breaks resumability
- **Relative imports inside `$`**: bundler requires static import analysis — dynamic imports break lazy boundaries

## Related Skills
- `vite-plugin-dev` — QwikCity uses Vite
- `tailwind-shadcn-ui-setup` — Tailwind integrates cleanly
- `zod-expert` — used for form validation in routeAction$

## GitNexus Index
```
domain: frontend/web
tier: framework
runtime: node,edge
language: tsx,ts
bundler: vite
renders: resumable-ssr
```
