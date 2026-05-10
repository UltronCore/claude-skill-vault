---
name: core-web-vitals
description: >
  Optimize Next.js Core Web Vitals (LCP, CLS, INP/FID) and Lighthouse scores. Triggers on: LCP, CLS, INP, Lighthouse score, Core Web Vitals, next/image, font optimization, layout shift, performance budget.
---

# Core Web Vitals Optimization (Next.js)

## When to Use

Use this skill when diagnosing or fixing performance issues in Next.js production sites: poor Lighthouse scores, slow LCP, layout shifts, janky interactions, or failing Core Web Vitals thresholds in Google Search Console.

---

## Target Thresholds

| Metric | Good | Needs Work | Poor |
|--------|------|------------|------|
| LCP (Largest Contentful Paint) | ≤ 2.5s | 2.5–4s | > 4s |
| CLS (Cumulative Layout Shift) | ≤ 0.1 | 0.1–0.25 | > 0.25 |
| INP (Interaction to Next Paint) | ≤ 200ms | 200–500ms | > 500ms |

---

## LCP Optimization

### 1. Hero Images — `next/image` with `priority`

```typescript
// app/page.tsx — hero image above the fold
import Image from 'next/image'

// ✓ priority tells Next.js to preload this image (removes lazy loading)
// ✓ sizes helps browser pick the right srcset entry
// ✓ fill with a sized container avoids CLS
export default function HeroSection() {
  return (
    <section className="relative h-[600px] w-full">
      <Image
        src="/hero.jpg"
        alt="Our product in action"
        fill
        priority                                    // adds <link rel="preload"> in <head>
        sizes="100vw"                               // full width on all screens
        quality={85}                                // balance quality vs size
        className="object-cover"
        placeholder="blur"                          // prevents CLS while loading
        blurDataURL="data:image/jpeg;base64,..."    // tiny base64 placeholder
      />
    </section>
  )
}

// For non-fill images — always provide width/height
<Image
  src="/product.jpg"
  alt="Product"
  width={800}
  height={600}
  priority
  sizes="(max-width: 768px) 100vw, (max-width: 1200px) 50vw, 800px"
/>
```

### 2. Preload Critical Resources

```typescript
// app/layout.tsx — preload LCP image when src is dynamic/CDN
export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html>
      <head>
        {/* Preload LCP image — use when next/image priority isn't enough */}
        <link
          rel="preload"
          as="image"
          href="https://cdn.example.com/hero.jpg"
          imageSrcSet="https://cdn.example.com/hero-400.jpg 400w, https://cdn.example.com/hero-800.jpg 800w"
          imageSizes="100vw"
        />
        {/* Preconnect to critical third parties */}
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link rel="preconnect" href="https://cdn.example.com" crossOrigin="anonymous" />
        <link rel="dns-prefetch" href="https://analytics.example.com" />
      </head>
      <body>{children}</body>
    </html>
  )
}
```

### 3. Server-Side Rendering for LCP Content

```typescript
// ✓ LCP content should be in initial HTML — not client-fetched
// Use RSC (React Server Components) or generateStaticParams for LCP sections

// app/products/[slug]/page.tsx — static generation
export async function generateStaticParams() {
  const products = await db.product.findMany({ select: { slug: true } })
  return products.map(p => ({ slug: p.slug }))
}

// Product image is in initial HTML — fast LCP
export default async function ProductPage({ params }: { params: { slug: string } }) {
  const product = await db.product.findUnique({ where: { slug: params.slug } })

  return (
    <div>
      <Image src={product.imageUrl} alt={product.name} width={600} height={400} priority />
      <h1>{product.name}</h1>
    </div>
  )
}
```

---

## CLS Prevention

### 1. Always Specify Image Dimensions

```typescript
// ✗ No dimensions — browser can't reserve space → layout shift when image loads
<img src="/product.jpg" alt="Product" />

// ✓ Explicit dimensions — browser reserves space before image loads
<Image src="/product.jpg" alt="Product" width={400} height={300} />

// ✓ Fill with sized container
<div className="relative aspect-video w-full">  {/* aspect-video = 16:9 */}
  <Image src="/video-thumb.jpg" alt="Video" fill className="object-cover" />
</div>

// ✓ CSS aspect-ratio for responsive images
<div className="aspect-square overflow-hidden rounded-lg">
  <Image src="/avatar.jpg" alt="Avatar" fill className="object-cover" />
</div>
```

### 2. Skeleton Loaders — Reserve Space

```typescript
// Reserve exact space with skeleton that matches content dimensions
function ProductCardSkeleton() {
  return (
    <div className="rounded-xl border bg-card">
      {/* Match the 4:3 aspect ratio of the real image */}
      <div className="aspect-[4/3] animate-pulse rounded-t-xl bg-gray-200" />
      <div className="p-4 space-y-3">
        <div className="h-4 w-3/4 animate-pulse rounded bg-gray-200" />
        <div className="h-4 w-1/2 animate-pulse rounded bg-gray-200" />
        <div className="h-8 w-24 animate-pulse rounded bg-gray-200" />
      </div>
    </div>
  )
}

// Use with Suspense
<Suspense fallback={<ProductCardSkeleton />}>
  <ProductCard id={id} />
</Suspense>
```

### 3. Font Display — Prevent Font Flash Shift

```typescript
// next/font — zero CLS, self-hosted, preloaded automatically
import { Inter, Playfair_Display } from 'next/font/google'
import localFont from 'next/font/local'

const inter = Inter({
  subsets: ['latin'],
  display: 'swap',      // show fallback font until Inter loads
  variable: '--font-inter',
  preload: true,        // default true — preloads on first page with this font
})

const playfair = Playfair_Display({
  subsets: ['latin'],
  weight: ['400', '700'],
  variable: '--font-playfair',
})

// Local font (best performance — zero network request)
const myFont = localFont({
  src: [
    { path: '../public/fonts/MyFont-Regular.woff2', weight: '400' },
    { path: '../public/fonts/MyFont-Bold.woff2', weight: '700' },
  ],
  variable: '--font-myfont',
  display: 'swap',
})

// Apply in layout
export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html className={`${inter.variable} ${playfair.variable}`}>
      <body className={inter.className}>{children}</body>
    </html>
  )
}
```

### 4. Avoid Dynamic Content Above Existing Content

```typescript
// ✗ Cookie banner inserts above page — everything shifts down
function CookieBanner() {
  return <div className="fixed-but-inserted-above-content">Accept cookies?</div>
}

// ✓ Fixed position — doesn't affect document flow
function CookieBanner() {
  return (
    <div className="fixed bottom-0 left-0 right-0 z-50 p-4 bg-white border-t shadow-lg">
      We use cookies...
    </div>
  )
}

// ✓ Reserve space in layout if you must show it inline
<div className="min-h-[60px]">  {/* reserved — no shift when banner appears */}
  {showBanner && <CookieBanner />}
</div>
```

---

## INP (Interaction to Next Paint) Optimization

### 1. Code Splitting with `dynamic`

```typescript
import dynamic from 'next/dynamic'

// Heavy components — defer loading until needed
const RichTextEditor = dynamic(() => import('@/components/rich-text-editor'), {
  loading: () => <EditorSkeleton />,
  ssr: false,  // editor requires browser APIs
})

const HeavyChart = dynamic(() => import('@/components/analytics-chart'), {
  loading: () => <ChartSkeleton />,
})

// Only load when user interacts
function BlogPost() {
  const [showEditor, setShowEditor] = useState(false)

  return (
    <>
      <button onClick={() => setShowEditor(true)}>Edit post</button>
      {showEditor && <RichTextEditor />}
    </>
  )
}
```

### 2. Deferred Rendering for Heavy Components

```typescript
import { useDeferredValue, useTransition, startTransition } from 'react'

// useDeferredValue — defer re-rendering of slow list during typing
function SearchResults({ query }: { query: string }) {
  const deferredQuery = useDeferredValue(query)  // lags behind input — keeps input responsive
  const isStale = query !== deferredQuery         // show loading state during transition

  const results = useHeavyFilter(deferredQuery)

  return (
    <div style={{ opacity: isStale ? 0.7 : 1 }}>
      {results.map(r => <ResultCard key={r.id} result={r} />)}
    </div>
  )
}

// useTransition — mark state updates as non-urgent
function DataTable() {
  const [isPending, startTransition] = useTransition()
  const [filter, setFilter] = useState('all')

  function handleFilterChange(newFilter: string) {
    startTransition(() => {
      setFilter(newFilter)  // this update is non-urgent — won't block input
    })
  }

  return (
    <>
      <FilterButtons onSelect={handleFilterChange} />
      {isPending ? <TableSkeleton /> : <ExpensiveTable filter={filter} />}
    </>
  )
}
```

### 3. Debounce Expensive Event Handlers

```typescript
import { useMemo, useCallback } from 'react'

function useDebounce<T>(value: T, delay: number): T {
  const [debounced, setDebounced] = useState(value)

  useEffect(() => {
    const timer = setTimeout(() => setDebounced(value), delay)
    return () => clearTimeout(timer)
  }, [value, delay])

  return debounced
}

// Debounce search to avoid hammering API on every keystroke
function SearchBar({ onSearch }: { onSearch: (q: string) => void }) {
  const [query, setQuery] = useState('')
  const debouncedQuery = useDebounce(query, 300)

  useEffect(() => {
    if (debouncedQuery) onSearch(debouncedQuery)
  }, [debouncedQuery, onSearch])

  return (
    <input
      type="search"
      value={query}
      onChange={e => setQuery(e.target.value)}  // instant — updates input immediately
      placeholder="Search..."
    />
  )
}
```

### 4. Virtualize Long Lists

```typescript
// Use react-virtual or @tanstack/react-virtual for large lists
import { useVirtualizer } from '@tanstack/react-virtual'
import { useRef } from 'react'

function VirtualList({ items }: { items: Item[] }) {
  const parentRef = useRef<HTMLDivElement>(null)

  const virtualizer = useVirtualizer({
    count: items.length,
    getScrollElement: () => parentRef.current,
    estimateSize: () => 72,           // estimated row height in px
    overscan: 5,                      // extra rows rendered above/below viewport
  })

  return (
    <div ref={parentRef} className="h-[600px] overflow-auto">
      <div style={{ height: `${virtualizer.getTotalSize()}px`, position: 'relative' }}>
        {virtualizer.getVirtualItems().map(virtualItem => (
          <div
            key={virtualItem.key}
            style={{
              position: 'absolute',
              top: 0,
              left: 0,
              width: '100%',
              height: `${virtualItem.size}px`,
              transform: `translateY(${virtualItem.start}px)`,
            }}
          >
            <ItemRow item={items[virtualItem.index]} />
          </div>
        ))}
      </div>
    </div>
  )
}
```

---

## Next.js Specific Optimizations

### Script Loading

```typescript
import Script from 'next/script'

// strategy options:
// beforeInteractive — blocks page render (use sparingly: critical polyfills)
// afterInteractive — loads after hydration (analytics, chat widgets)
// lazyOnload — loads during browser idle time (social embeds, feedback widgets)
// worker — moves script to web worker via Partytown (experimental)

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html>
      <body>
        {children}

        {/* Analytics — load after interactive, non-blocking */}
        <Script
          src="https://www.googletagmanager.com/gtag/js?id=GA_ID"
          strategy="afterInteractive"
        />
        <Script id="gtag-init" strategy="afterInteractive">
          {`
            window.dataLayer = window.dataLayer || [];
            function gtag(){dataLayer.push(arguments);}
            gtag('js', new Date());
            gtag('config', 'GA_ID');
          `}
        </Script>

        {/* Intercom / chat — lazy load */}
        <Script
          src="https://widget.intercom.io/widget/YOUR_APP_ID"
          strategy="lazyOnload"
        />
      </body>
    </html>
  )
}
```

### Bundle Analysis

```bash
npm install --save-dev @next/bundle-analyzer

# next.config.ts
import { withBundleAnalyzer } from '@next/bundle-analyzer'

const withAnalyzer = withBundleAnalyzer({
  enabled: process.env.ANALYZE === 'true',
})

export default withAnalyzer(nextConfig)

# Run analysis
ANALYZE=true npm run build
# Opens treemap of client/server bundles — look for unexpected large packages
```

### next.config.ts Performance Settings

```typescript
// next.config.ts
import type { NextConfig } from 'next'

const nextConfig: NextConfig = {
  // Image optimization
  images: {
    formats: ['image/avif', 'image/webp'],   // serve AVIF/WebP (smaller than JPEG/PNG)
    minimumCacheTTL: 60 * 60 * 24 * 30,     // cache images 30 days
    remotePatterns: [
      { protocol: 'https', hostname: 'cdn.example.com' },
      { protocol: 'https', hostname: '*.supabase.co' },
    ],
    deviceSizes: [640, 750, 828, 1080, 1200, 1920],  // customize to your design breakpoints
  },

  // Compress responses
  compress: true,

  // Headers for performance
  async headers() {
    return [
      {
        source: '/(.*)',
        headers: [
          { key: 'X-Content-Type-Options', value: 'nosniff' },
          { key: 'X-Frame-Options', value: 'SAMEORIGIN' },
        ],
      },
      {
        // Cache static assets aggressively
        source: '/(.*)\\.(jpg|jpeg|png|gif|svg|ico|woff|woff2)',
        headers: [
          { key: 'Cache-Control', value: 'public, max-age=31536000, immutable' },
        ],
      },
    ]
  },

  // Experimental
  experimental: {
    optimizeCss: true,          // critters CSS optimization (inline critical CSS)
    optimizePackageImports: [   // only import used exports from large packages
      'lucide-react',
      '@radix-ui/react-icons',
      'date-fns',
      'lodash-es',
    ],
  },
}

export default nextConfig
```

---

## Vercel Speed Insights

```bash
npm install @vercel/speed-insights
```

```typescript
// app/layout.tsx
import { SpeedInsights } from '@vercel/speed-insights/next'
import { Analytics } from '@vercel/analytics/react'

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html>
      <body>
        {children}
        <SpeedInsights />   {/* Real user Core Web Vitals from Vercel dashboard */}
        <Analytics />       {/* Page view analytics */}
      </body>
    </html>
  )
}
```

---

## Measuring in Dev + CI

```typescript
// lib/web-vitals.ts — report to analytics
import { onCLS, onINP, onLCP, onFCP, onTTFB } from 'web-vitals'

function sendToAnalytics(metric: Metric) {
  const body = JSON.stringify({
    name: metric.name,
    value: Math.round(metric.name === 'CLS' ? metric.value * 1000 : metric.value),
    rating: metric.rating,  // 'good' | 'needs-improvement' | 'poor'
    delta: metric.delta,
    id: metric.id,
  })

  // Use sendBeacon for reliability during page unload
  if (navigator.sendBeacon) {
    navigator.sendBeacon('/api/vitals', body)
  } else {
    fetch('/api/vitals', { body, method: 'POST', keepalive: true })
  }
}

export function reportWebVitals() {
  onCLS(sendToAnalytics)
  onINP(sendToAnalytics)
  onLCP(sendToAnalytics)
  onFCP(sendToAnalytics)
  onTTFB(sendToAnalytics)
}

// app/layout.tsx
'use client'
import { useEffect } from 'react'
import { reportWebVitals } from '@/lib/web-vitals'

export function VitalsReporter() {
  useEffect(() => { reportWebVitals() }, [])
  return null
}
```

---

## Quick Wins Checklist

```
LCP:
□ Add priority to hero/LCP image
□ Use next/image for all images
□ Switch to RSC for above-fold data fetching
□ Add preconnect for CDN/font domains
□ Check LCP element in Chrome DevTools Performance panel

CLS:
□ All images have width+height or fill+sized container
□ Fonts use next/font (no FOUT shift)
□ Dynamic content uses fixed positioning or reserved space
□ No content inserted above page fold on load
□ Check CLS elements in Chrome DevTools → CLS annotations

INP:
□ Heavy components use dynamic import
□ Search/filter uses debouncing
□ Long lists use virtualization
□ State updates that cause heavy re-renders use useTransition
□ Third-party scripts use lazyOnload strategy

Bundle:
□ Run ANALYZE=true npm run build — check for unexpected packages
□ Add optimizePackageImports for icon libraries (lucide-react, etc.)
□ Ensure page-level code splitting is working (check .next/analyze)
□ Remove unused dependencies
```
