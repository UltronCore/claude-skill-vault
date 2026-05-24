---
name: nextjs-performance
description: Optimize Next.js applications for Core Web Vitals, bundle size, and runtime performance. Covers Image optimization, font loading, dynamic imports, Partial Prerendering, React Server Components, caching strategies, and measuring with Lighthouse and Vercel Analytics.
version: 1.0.0
tags: [nextjs, performance, core-web-vitals, lcp, cls, fid, rsc, ppr, bundle-size, images, frontend]
---

# Next.js Performance Optimization

## Overview

Next.js performance optimization targets three dimensions: build-time (bundle size, code splitting), rendering (SSR vs SSG vs RSC selection), and runtime (image loading, font rendering, Core Web Vitals). Modern Next.js 14/15 features — Partial Prerendering, Server Components, the `use cache` directive — make fine-grained control of the data/rendering boundary possible. The goal is consistently high Core Web Vitals: LCP < 2.5s, CLS < 0.1, INP < 200ms.

## When to Use

- Lighthouse score below 80 or Core Web Vitals failing in CrUX data
- LCP images slow to load (>2.5s) due to unoptimized images or wrong priority settings
- Bundle size over 500KB parsed JavaScript on first load
- CLS caused by fonts, images without dimensions, or async content injecting above existing content
- Slow RSC hydration or server data fetching creating waterfalls
- Pages not benefiting from caching when the data doesn't change between requests

## Step-by-Step Workflow

### 1. Image Optimization

```tsx
// app/components/hero.tsx — optimized hero image
import Image from "next/image";

// Critical LCP image — use priority + fill for responsive
export function HeroImage() {
  return (
    <div style={{ position: "relative", height: "500px" }}>
      <Image
        src="/hero.jpg"
        alt="Hero image"
        fill                        // Fill the container
        priority                    // Preload — don't lazy load LCP images
        sizes="(max-width: 768px) 100vw, (max-width: 1200px) 50vw, 33vw"
        style={{ objectFit: "cover" }}
        quality={85}               // 85 is a good default (100 = 2x file size)
      />
    </div>
  );
}

// Non-critical images — lazy load by default
export function ProductCard({ product }: { product: Product }) {
  return (
    <Image
      src={product.imageUrl}
      alt={product.name}
      width={300}
      height={300}
      // No priority — lazy loaded automatically
      sizes="(max-width: 640px) 100vw, 300px"
    />
  );
}
```

```js
// next.config.js — image optimization configuration
/** @type {import('next').NextConfig} */
const nextConfig = {
  images: {
    formats: ["image/avif", "image/webp"],  // Modern formats first
    deviceSizes: [640, 750, 828, 1080, 1200, 1920],
    imageSizes: [16, 32, 48, 64, 96, 128, 256, 384],
    remotePatterns: [
      { protocol: "https", hostname: "cdn.myapp.com" },
      { protocol: "https", hostname: "images.unsplash.com" },
    ],
    minimumCacheTTL: 86400,  // Cache optimized images for 24h
  },
};

module.exports = nextConfig;
```

### 2. Font Loading (Zero CLS)

```tsx
// app/layout.tsx — optimal font loading
import { Inter, Playfair_Display } from "next/font/google";

// Subset fonts — only load characters you use
const inter = Inter({
  subsets: ["latin"],
  variable: "--font-inter",
  display: "swap",      // Show fallback font until loaded (prevents invisible text)
  preload: true,        // Default — explicitly set for clarity
});

const playfair = Playfair_Display({
  subsets: ["latin"],
  variable: "--font-playfair",
  weight: ["400", "700"],
  display: "swap",
  preload: false,       // Not in critical path — load after body font
});

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={`${inter.variable} ${playfair.variable}`}>
      <body className="font-inter">{children}</body>
    </html>
  );
}
```

```css
/* globals.css — use CSS variables for font families */
body {
  font-family: var(--font-inter), system-ui, sans-serif;
}
h1, h2 {
  font-family: var(--font-playfair), Georgia, serif;
}
```

### 3. Code Splitting with Dynamic Imports

```tsx
// app/components/heavy-chart.tsx — async import for heavy component
import dynamic from "next/dynamic";
import { Suspense } from "react";

// Load chart library only when component is visible
const HeavyChart = dynamic(
  () => import("@/components/chart-library").then(m => m.HeavyChart),
  {
    loading: () => <div className="h-64 animate-pulse bg-gray-200 rounded" />,
    ssr: false,          // Client-only (requires window/DOM)
  }
);

// Load modal only when triggered
const AuthModal = dynamic(() => import("@/components/auth-modal"), {
  loading: () => null,  // No placeholder needed — not visible initially
});

// Route-based code splitting with Suspense
export default function Dashboard() {
  return (
    <div>
      <Suspense fallback={<ChartSkeleton />}>
        <HeavyChart data={data} />
      </Suspense>
    </div>
  );
}
```

```tsx
// app/components/bundle-analyzer.tsx — identify large dependencies
// Run: ANALYZE=true next build
// next.config.js
const withBundleAnalyzer = require("@next/bundle-analyzer")({
  enabled: process.env.ANALYZE === "true",
});

module.exports = withBundleAnalyzer({
  // your config
});
```

### 4. React Server Components and Caching

```tsx
// app/products/page.tsx — Server Component with fine-grained caching
import { Suspense } from "react";
import { unstable_cache } from "next/cache";

// Cache this data fetch for 1 hour, tagged for revalidation
const getProducts = unstable_cache(
  async (category: string) => {
    const products = await db.products.findMany({ where: { category } });
    return products;
  },
  ["products"],                    // Cache key
  {
    revalidate: 3600,              // Revalidate every hour
    tags: ["products"],            // Tag for on-demand revalidation
  }
);

// Server Component — fetches in parallel, no client JS
async function ProductList({ category }: { category: string }) {
  const products = await getProducts(category);
  return (
    <ul>
      {products.map(p => (
        <li key={p.id}>{p.name} - ${p.price}</li>
      ))}
    </ul>
  );
}

// Page with Partial Prerendering (PPR) pattern
export default async function ProductsPage({
  searchParams
}: {
  searchParams: { category?: string }
}) {
  const category = searchParams.category ?? "all";

  return (
    <div>
      <h1>Products</h1>
      {/* Static shell renders immediately */}
      <Suspense fallback={<ProductsSkeleton />}>
        {/* Dynamic content streams in */}
        <ProductList category={category} />
      </Suspense>
    </div>
  );
}

// On-demand revalidation when products change
// app/api/revalidate/route.ts
import { revalidateTag } from "next/cache";
import { NextRequest } from "next/server";

export async function POST(request: NextRequest) {
  const secret = request.headers.get("x-revalidate-secret");
  if (secret !== process.env.REVALIDATE_SECRET) {
    return Response.json({ error: "Unauthorized" }, { status: 401 });
  }
  revalidateTag("products");
  return Response.json({ revalidated: true });
}
```

### 5. Metadata and SEO Performance

```tsx
// app/products/[id]/page.tsx — dynamic metadata with caching
import type { Metadata } from "next";

export async function generateMetadata({ params }: { params: { id: string } }): Promise<Metadata> {
  const product = await getProduct(params.id);

  return {
    title: `${product.name} | MyStore`,
    description: product.description.slice(0, 160),
    openGraph: {
      images: [{ url: product.imageUrl, width: 1200, height: 630 }],
    },
    // Canonical URL prevents duplicate content
    alternates: { canonical: `https://mystore.com/products/${params.id}` },
  };
}

// Generate static paths for most popular products (ISR for the rest)
export async function generateStaticParams() {
  const topProducts = await db.products.findMany({
    take: 100,
    orderBy: { views: "desc" }
  });
  return topProducts.map(p => ({ id: p.id }));
}

export const dynamicParams = true;   // ISR for products not in generateStaticParams
export const revalidate = 3600;      // Revalidate static pages every hour
```

## Key Commands Reference

```bash
# Analyze bundle
ANALYZE=true next build
# Opens webpack-bundle-analyzer in browser

# Measure Core Web Vitals
npx lighthouse https://myapp.com --view
npx lighthouse https://myapp.com --output=json --output-path=./lighthouse.json

# Check for unused JS
npx next build && npx @next/bundle-analyzer

# Find large pages
npx next build 2>&1 | grep "●" | sort -k4 -rh | head -20

# Next.js dev with turbopack (faster HMR)
next dev --turbopack

# Profile server component timing
NEXT_EXPERIMENTAL_PROFILING=1 next build

# Check image optimization locally
curl -I http://localhost:3000/_next/image?url=%2Fhero.jpg&w=1200&q=85
# Should return: Cache-Control: public, max-age=31536000, immutable

# Bundle size limits with bundlesize
npx bundlesize --config bundlesize.config.json
```

## Common Patterns

### Pattern 1: Streaming with Suspense Boundaries

```tsx
// Granular Suspense for optimal streaming — most important content first
export default async function Page() {
  return (
    <main>
      {/* Renders immediately — no async */}
      <Header />

      {/* Streams in as soon as hero data is ready */}
      <Suspense fallback={<HeroSkeleton />}>
        <HeroSection />
      </Suspense>

      <div className="grid grid-cols-2">
        {/* These stream independently */}
        <Suspense fallback={<FeedSkeleton />}>
          <NewsFeed />
        </Suspense>
        <Suspense fallback={<RecommendationSkeleton />}>
          <Recommendations />
        </Suspense>
      </div>
    </main>
  );
}
```

### Pattern 2: Client Component Islands

```tsx
// Minimize client boundary — keep as much in Server Components as possible
// GOOD: Only the interactive part is a Client Component
"use client";
import { useState } from "react";

export function AddToCartButton({ productId }: { productId: string }) {
  const [added, setAdded] = useState(false);

  return (
    <button
      onClick={() => {
        addToCart(productId);
        setAdded(true);
      }}
      className={added ? "bg-green-500" : "bg-blue-500"}
    >
      {added ? "Added!" : "Add to Cart"}
    </button>
  );
}

// Server Component wraps Client Component — passes server data as props
// app/products/[id]/page.tsx (Server Component)
export default async function ProductPage({ params }: { params: { id: string } }) {
  const product = await getProduct(params.id);

  return (
    <div>
      <h1>{product.name}</h1>
      <Image src={product.image} alt={product.name} width={400} height={400} />
      {/* Client island only for interactivity */}
      <AddToCartButton productId={product.id} />
    </div>
  );
}
```

### Pattern 3: Parallel Data Fetching

```tsx
// Fetch in parallel — avoid sequential awaits creating waterfalls
async function ProductDetailPage({ productId }: { productId: string }) {
  // BAD: Sequential fetches (3 round trips)
  // const product = await getProduct(productId);
  // const reviews = await getReviews(productId);
  // const related = await getRelated(productId);

  // GOOD: Parallel fetches (1 round trip)
  const [product, reviews, related] = await Promise.all([
    getProduct(productId),
    getReviews(productId),
    getRelated(productId),
  ]);

  return (
    <div>
      <ProductDetails product={product} />
      <ReviewsList reviews={reviews} />
      <RelatedProducts products={related} />
    </div>
  );
}
```

## Pitfalls to Avoid

1. **Using `"use client"` at the top of the component tree**: This converts all children to client components, eliminating the RSC performance benefits. Keep client boundaries as low as possible — only add `"use client"` to the specific components that need interactivity, state, or browser APIs. The pattern is: Server Component wraps Client Component, not the reverse.

2. **Not setting `sizes` on `<Image>` components**: Without `sizes`, Next.js generates a single large image version and serves it to all screen sizes. `sizes` tells the browser which image size to download based on viewport — `(max-width: 768px) 100vw, 300px` prevents mobile users from downloading a desktop-sized image. Always match `sizes` to your CSS layout.

3. **Fetching in components instead of caching at the request level**: If multiple Server Components on a page call the same `fetch()` URL, Next.js automatically deduplicates them within a single request cycle — but only for identical URLs. Use `unstable_cache` or `cache()` from React for database/ORM queries that don't use `fetch`, and set appropriate `revalidate` values to avoid unnecessary cache misses.

## Related Skills

- `core-web-vitals` — Deep dive into LCP, CLS, and INP measurement
- `react-server-components` — RSC architecture and patterns
- `nextjs-fullstack-scaffold` — Full project setup with Next.js
- `revalidation-strategy-planner` — Cache revalidation strategy design
- `image-optimization` — General image optimization beyond Next.js

## GitNexus Index

```json
{
  "skill": "nextjs-performance",
  "category": "frontend",
  "triggers": ["nextjs performance", "core web vitals nextjs", "LCP optimization", "CLS nextjs", "bundle size nextjs", "RSC performance", "next/image", "next/font", "dynamic import nextjs", "partial prerendering", "unstable_cache", "nextjs caching"],
  "outputs": ["Image priority fill sizes", "Inter font variable", "dynamic() lazy load", "unstable_cache", "generateStaticParams", "revalidateTag", "Promise.all parallel fetch"],
  "complexity": "medium",
  "tools": ["nextjs", "react", "typescript", "lighthouse", "bundle-analyzer", "vercel"]
}
```
