---
name: vercel-advanced
description: >
  Vercel advanced features: Edge Runtime, ISR/PPR, preview deployments, Analytics, and environment management. Triggers on: Vercel, ISR, revalidatePath, revalidateTag, Edge Runtime, unstable_cache, prerender, PPR, vercel.json.
---

# Vercel Advanced

## When to Use

Trigger when working with Vercel-specific Next.js features: ISR revalidation strategies, Partial Prerendering, Edge Runtime vs Node.js choice, unstable_cache patterns, preview deployments, Speed Insights, or vercel.json configuration.

---

## Core Rules

- ISR = static pages that revalidate in the background — use for product/catalog pages
- `revalidateTag` is preferred over `revalidatePath` when multiple pages share data
- PPR (Partial Prerendering) requires `experimental.ppr = true` in next.config — still experimental
- Edge Runtime: no Node.js APIs, no filesystem, no native modules — use for auth middleware
- `unstable_cache` wraps any async function with caching, tagging, and TTL
- Never put secrets in `vercel.json` — use Vercel dashboard environment variables
- Preview deployments get unique URLs (`https://my-app-abc123.vercel.app`) — safe to share

---

## ISR — Incremental Static Regeneration

### Route Segment Config (App Router)

```typescript
// app/shop/page.tsx
export const revalidate = 60;        // seconds; 0 = no cache; false = infinite
export const dynamic = "force-static"; // always static
// export const dynamic = "force-dynamic"; // always dynamic (SSR)

export default async function Page() { /* ... */ }
```

### revalidatePath — invalidate a specific route

```typescript
// app/api/revalidate/route.ts
import { revalidatePath } from "next/cache";

export async function POST(req: Request) {
  const { path, secret } = await req.json();

  if (secret !== process.env.REVALIDATION_SECRET) {
    return Response.json({ error: "Unauthorized" }, { status: 401 });
  }

  revalidatePath(path);  // e.g., "/shop" or "/shop/[slug]"
  // Also can revalidate layout level:
  revalidatePath("/", "layout");  // invalidates all pages using root layout

  return Response.json({ revalidated: true, path });
}
```

### revalidateTag — tag-based cache invalidation

```typescript
// Tag data when fetching
async function getProducts() {
  const res = await fetch("https://api.example.com/products", {
    next: {
      tags: ["products"],
      revalidate: 3600,
    },
  });
  return res.json();
}

// Or with unstable_cache:
import { unstable_cache } from "next/cache";

const getCachedProducts = unstable_cache(
  async () => {
    return prisma.product.findMany({ where: { isActive: true } });
  },
  ["products-list"],        // cache key parts
  {
    tags: ["products"],     // invalidation tag
    revalidate: 3600,       // 1 hour TTL
  }
);

// Invalidate all "products" tagged cache entries
import { revalidateTag } from "next/cache";

export async function POST(req: Request) {
  const { entity } = await req.json();
  revalidateTag(entity);  // e.g., "products", "orders"
  return Response.json({ revalidated: true });
}
```

### On-demand revalidation from webhook (e.g., Shopify, CMS)

```typescript
// app/api/webhooks/cms/route.ts
import { revalidateTag } from "next/cache";

export async function POST(req: Request) {
  const body = await req.json();

  // Revalidate based on what changed
  if (body.type === "product") {
    revalidateTag("products");
    revalidatePath(`/shop/${body.slug}`);
  }
  if (body.type === "collection") {
    revalidateTag("collections");
  }

  return Response.json({ ok: true });
}
```

---

## unstable_cache Patterns

```typescript
import { unstable_cache } from "next/cache";

// Basic wrapper
const getUser = unstable_cache(
  async (userId: string) => {
    return prisma.user.findUnique({ where: { id: userId } });
  },
  ["user"],                    // base key — userId added automatically as argument
  { tags: ["users"], revalidate: 300 }
);

// Use it like a normal function
const user = await getUser("user-123");

// Dynamic tag per record
const getProduct = unstable_cache(
  async (slug: string) => prisma.product.findUnique({ where: { slug } }),
  ["product"],
  {
    tags: ["products"],           // general tag
    revalidate: 60,
  }
);

// Revalidate just this product:
revalidateTag("products");

// Or use dynamic tags for per-record granularity:
const getProductGranular = unstable_cache(
  async (slug: string) => prisma.product.findUnique({ where: { slug } }),
  ["product"],
  (slug: string) => ({          // tag factory (Next.js 15+)
    tags: [`product-${slug}`],
    revalidate: 3600,
  })
);
// Invalidate: revalidateTag(`product-${slug}`)
```

---

## Partial Prerendering (PPR)

PPR renders a static shell instantly and streams dynamic content. Opt-in per-route.

```typescript
// next.config.ts
import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  experimental: {
    ppr: true,          // enable globally; or "incremental" for per-route opt-in
  },
};

export default nextConfig;
```

```tsx
// app/shop/[slug]/page.tsx
import { Suspense } from "react";
import { ProductInfo } from "./ProductInfo";      // static
import { RecommendedProducts } from "./Recommended"; // dynamic

// With ppr: "incremental", add this:
export const experimental_ppr = true;

export default async function ProductPage({ params }: { params: { slug: string } }) {
  return (
    <div>
      {/* Prerendered at build time */}
      <ProductInfo slug={params.slug} />

      {/* Streamed dynamically — wrapped in Suspense */}
      <Suspense fallback={<div>Loading recommendations...</div>}>
        <RecommendedProducts slug={params.slug} />
      </Suspense>
    </div>
  );
}
```

```tsx
// RecommendedProducts.tsx — forces dynamic rendering
import { cookies } from "next/headers"; // dynamic API

export async function RecommendedProducts({ slug }: { slug: string }) {
  const sessionId = cookies().get("session")?.value;
  const products = await fetchRecommended(slug, sessionId);
  return <ProductGrid products={products} />;
}
```

---

## Edge Runtime vs Node.js Runtime

### When to use Edge Runtime

```typescript
// app/api/auth/route.ts
export const runtime = "edge";  // V8 isolate — fast cold start, global

// Good for:
// - Auth token validation (JWT verify)
// - Geo-routing, A/B testing
// - Request transformation
// - Rate limiting headers

// NOT available in Edge:
// - Node.js crypto (use Web Crypto API instead)
// - File system access
// - Most npm packages that use Node internals
```

### Edge-compatible JWT verification

```typescript
// Edge Runtime — use Web Crypto instead of jsonwebtoken
export const runtime = "edge";

async function verifyJWT(token: string, secret: string): Promise<boolean> {
  const parts = token.split(".");
  if (parts.length !== 3) return false;

  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["verify"]
  );

  const data = new TextEncoder().encode(`${parts[0]}.${parts[1]}`);
  const signature = Uint8Array.from(atob(parts[2].replace(/-/g, "+").replace(/_/g, "/")), (c) => c.charCodeAt(0));

  return crypto.subtle.verify("HMAC", key, signature, data);
}
```

### When to use Node.js Runtime (default)

```typescript
// app/api/pdf/route.ts
export const runtime = "nodejs";  // or omit — nodejs is default

// Required for:
// - Stripe SDK
// - Prisma / database clients
// - Image processing (sharp)
// - PDF generation
// - Any Node.js package
```

### Middleware (always Edge)

```typescript
// middleware.ts — always runs on Edge
import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";

export function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl;

  // Auth check
  const token = request.cookies.get("auth-token")?.value;
  if (pathname.startsWith("/dashboard") && !token) {
    return NextResponse.redirect(new URL("/login", request.url));
  }

  // Geo-based routing
  const country = request.geo?.country;
  if (country === "GB" && pathname === "/") {
    return NextResponse.redirect(new URL("/uk", request.url));
  }

  // A/B test header
  const bucket = Math.random() < 0.5 ? "a" : "b";
  const response = NextResponse.next();
  response.headers.set("x-ab-bucket", bucket);
  return response;
}

export const config = {
  matcher: ["/((?!_next|api|favicon).*)"],
};
```

---

## Preview Deployments

### Trigger from GitHub Actions

```yaml
# .github/workflows/preview.yml
- name: Deploy Preview
  uses: amondnet/vercel-action@v25
  with:
    vercel-token: ${{ secrets.VERCEL_TOKEN }}
    github-token: ${{ secrets.GITHUB_TOKEN }}
    vercel-org-id: ${{ secrets.VERCEL_ORG_ID }}
    vercel-project-id: ${{ secrets.VERCEL_PROJECT_ID }}
    working-directory: ./
```

### Detect preview environment in code

```typescript
const isPreview = process.env.VERCEL_ENV === "preview";
const isProd = process.env.VERCEL_ENV === "production";
const branchName = process.env.VERCEL_GIT_COMMIT_REF;
const previewUrl = process.env.VERCEL_URL; // e.g., "my-app-abc.vercel.app"
```

### Preview-only features

```typescript
// Show debug panel only in preview
export default function DebugPanel() {
  if (process.env.VERCEL_ENV !== "preview") return null;
  return <div>Debug info here</div>;
}
```

---

## vercel.json Configuration

```json
{
  "$schema": "https://openapi.vercel.sh/vercel.json",
  "buildCommand": "npm run build",
  "outputDirectory": ".next",
  "installCommand": "npm ci",
  "framework": "nextjs",

  "rewrites": [
    {
      "source": "/api/legacy/:path*",
      "destination": "https://old-api.example.com/:path*"
    },
    {
      "source": "/shop",
      "destination": "/shop?category=all"
    }
  ],

  "redirects": [
    {
      "source": "/old-page",
      "destination": "/new-page",
      "permanent": true
    },
    {
      "source": "/blog/:slug",
      "destination": "/articles/:slug",
      "permanent": false
    }
  ],

  "headers": [
    {
      "source": "/(.*)",
      "headers": [
        { "key": "X-Frame-Options", "value": "DENY" },
        { "key": "X-Content-Type-Options", "value": "nosniff" },
        { "key": "Referrer-Policy", "value": "strict-origin-when-cross-origin" }
      ]
    },
    {
      "source": "/api/(.*)",
      "headers": [
        { "key": "Access-Control-Allow-Origin", "value": "https://yourdomain.com" }
      ]
    }
  ],

  "regions": ["iad1"],  // Force deployment region: iad1=US-East, sfo1=US-West, cdg1=EU

  "crons": [
    {
      "path": "/api/cron/cleanup",
      "schedule": "0 3 * * *"
    }
  ]
}
```

---

## Environment Variable Management

```bash
# Vercel CLI — manage env vars
npm install -g vercel

# Pull env vars from Vercel to local .env.local
vercel env pull .env.local

# Add env var
vercel env add STRIPE_SECRET_KEY production

# List env vars
vercel env ls

# Remove
vercel env rm STRIPE_SECRET_KEY production
```

### Environment types in Vercel

| Type | When | Access |
|------|------|--------|
| `Production` | `main` branch deploys | Server-side only unless `NEXT_PUBLIC_` |
| `Preview` | All non-main branches | Same |
| `Development` | `vercel dev` local | Same |

```bash
# Override for preview only:
vercel env add NEXT_PUBLIC_API_URL preview
```

---

## Speed Insights & Analytics

```bash
npm install @vercel/speed-insights @vercel/analytics
```

```tsx
// app/layout.tsx
import { SpeedInsights } from "@vercel/speed-insights/next";
import { Analytics } from "@vercel/analytics/react";

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html>
      <body>
        {children}
        <SpeedInsights />
        <Analytics />
      </body>
    </html>
  );
}
```

### Custom analytics events

```typescript
import { track } from "@vercel/analytics";

// Track a custom event
track("Add to Cart", {
  productId: product.id,
  productName: product.name,
  price: product.price,
});

track("Checkout Started", { itemCount: cartItems.length, total: subtotal });
```

---

## Cron Jobs (Vercel)

```typescript
// app/api/cron/cleanup/route.ts
export const maxDuration = 300; // max 5 min for cron jobs

export async function GET(req: Request) {
  // Verify it's actually Vercel calling
  const authHeader = req.headers.get("authorization");
  if (authHeader !== `Bearer ${process.env.CRON_SECRET}`) {
    return new Response("Unauthorized", { status: 401 });
  }

  await cleanupOldSessions();
  await revalidateTag("products");

  return Response.json({ success: true, ran: new Date().toISOString() });
}
```

```json
// vercel.json
{
  "crons": [
    { "path": "/api/cron/cleanup", "schedule": "0 3 * * *" },
    { "path": "/api/cron/sync-inventory", "schedule": "*/15 * * * *" }
  ]
}
```

---

## Vercel KV / Postgres / Blob (Built-in Storage)

```bash
# Vercel KV (Upstash Redis)
npm install @vercel/kv
import { kv } from "@vercel/kv";
await kv.set("key", "value", { ex: 3600 });
const val = await kv.get("key");

# Vercel Postgres (Neon)
npm install @vercel/postgres
import { sql } from "@vercel/postgres";
const { rows } = await sql`SELECT * FROM users WHERE id = ${userId}`;

# Vercel Blob (file storage)
npm install @vercel/blob
import { put } from "@vercel/blob";
const blob = await put("product.jpg", file, { access: "public" });
console.log(blob.url);
```

## GitNexus Index
This skill is indexed by GitNexus for knowledge graph traversal.
Index path: /Users/localuser/claude-skill-vault/skills/cloud-devops/vercel-advanced/.gitnexus
Last indexed: 2026-05-23
