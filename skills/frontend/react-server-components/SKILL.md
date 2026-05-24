---
name: react-server-components
description: Build with React Server Components (RSC) in Next.js App Router. Covers data fetching, streaming, server actions, client/server boundaries, caching strategies, and performance patterns.
version: 1.0.0
tags: [react, server-components, nextjs, app-router, streaming, server-actions, RSC]
---

# React Server Components

## Overview

This skill covers building production applications with React Server Components in the Next.js App Router. It explains the server/client boundary model, streaming with Suspense, server actions for mutations, caching and revalidation strategies, and common patterns for mixing server and client components effectively. RSC fundamentally changes how data flows through React applications.

## When to Use

- Building new Next.js 13+ projects with the App Router
- Migrating pages from Next.js Pages Router to App Router
- Optimizing initial page load by reducing client JavaScript
- Implementing streaming for large data-fetching pages
- Replacing API routes with server actions for form mutations

## Step-by-Step Workflow

### 1. Server vs Client Component Decision
```
Default: Server Component (no "use client" directive)

Use SERVER components for:
✓ Data fetching (async/await directly in component)
✓ Accessing backend resources (DB, filesystem, secrets)
✓ Large dependencies (markdown parsers, date libraries)
✓ Static content that doesn't need interactivity

Use CLIENT components for:
✓ useState, useEffect, event handlers
✓ Browser APIs (localStorage, geolocation, IntersectionObserver)
✓ UI libraries with their own state (charts, editors)
✓ Anything that needs to "react" to user input
```

### 2. Server Component Data Fetching
```tsx
// app/products/page.tsx — Server Component (default)
// No 'use client' → runs only on server → secrets safe, no JS sent to client

interface Product {
  id: string;
  name: string;
  price: number;
}

// Direct async/await — no useEffect, no useState, no loading state boilerplate
async function getProducts(): Promise<Product[]> {
  // Can access DB directly — never exposed to client
  const res = await fetch('https://api.example.com/products', {
    // Next.js extends fetch with caching
    next: { revalidate: 60 }, // Cache for 60 seconds (ISR)
    // Or: cache: 'no-store'  // Always fresh (SSR)
    // Or: cache: 'force-cache'  // Cache forever (SSG)
    headers: { 'Authorization': `Bearer ${process.env.API_SECRET}` },
  });
  if (!res.ok) throw new Error('Failed to fetch products');
  return res.json();
}

export default async function ProductsPage() {
  const products = await getProducts(); // Runs server-side, awaited
  
  return (
    <div>
      <h1>Products</h1>
      <ProductGrid products={products} />
    </div>
  );
}

// This server component passes data DOWN to client components
// app/products/_components/ProductGrid.tsx
'use client'; // Only add this where interactivity is needed

import { useState } from 'react';

interface Props { products: Product[] }

export function ProductGrid({ products }: Props) {
  const [filter, setFilter] = useState('');
  
  const filtered = products.filter(p =>
    p.name.toLowerCase().includes(filter.toLowerCase())
  );
  
  return (
    <div>
      <input value={filter} onChange={e => setFilter(e.target.value)} 
             placeholder="Filter..." />
      {filtered.map(p => <ProductCard key={p.id} product={p} />)}
    </div>
  );
}
```

### 3. Streaming with Suspense
```tsx
// app/dashboard/page.tsx
import { Suspense } from 'react';

// Each async section streams independently
export default function DashboardPage() {
  return (
    <div className="grid grid-cols-2 gap-4">
      <Suspense fallback={<MetricsSkeleton />}>
        <MetricsSection />  {/* Streams when ready */}
      </Suspense>
      
      <Suspense fallback={<OrdersSkeleton />}>
        <RecentOrders />    {/* Streams independently */}
      </Suspense>
      
      <Suspense fallback={<ChartSkeleton />}>
        <RevenueChart />    {/* Streams when ready */}
      </Suspense>
    </div>
  );
}

// Each component fetches its own data — no waterfall
async function MetricsSection() {
  const metrics = await fetchMetrics(); // These run in parallel via Promise.all
  return <MetricsDisplay data={metrics} />;
}

async function RecentOrders() {
  const orders = await fetchOrders({ limit: 10 });
  return <OrderTable orders={orders} />;
}
```

### 4. Server Actions for Mutations
```tsx
// app/cart/actions.ts
'use server'; // This file's exports are server actions

import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';

export async function addToCart(formData: FormData) {
  // formData comes from form submission — no API route needed
  const productId = formData.get('productId') as string;
  const quantity = parseInt(formData.get('quantity') as string);
  
  // Direct DB access — runs server-side
  await db.cart.upsert({
    where: { productId },
    update: { quantity: { increment: quantity } },
    create: { productId, quantity },
  });
  
  // Invalidate cached cart count
  revalidatePath('/cart');
  revalidatePath('/checkout');
}

export async function removeFromCart(productId: string) {
  await db.cart.delete({ where: { productId } });
  revalidatePath('/cart');
}

export async function checkout(prevState: any, formData: FormData) {
  // With useFormState — can return error state
  try {
    const order = await createOrder(formData);
    redirect(`/orders/${order.id}/confirmation`); // Throws redirect internally
  } catch (error) {
    if (isRedirectError(error)) throw error; // Re-throw redirect
    return { error: 'Checkout failed. Please try again.' };
  }
}
```

```tsx
// app/cart/page.tsx — Using server actions
import { addToCart } from './actions';

// Pattern 1: Form action (zero client JS)
export function AddToCartForm({ productId }: { productId: string }) {
  return (
    <form action={addToCart}>
      <input type="hidden" name="productId" value={productId} />
      <input type="number" name="quantity" defaultValue={1} min={1} />
      <button type="submit">Add to Cart</button>
    </form>
  );
}

// Pattern 2: Programmatic call from client component
'use client';
import { addToCart } from '../actions';
import { useTransition } from 'react';

export function AddToCartButton({ productId }: { productId: string }) {
  const [isPending, startTransition] = useTransition();
  
  return (
    <button
      disabled={isPending}
      onClick={() => startTransition(() => 
        addToCart(new FormData() /* ... */)
      )}
    >
      {isPending ? 'Adding...' : 'Add to Cart'}
    </button>
  );
}
```

### 5. Caching and Revalidation
```tsx
// app/blog/[slug]/page.tsx
import { notFound } from 'next/navigation';

// Generate static params at build time
export async function generateStaticParams() {
  const posts = await fetchAllPosts();
  return posts.map(post => ({ slug: post.slug }));
}

export default async function BlogPost({ params }: { params: { slug: string } }) {
  const post = await fetchPost(params.slug);
  if (!post) notFound();
  return <PostContent post={post} />;
}

// Revalidation options:
// 1. Time-based (ISR)
export const revalidate = 3600; // Revalidate page every hour

// 2. On-demand (from server action or API route)
import { revalidatePath, revalidateTag } from 'next/cache';

export async function publishPost(slug: string) {
  await db.post.update({ where: { slug }, data: { published: true } });
  revalidatePath(`/blog/${slug}`);    // Specific page
  revalidateTag('blog-posts');        // All tagged fetches
}

// Tag fetches for targeted invalidation
const post = await fetch(`/api/posts/${slug}`, {
  next: { tags: ['blog-posts', `post-${slug}`] },
});
```

### 6. Parallel Data Fetching
```tsx
// WRONG: Sequential waterfall
async function SlowPage() {
  const user = await fetchUser();       // 300ms
  const orders = await fetchOrders();   // 300ms  
  const products = await fetchProducts(); // 300ms
  // Total: 900ms
}

// RIGHT: Parallel with Promise.all
async function FastPage() {
  const [user, orders, products] = await Promise.all([
    fetchUser(),      // All start simultaneously
    fetchOrders(),    // 
    fetchProducts(),  // Total: ~300ms
  ]);
  
  return <Dashboard user={user} orders={orders} products={products} />;
}

// BETTER: Parallel with Suspense streaming (no waterfall, no wait-for-all)
async function BestPage() {
  // Kick off all fetches without awaiting
  const userPromise = fetchUser();
  const ordersPromise = fetchOrders();
  
  return (
    <>
      <Suspense fallback={<UserSkeleton />}>
        <UserSection promise={userPromise} />
      </Suspense>
      <Suspense fallback={<OrdersSkeleton />}>
        <OrdersSection promise={ordersPromise} />
      </Suspense>
    </>
  );
}
```

## Key Commands Reference

```bash
# Create Next.js App Router project
npx create-next-app@latest my-app --typescript --tailwind --app

# Analyze bundle size
npm install -D @next/bundle-analyzer
ANALYZE=true next build

# Inspect RSC payload
# In browser DevTools Network tab, look for requests with ?_rsc=1

# Debug server component rendering
# In next.config.js:
module.exports = { logging: { fetches: { fullUrl: true } } }
```

## Common Patterns

### Pattern 1: Server Component Passing Children to Client
```tsx
// Server component can pass server-rendered children INTO client component
// This avoids the client needing to fetch data

// Server:
async function ServerLayout({ children }: { children: React.ReactNode }) {
  const user = await getUser(); // Server-side
  return (
    <ClientSidebar user={user}>
      {children}  {/* children can be server-rendered! */}
    </ClientSidebar>
  );
}

// Client:
'use client';
function ClientSidebar({ user, children }) {
  const [open, setOpen] = useState(false);
  return (
    <div>
      <nav className={open ? 'open' : ''}>
        <UserAvatar user={user} />
        {children}
      </nav>
    </div>
  );
}
```

### Pattern 2: Optimistic Updates with useOptimistic
```tsx
'use client';
import { useOptimistic } from 'react';
import { toggleLike } from './actions';

export function LikeButton({ postId, initialLiked, initialCount }) {
  const [optimisticLiked, setOptimistic] = useOptimistic(
    { liked: initialLiked, count: initialCount },
    (current, newLiked: boolean) => ({
      liked: newLiked,
      count: current.count + (newLiked ? 1 : -1),
    })
  );
  
  return (
    <form action={async () => {
      setOptimistic(!optimisticLiked.liked); // Instant UI update
      await toggleLike(postId);             // Then sync with server
    }}>
      <button type="submit">
        {optimisticLiked.liked ? '♥' : '♡'} {optimisticLiked.count}
      </button>
    </form>
  );
}
```

### Pattern 3: Error Boundaries per Section
```tsx
// app/dashboard/error.tsx — Scoped to dashboard segment
'use client';

export default function DashboardError({ error, reset }) {
  return (
    <div className="error-card">
      <h2>Dashboard failed to load</h2>
      <button onClick={reset}>Retry</button>
    </div>
  );
}
```

## Pitfalls to Avoid

1. **Passing non-serializable props to client components**: Server components can only pass serializable data (strings, numbers, plain objects, arrays) to client components — not functions, classes, or Dates. Use `toISOString()` for dates and keep business logic in server components.

2. **Adding 'use client' to shared utility files**: Adding `'use client'` to a file moves ALL its imports to the client bundle. Keep utilities in separate files with no directive, then import into client components as needed. Never put `'use client'` on files that export both client and server utilities.

3. **Not using Suspense for slow data**: Without Suspense boundaries, a slow server component blocks the entire page from rendering. Wrap each slow async section in `<Suspense fallback={<Skeleton />}>`. This enables streaming — fast sections appear immediately while slow ones load.

## Related Skills

- `nextjs-fullstack-scaffold` — Full Next.js project setup
- `revalidation-strategy-planner` — Cache and revalidation strategies
- `streaming-llm-responses` — Streaming AI responses in server components
- `server-actions-vs-api-optimizer` — When to use server actions vs API routes

## GitNexus Index

```json
{
  "skill": "react-server-components",
  "category": "frontend",
  "triggers": ["RSC", "react server components", "app router", "server actions", "next.js app router", "use server", "use client"],
  "outputs": ["server component", "client component", "server action", "streaming page"],
  "complexity": "high",
  "tools": ["next.js", "react", "typescript", "vercel"]
}
```
