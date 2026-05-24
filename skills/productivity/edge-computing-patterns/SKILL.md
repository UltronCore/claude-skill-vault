---
name: edge-computing-patterns
description: Build and deploy edge computing applications using Cloudflare Workers, Deno Deploy, Vercel Edge Functions, and AWS Lambda@Edge. Covers edge caching, geolocation routing, A/B testing at the edge, and CDN integration.
version: 1.0.0
tags: [edge-computing, cloudflare-workers, vercel-edge, deno-deploy, cdn, serverless, performance]
---

# Edge Computing Patterns

## Overview

This skill covers building applications that run at the network edge — code executing in 300+ global data centers, milliseconds from users. It addresses Cloudflare Workers for general edge logic, Vercel Edge Functions for Next.js, edge caching strategies, geolocation-based routing, A/B testing at the edge without JS, and the important constraints of the edge runtime (no Node.js APIs, 128MB memory, sub-50ms CPU time limits).

## When to Use

- Global APIs where sub-100ms latency is required from any location
- Geolocation-based content personalization or routing
- A/B testing that needs to run before any JavaScript loads (no CLS)
- Authentication/authorization checks before hitting origin servers
- Bot detection, rate limiting, or IP blocking before traffic hits origin
- CDN cache manipulation with custom logic

## Step-by-Step Workflow

### 1. Cloudflare Worker (General Edge Logic)
```typescript
// src/worker.ts
export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const url = new URL(request.url);
    
    // Geolocation routing
    const country = request.cf?.country ?? 'US';
    const region = request.cf?.region;
    
    // Bot detection
    if (isBotRequest(request)) {
      return new Response('Forbidden', { status: 403 });
    }
    
    // Rate limiting check
    const rateLimitKey = `ratelimit:${request.headers.get('CF-Connecting-IP')}`;
    const { success } = await env.RATE_LIMITER.limit({ key: rateLimitKey });
    if (!success) {
      return new Response('Too Many Requests', {
        status: 429,
        headers: { 'Retry-After': '60' }
      });
    }
    
    // Route by path
    if (url.pathname.startsWith('/api/')) {
      return handleAPI(request, env, ctx);
    }
    
    // Serve static with edge cache
    return fetchWithCache(request, env, ctx);
  }
};

async function fetchWithCache(
  request: Request,
  env: Env,
  ctx: ExecutionContext
): Promise<Response> {
  const cache = caches.default;
  const cacheKey = new Request(request.url, { method: 'GET' });
  
  // Check cache
  const cached = await cache.match(cacheKey);
  if (cached) {
    return new Response(cached.body, {
      ...cached,
      headers: { ...cached.headers, 'X-Cache': 'HIT' }
    });
  }
  
  // Fetch from origin
  const response = await fetch(request);
  
  // Cache successful responses
  if (response.ok && response.headers.get('content-type')?.includes('text/html')) {
    const responseToCache = new Response(response.clone().body, {
      ...response,
      headers: {
        ...Object.fromEntries(response.headers),
        'Cache-Control': 'public, max-age=300, stale-while-revalidate=60',
        'X-Cache': 'MISS',
      }
    });
    ctx.waitUntil(cache.put(cacheKey, responseToCache));
  }
  
  return response;
}

function isBotRequest(request: Request): boolean {
  const ua = request.headers.get('User-Agent') ?? '';
  const botPatterns = [/bot/i, /crawler/i, /spider/i, /scraper/i];
  return botPatterns.some(p => p.test(ua));
}

interface Env {
  RATE_LIMITER: RateLimit;
  KV_STORE: KVNamespace;
}
```

### 2. A/B Testing at the Edge
```typescript
// No JavaScript needed — cookie set before HTML loads, no CLS
async function handleABTest(request: Request): Promise<Response> {
  const url = new URL(request.url);
  
  // Check for existing assignment
  const cookies = parseCookies(request.headers.get('Cookie') ?? '');
  let variant = cookies['ab_variant'];
  
  if (!variant) {
    // Assign variant: 50/50 split
    variant = Math.random() < 0.5 ? 'control' : 'treatment';
  }
  
  // Fetch appropriate variant from origin
  const variantUrl = new URL(request.url);
  if (variant === 'treatment') {
    variantUrl.pathname = variantUrl.pathname.replace('/landing', '/landing-v2');
  }
  
  const response = await fetch(variantUrl.toString(), request);
  const newResponse = new Response(response.body, response);
  
  // Set cookie if not already set
  if (!cookies['ab_variant']) {
    newResponse.headers.append('Set-Cookie',
      `ab_variant=${variant}; Path=/; Max-Age=604800; SameSite=Lax`
    );
  }
  
  // Track experiment (fire and forget)
  // ctx.waitUntil(trackImpression(variant, request));
  
  return newResponse;
}

function parseCookies(cookieHeader: string): Record<string, string> {
  return Object.fromEntries(
    cookieHeader.split(';').map(c => c.trim().split('=').map(decodeURIComponent))
  );
}
```

### 3. Geolocation-Based Content
```typescript
export default {
  async fetch(request: Request): Promise<Response> {
    const cf = (request as any).cf;
    const country = cf?.country ?? 'US';
    const continent = cf?.continent ?? 'NA';
    const timezone = cf?.timezone ?? 'America/New_York';
    
    // Content localization
    const locale = getLocale(country);
    const currency = getCurrency(country);
    
    // Compliance-based routing (GDPR)
    if (['DE', 'FR', 'IT', 'ES', 'NL', ...EU_COUNTRIES].includes(country)) {
      // European users: show cookie consent, enable GDPR mode
      return addEUHeaders(await fetch(request), country);
    }
    
    // Price customization at edge (no origin round-trip)
    if (request.url.includes('/api/pricing')) {
      return Response.json({
        price: getRegionalPrice(country),
        currency,
        locale,
      });
    }
    
    // Route EU traffic to EU origin
    if (continent === 'EU') {
      const euUrl = new URL(request.url);
      euUrl.hostname = 'eu.api.example.com';
      return fetch(euUrl.toString(), request);
    }
    
    return fetch(request);
  }
};

const EU_COUNTRIES = ['DE', 'FR', 'IT', 'ES', 'NL', 'BE', 'AT', 'PT', 'SE', 'DK', 'FI', 'PL'];
```

### 4. Vercel Edge Functions (Next.js)
```typescript
// middleware.ts — runs at edge before every request
import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/server';

export function middleware(request: NextRequest) {
  const { pathname, searchParams } = request.nextUrl;
  
  // Auth check at edge (JWT verification without DB roundtrip)
  const token = request.cookies.get('session')?.value;
  if (pathname.startsWith('/dashboard')) {
    if (!token || !isValidToken(token)) {
      return NextResponse.redirect(new URL('/login', request.url));
    }
  }
  
  // Rewrite for A/B testing
  if (pathname === '/') {
    const bucket = getBucket(request);
    if (bucket === 'b') {
      return NextResponse.rewrite(new URL('/homepage-v2', request.url));
    }
  }
  
  // Add security headers to all responses
  const response = NextResponse.next();
  response.headers.set('X-Frame-Options', 'DENY');
  response.headers.set('X-Content-Type-Options', 'nosniff');
  response.headers.set('Referrer-Policy', 'strict-origin-when-cross-origin');
  return response;
}

export const config = {
  matcher: ['/((?!_next/static|_next/image|favicon.ico).*)'],
};

function getBucket(request: NextRequest): 'a' | 'b' {
  const cookieBucket = request.cookies.get('ab_bucket')?.value;
  if (cookieBucket) return cookieBucket as 'a' | 'b';
  return Math.random() < 0.5 ? 'a' : 'b';
}

function isValidToken(token: string): boolean {
  // Edge-compatible JWT verification (no node crypto — use Web Crypto API)
  try {
    const [, payloadB64] = token.split('.');
    const payload = JSON.parse(atob(payloadB64));
    return payload.exp > Date.now() / 1000;
  } catch {
    return false;
  }
}
```

### 5. KV Storage at Edge
```typescript
// Cloudflare Workers KV for edge-distributed data
export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    
    if (url.pathname === '/feature-flags') {
      // Read feature flags from KV (eventually consistent, globally cached)
      const flags = await env.KV_STORE.get('feature-flags', 'json');
      return Response.json(flags ?? {});
    }
    
    if (url.pathname === '/redirect' && request.method === 'GET') {
      const slug = url.searchParams.get('slug');
      const target = await env.KV_STORE.get(`redirect:${slug}`);
      if (target) {
        return Response.redirect(target, 301);
      }
    }
    
    return new Response('Not Found', { status: 404 });
  }
};
```

## Key Commands Reference

```bash
# Cloudflare Workers
npm install -g wrangler
wrangler init my-worker
wrangler dev        # Local development
wrangler deploy     # Deploy to edge

# Test worker locally
wrangler dev --port 8787
curl http://localhost:8787/

# Tail logs in production
wrangler tail

# KV operations
wrangler kv:put --namespace-id=XXX "key" "value"
wrangler kv:get --namespace-id=XXX "key"
wrangler kv:list --namespace-id=XXX --prefix="redirect:"

# Vercel Edge
vercel env pull .env.local
vercel dev    # Runs middleware locally
vercel deploy --prod
```

## Common Patterns

### Pattern 1: Edge Authentication with JWT
```typescript
// Verify JWT using Web Crypto API (edge-compatible)
async function verifyJWT(token: string, secret: string): Promise<boolean> {
  const [header, payload, signature] = token.split('.');
  
  const key = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['verify']
  );
  
  const valid = await crypto.subtle.verify(
    'HMAC',
    key,
    base64UrlDecode(signature),
    new TextEncoder().encode(`${header}.${payload}`)
  );
  
  if (!valid) return false;
  
  const { exp } = JSON.parse(atob(payload.replace(/-/g, '+').replace(/_/g, '/')));
  return exp > Math.floor(Date.now() / 1000);
}
```

### Pattern 2: Edge Cache Invalidation
```typescript
// Purge specific URL from edge cache via Cloudflare API
async function purgeEdgeCache(urls: string[], cfZoneId: string, cfToken: string) {
  const response = await fetch(
    `https://api.cloudflare.com/client/v4/zones/${cfZoneId}/purge_cache`,
    {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${cfToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ files: urls }),
    }
  );
  return response.json();
}
```

### Pattern 3: Request Transformation
```typescript
// Rewrite requests, add headers, change method before hitting origin
async function transformRequest(request: Request): Promise<Response> {
  // Add API key to origin request (not exposed to client)
  const newRequest = new Request(request, {
    headers: {
      ...Object.fromEntries(request.headers),
      'X-API-Key': SECRET_API_KEY,
      'X-Forwarded-Country': request.cf?.country ?? 'US',
    }
  });
  
  // Strip sensitive headers before forwarding to origin
  newRequest.headers.delete('Cookie');
  
  return fetch(newRequest);
}
```

## Pitfalls to Avoid

1. **Node.js APIs at the edge**: Edge runtimes don't support Node.js built-ins (fs, path, crypto, Buffer). Use the Web Platform APIs instead: `fetch`, `crypto.subtle`, `TextEncoder`, `ReadableStream`. Test locally with `wrangler dev` which enforces edge constraints.

2. **CPU time limit exceeded**: Cloudflare Workers have 10-50ms CPU time limits. Long-running loops, heavy crypto, or large JSON parsing fail. Profile with `performance.now()` timing and move heavy work to origin or Durable Objects. Stream responses instead of loading full body.

3. **Over-using KV for high-frequency writes**: Cloudflare KV is eventually consistent and rate-limited on writes (1 write/key/second globally). For high-frequency counters or session state, use Durable Objects instead. KV is best for config, feature flags, and redirect maps that change infrequently.

## Related Skills

- `cloudflare-expert` — Deep Cloudflare platform knowledge
- `react-server-components` — Next.js middleware integration
- `redis-patterns` — Session state at the edge with Redis
- `circuit-breaker-patterns` — Resilience patterns for edge → origin calls

## GitNexus Index

```json
{
  "skill": "edge-computing-patterns",
  "category": "devops",
  "triggers": ["edge computing", "cloudflare workers", "vercel edge", "edge functions", "CDN logic", "middleware next.js", "geolocation routing"],
  "outputs": ["worker script", "middleware", "edge function", "KV store config"],
  "complexity": "medium",
  "tools": ["wrangler", "cloudflare-workers", "vercel", "deno-deploy"]
}
```
