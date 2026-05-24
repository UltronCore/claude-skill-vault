---
name: astro
version: 1.0.0
description: Island architecture web framework for content-focused sites
tools: [Read, Edit, Write, Bash]
tags: [frontend, web, framework, astro, islands, performance]
author: claude-skill-vault
created: 2026-05-24
---

# Astro — Island Architecture Web Framework

## Overview
Astro is a web framework optimized for content-focused sites. It ships zero JS by default and uses "island architecture" — only interactive UI components hydrate in the browser. Supports React, Vue, Svelte, Solid, and other UI frameworks simultaneously in the same project.

## When to Use
- Marketing sites, blogs, docs, portfolios, e-commerce storefronts
- Projects where most content is static with isolated interactive widgets
- When Lighthouse scores and Core Web Vitals are critical
- Migrating from Gatsby, Next.js, or Hugo and wanting less JS overhead
- Teams that want to mix UI frameworks without friction

## Installation / Setup

```bash
# Create new project
npm create astro@latest my-site

# Add integrations
npx astro add react
npx astro add tailwind
npx astro add mdx
npx astro add sitemap

# Dev server
npm run dev
```

### astro.config.mjs
```js
import { defineConfig } from 'astro/config';
import react from '@astrojs/react';
import tailwind from '@astrojs/tailwind';
import sitemap from '@astrojs/sitemap';

export default defineConfig({
  site: 'https://example.com',
  integrations: [react(), tailwind(), sitemap()],
  output: 'static', // or 'server' for SSR, 'hybrid'
  image: {
    service: { entrypoint: 'astro/assets/services/sharp' },
  },
});
```

## Key Patterns

### .astro Component Syntax
```astro
---
// Frontmatter: runs at build time (Node.js environment)
import Layout from '../layouts/Layout.astro';
import Card from '../components/Card.astro';

interface Props {
  title: string;
}

const { title } = Astro.props;
const posts = await fetch('https://api.example.com/posts').then(r => r.json());
---

<Layout title={title}>
  <main>
    <h1>{title}</h1>
    {posts.map(post => <Card post={post} />)}
  </main>
</Layout>

<style>
  /* Scoped by default */
  h1 { color: navy; }
</style>
```

### Island Hydration Directives
```astro
---
import Counter from '../components/Counter.tsx'; // React component
import Map from '../components/Map.svelte';       // Svelte component
---

<!-- Only hydrate when visible in viewport -->
<Counter client:visible initialCount={0} />

<!-- Hydrate on page load -->
<Map client:load center={[38.6, -90.2]} />

<!-- Hydrate when browser is idle -->
<HeavyWidget client:idle />

<!-- Hydrate only on specific media query -->
<MobileMenu client:media="(max-width: 768px)" />

<!-- Never hydrate (static HTML only) -->
<StaticChart />
```

### File-Based Routing
```
src/pages/
  index.astro           → /
  about.astro           → /about
  blog/
    index.astro         → /blog
    [slug].astro        → /blog/:slug
  api/
    contact.ts          → /api/contact (API route)
```

### Dynamic Routes with getStaticPaths
```astro
---
// src/pages/blog/[slug].astro
export async function getStaticPaths() {
  const posts = await getCollection('blog');
  return posts.map(post => ({
    params: { slug: post.slug },
    props: { post },
  }));
}

const { post } = Astro.props;
---
<article>
  <h1>{post.data.title}</h1>
  <post.Content />
</article>
```

### Content Collections (Type-Safe MDX)
```ts
// src/content/config.ts
import { defineCollection, z } from 'astro:content';

const blog = defineCollection({
  type: 'content',
  schema: z.object({
    title: z.string(),
    pubDate: z.date(),
    tags: z.array(z.string()).optional(),
    image: z.object({ url: z.string(), alt: z.string() }).optional(),
  }),
});

export const collections = { blog };
```

### SSR / API Routes
```ts
// src/pages/api/newsletter.ts
import type { APIRoute } from 'astro';

export const POST: APIRoute = async ({ request }) => {
  const data = await request.json();
  // handle subscription...
  return new Response(JSON.stringify({ success: true }), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  });
};
```

### Image Optimization
```astro
---
import { Image } from 'astro:assets';
import heroImg from '../assets/hero.jpg';
---

<Image src={heroImg} alt="Hero" width={800} height={400} format="webp" />
```

## Common Pitfalls
- **Frontmatter runs at build time**: no `window`, `document`, or browser APIs in `---` blocks
- **client: directive required for interactivity**: forgetting it renders React/Svelte as static HTML only
- **Shared state between islands**: use nanostores or a URL-based approach, not component state
- **SSR output mode required for**: form handling, auth cookies, real-time data — default is `static`
- **MDX and .astro are different**: MDX is for content authors; .astro is for layout/component authors

## Related Skills
- `react-best-practices` — when React islands are used
- `tailwind-shadcn-ui-setup` — Tailwind integration
- `core-web-vitals` — measuring Astro's performance gains
- `vercel-deploy` — deploying Astro SSR

## GitNexus Index
```
domain: frontend/web
tier: framework
runtime: node
language: astro,tsx,ts
bundler: vite
outputs: static,ssr,hybrid
```
