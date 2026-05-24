---
name: nuxt3
version: 1.0.0
description: Vue full-stack framework with auto-imports, SSR, and Nitro server
tools: [Read, Edit, Write, Bash]
tags: [frontend, web, vue, nuxt, ssr, fullstack, nitro]
author: claude-skill-vault
created: 2026-05-24
---

# Nuxt 3 — Vue Full-Stack Framework

## Overview
Nuxt 3 is the Vue ecosystem's full-stack framework. It brings auto-imports (no manual imports needed for composables and components), file-based routing, server-side rendering via the Nitro server engine, and a powerful module ecosystem. Nuxt runs on any deployment target: Vercel, Netlify, Node, edge workers, or static files.

## When to Use
- Vue.js projects requiring SSR, SSG, or ISR
- Teams migrating from Nuxt 2 or Nuxt.js legacy apps
- Full-stack Vue apps needing API routes alongside the UI
- CMS-backed sites (Nuxt Content module)
- When auto-imports and DX velocity matter

## Installation / Setup

```bash
npx nuxi@latest init my-app
cd my-app && npm install && npm run dev

# Add modules
npx nuxi module add tailwindcss
npx nuxi module add @nuxtjs/supabase
npx nuxi module add @nuxt/content
npx nuxi module add @pinia/nuxt
```

### nuxt.config.ts
```ts
export default defineNuxtConfig({
  devtools: { enabled: true },
  modules: ['@nuxtjs/tailwindcss', '@pinia/nuxt', '@nuxt/content'],
  runtimeConfig: {
    // Server-only
    dbUrl: process.env.DATABASE_URL,
    // Exposed to client (prefix: public)
    public: {
      apiBase: process.env.API_BASE ?? '/api',
    },
  },
  nitro: {
    preset: 'vercel-edge', // or 'node-server', 'cloudflare-pages'
  },
});
```

## Key Patterns

### Auto-Imports (Zero Boilerplate)
```vue
<!-- Composables, components, Vue APIs are auto-imported -->
<script setup lang="ts">
// No imports needed for: ref, computed, useFetch, useRoute, useRuntimeConfig, etc.
const route = useRoute();
const config = useRuntimeConfig();

const { data: post, error } = await useFetch(`/api/posts/${route.params.slug}`);
</script>

<template>
  <div>
    <h1>{{ post?.title }}</h1>
  </div>
</template>
```

### Data Fetching Composables
```vue
<script setup lang="ts">
// useFetch — SSR-aware, cached, deduped
const { data: users, pending, refresh } = await useFetch('/api/users', {
  lazy: true, // Don't block navigation
  watch: [route.query], // Re-fetch when query changes
});

// useAsyncData — for custom async functions
const { data: stats } = await useAsyncData('stats', () =>
  $fetch('/api/stats', { method: 'POST', body: { period: '7d' } })
);

// $fetch — for client-side requests (no SSR dedup)
const submit = async (form: FormData) => {
  const result = await $fetch('/api/submit', { method: 'POST', body: form });
};
</script>
```

### Server API Routes (Nitro)
```ts
// server/api/users/index.get.ts
import { z } from 'zod';

const querySchema = z.object({ limit: z.coerce.number().default(10) });

export default defineEventHandler(async (event) => {
  const { limit } = await getValidatedQuery(event, querySchema.parse);
  return db.users.findMany({ take: limit });
});

// server/api/users/[id].delete.ts
export default defineEventHandler(async (event) => {
  const id = getRouterParam(event, 'id');
  await requireAuth(event); // custom utility
  await db.users.delete({ where: { id } });
  return { success: true };
});
```

### Middleware
```ts
// middleware/auth.ts (client-side route guard)
export default defineNuxtRouteMiddleware((to) => {
  const user = useSupabaseUser();
  if (!user.value && to.path !== '/login') {
    return navigateTo('/login');
  }
});

// server/middleware/cors.ts (server-side)
export default defineEventHandler((event) => {
  setResponseHeaders(event, {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  });
});
```

### Pinia Store (Auto-Imported)
```ts
// stores/cart.ts
export const useCartStore = defineStore('cart', () => {
  const items = ref<CartItem[]>([]);
  const total = computed(() =>
    items.value.reduce((sum, i) => sum + i.price * i.qty, 0)
  );

  function add(item: CartItem) {
    const existing = items.value.find(i => i.id === item.id);
    existing ? existing.qty++ : items.value.push({ ...item, qty: 1 });
  }

  return { items, total, add };
});

// In any component — auto-imported, no manual import
const cart = useCartStore();
```

### Nuxt Content (MDX CMS)
```vue
<script setup lang="ts">
const { data: doc } = await useAsyncData(route.path, () =>
  queryContent(route.path).findOne()
);
</script>

<template>
  <ContentDoc />
</template>
```

## Common Pitfalls
- **`useFetch` runs twice**: once on server, once on client — use `server: false` for client-only, or ensure idempotent calls
- **Auto-import conflicts**: custom composables in `composables/` are auto-imported — avoid naming them `use` prefix unless intentional
- **`runtimeConfig` vs `appConfig`**: runtimeConfig is for secrets and env-driven values; appConfig is for static app-level config
- **Nitro preset must match deployment**: `vercel-edge` fails on a Node server; mismatches cause runtime errors
- **SSR hydration mismatch**: server-rendered HTML must match first client render — avoid `Date.now()` or `Math.random()` in templates

## Related Skills
- `prisma-patterns` — DB layer for Nuxt server routes
- `tailwind-shadcn-ui-setup` — UI styling
- `vercel-deploy` — deploying Nuxt 3
- `zustand` — client state alternative when not using Pinia

## GitNexus Index
```
domain: frontend/web
tier: framework
runtime: node,edge
language: vue,ts
bundler: vite
server: nitro
```
