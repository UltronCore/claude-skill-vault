---
name: sveltekit
version: 1.0.0
description: Svelte full-stack framework with file-based routing and SSR
tools: [Read, Edit, Write, Bash]
tags: [frontend, web, framework, svelte, sveltekit, ssr, fullstack]
author: claude-skill-vault
created: 2026-05-24
---

# SvelteKit — Svelte Full-Stack Framework

## Overview
SvelteKit is the official full-stack framework for Svelte. It provides file-based routing, server-side rendering (SSR), static site generation (SSG), API routes, form actions, and adapter-based deployment. Svelte compiles components to vanilla JS with no virtual DOM, making it extremely performant.

## When to Use
- Full-stack web apps with a Svelte UI preference
- Replacing Next.js/Nuxt when bundle size and runtime overhead matter
- Progressive enhancement workflows (forms that work without JS)
- Projects needing flexible rendering per-page (SSR, SSG, CSR mixed)
- Rapid prototyping with minimal boilerplate

## Installation / Setup

```bash
npm create svelte@latest my-app
cd my-app
npm install
npm run dev

# Add adapters for deployment
npm install -D @sveltejs/adapter-vercel
npm install -D @sveltejs/adapter-node
npm install -D @sveltejs/adapter-static
```

### svelte.config.js
```js
import adapter from '@sveltejs/adapter-vercel';
import { vitePreprocess } from '@sveltejs/vite-plugin-svelte';

/** @type {import('@sveltejs/kit').Config} */
const config = {
  preprocess: vitePreprocess(),
  kit: {
    adapter: adapter(),
    alias: {
      $components: 'src/components',
      $lib: 'src/lib',
    },
  },
};

export default config;
```

## Key Patterns

### File-Based Routing
```
src/routes/
  +page.svelte            → /
  +layout.svelte          → Root layout (wraps all pages)
  +error.svelte           → Error page
  about/
    +page.svelte          → /about
    +page.server.ts       → Server-only load for /about
  blog/
    +layout.svelte        → Nested layout
    [slug]/
      +page.svelte        → /blog/:slug
      +page.server.ts     → Load fn for slug
  api/
    users/
      +server.ts          → REST API route
```

### Load Functions (Data Fetching)
```ts
// src/routes/blog/[slug]/+page.server.ts
import type { PageServerLoad } from './$types';
import { error } from '@sveltejs/kit';

export const load: PageServerLoad = async ({ params, fetch, cookies }) => {
  const post = await fetch(`/api/posts/${params.slug}`).then(r => r.json());

  if (!post) {
    throw error(404, 'Post not found');
  }

  return { post };
};
```

```svelte
<!-- src/routes/blog/[slug]/+page.svelte -->
<script lang="ts">
  import type { PageData } from './$types';

  export let data: PageData;
  // data.post is fully typed from load()
</script>

<article>
  <h1>{data.post.title}</h1>
  <p>{data.post.body}</p>
</article>
```

### Form Actions (Progressive Enhancement)
```ts
// src/routes/contact/+page.server.ts
import type { Actions } from './$types';
import { fail, redirect } from '@sveltejs/kit';

export const actions: Actions = {
  default: async ({ request }) => {
    const data = await request.formData();
    const email = data.get('email') as string;

    if (!email?.includes('@')) {
      return fail(400, { email, error: 'Invalid email' });
    }

    await sendEmail(email);
    throw redirect(303, '/thanks');
  },
};
```

```svelte
<!-- src/routes/contact/+page.svelte -->
<script lang="ts">
  import { enhance } from '$app/forms';
  import type { ActionData } from './$types';
  export let form: ActionData;
</script>

<form method="POST" use:enhance>
  <input name="email" type="email" value={form?.email ?? ''} />
  {#if form?.error}<p class="error">{form.error}</p>{/if}
  <button type="submit">Subscribe</button>
</form>
```

### API Routes
```ts
// src/routes/api/users/+server.ts
import { json, error } from '@sveltejs/kit';
import type { RequestHandler } from './$types';

export const GET: RequestHandler = async ({ url }) => {
  const limit = Number(url.searchParams.get('limit') ?? 10);
  const users = await db.users.findMany({ take: limit });
  return json(users);
};

export const POST: RequestHandler = async ({ request }) => {
  const body = await request.json();
  const user = await db.users.create({ data: body });
  return json(user, { status: 201 });
};
```

### Svelte Stores (Shared State)
```ts
// src/lib/stores/cart.ts
import { writable, derived } from 'svelte/store';

interface CartItem { id: string; qty: number; price: number; }

function createCart() {
  const { subscribe, update } = writable<CartItem[]>([]);

  return {
    subscribe,
    add: (item: CartItem) => update(items => {
      const existing = items.find(i => i.id === item.id);
      return existing
        ? items.map(i => i.id === item.id ? { ...i, qty: i.qty + 1 } : i)
        : [...items, item];
    }),
    remove: (id: string) => update(items => items.filter(i => i.id !== id)),
  };
}

export const cart = createCart();
export const cartTotal = derived(cart, $cart =>
  $cart.reduce((sum, i) => sum + i.price * i.qty, 0)
);
```

### Hooks (Middleware)
```ts
// src/hooks.server.ts
import type { Handle } from '@sveltejs/kit';

export const handle: Handle = async ({ event, resolve }) => {
  // Auth check
  const session = event.cookies.get('session');
  event.locals.user = session ? await validateSession(session) : null;

  const response = await resolve(event, {
    transformPageChunk: ({ html }) => html.replace('%lang%', 'en'),
  });

  response.headers.set('X-Frame-Options', 'SAMEORIGIN');
  return response;
};
```

## Common Pitfalls
- **`+page.server.ts` vs `+page.ts`**: server files never run on client; universal load files run both sides
- **Reactivity requires assignment**: `array.push()` does not trigger updates — use `array = [...array, item]`
- **`$app/stores` deprecation**: prefer `$app/state` (page, navigating) in Svelte 5 runes mode
- **Form action redirects**: use 303, not 302, to avoid POST-on-refresh issues
- **Adapter must match deployment**: using `adapter-static` with server-only load functions will fail at build

## Related Skills
- `tailwind-shadcn-ui-setup` — common Svelte UI pairing
- `drizzle-orm` — DB layer for SvelteKit backends
- `vercel-deploy` — hosting SvelteKit apps
- `prisma-patterns` — alternative ORM

## GitNexus Index
```
domain: frontend/web
tier: framework
runtime: node
language: svelte,ts
bundler: vite
renders: ssr,ssg,csr
```
