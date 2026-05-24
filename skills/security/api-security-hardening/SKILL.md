---
name: api-security-hardening
description: >
  API security: rate limiting, authentication middleware, input validation, CORS, and common attack prevention. Triggers on: rate limit, CORS, API key, middleware auth, brute force, SQL injection, XSS, CSRF, security headers.
---

# API Security Hardening

## When to Use
Use when building any public-facing API, adding auth to Next.js routes, or hardening an existing app before launch.

---

## Core Rules
- Validate all input at the boundary — trust nothing from the client
- Rate limit auth endpoints (login, signup, password reset) aggressively
- Never put secrets in responses, logs, or error messages
- Use Supabase RLS as your last line of defense, not your only one
- Always authenticate before authorizing — check identity, then permissions
- Log suspicious events; don't expose them in responses

---

## Rate Limiting

### Upstash Redis Rate Limiting (Recommended for Next.js)
```bash
npm install @upstash/ratelimit @upstash/redis
```

```typescript
// lib/ratelimit.ts
import { Ratelimit } from '@upstash/ratelimit';
import { Redis } from '@upstash/redis';

const redis = new Redis({
  url: process.env.UPSTASH_REDIS_REST_URL!,
  token: process.env.UPSTASH_REDIS_REST_TOKEN!,
});

// Auth endpoints — strict
export const authLimiter = new Ratelimit({
  redis,
  limiter: Ratelimit.slidingWindow(5, '15 m'),  // 5 requests per 15 minutes
  analytics: true,
  prefix: 'rl:auth',
});

// General API — lenient
export const apiLimiter = new Ratelimit({
  redis,
  limiter: Ratelimit.slidingWindow(100, '1 m'),  // 100 req/min
  analytics: true,
  prefix: 'rl:api',
});

// Per-user limiter
export const userLimiter = new Ratelimit({
  redis,
  limiter: Ratelimit.tokenBucket(10, '1 s', 100), // 10 req/s, burst 100
  prefix: 'rl:user',
});
```

```typescript
// middleware.ts (Next.js — runs on edge)
import { NextRequest, NextResponse } from 'next/server';
import { authLimiter, apiLimiter } from '@/lib/ratelimit';

export async function middleware(req: NextRequest) {
  const ip = req.headers.get('x-forwarded-for')?.split(',')[0]?.trim()
    ?? req.headers.get('x-real-ip')
    ?? '127.0.0.1';

  const pathname = req.nextUrl.pathname;

  // Strict rate limit for auth routes
  if (pathname.startsWith('/api/auth')) {
    const { success, limit, remaining, reset } = await authLimiter.limit(ip);

    if (!success) {
      return NextResponse.json(
        { error: 'Too many requests. Try again later.' },
        {
          status: 429,
          headers: {
            'X-RateLimit-Limit': String(limit),
            'X-RateLimit-Remaining': String(remaining),
            'X-RateLimit-Reset': String(reset),
            'Retry-After': String(Math.ceil((reset - Date.now()) / 1000)),
          },
        }
      );
    }
  }

  return NextResponse.next();
}

export const config = {
  matcher: ['/api/:path*'],
};
```

### In-Memory Rate Limiting (No Redis — for low-traffic or dev)
```typescript
// lib/in-memory-ratelimit.ts
const requestCounts = new Map<string, { count: number; resetAt: number }>();

export function inMemoryRateLimit(
  key: string,
  limit: number,
  windowMs: number
): { success: boolean; remaining: number } {
  const now = Date.now();
  const entry = requestCounts.get(key);

  if (!entry || now > entry.resetAt) {
    requestCounts.set(key, { count: 1, resetAt: now + windowMs });
    return { success: true, remaining: limit - 1 };
  }

  if (entry.count >= limit) {
    return { success: false, remaining: 0 };
  }

  entry.count++;
  return { success: true, remaining: limit - entry.count };
}

// Cleanup old entries periodically
setInterval(() => {
  const now = Date.now();
  for (const [key, entry] of requestCounts.entries()) {
    if (now > entry.resetAt) requestCounts.delete(key);
  }
}, 60_000);
```

---

## Authentication Middleware

### JWT Validation
```typescript
// lib/auth-middleware.ts
import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@supabase/supabase-js';

export async function withAuth(
  req: NextRequest,
  handler: (req: NextRequest, user: AuthUser) => Promise<NextResponse>
): Promise<NextResponse> {
  const authHeader = req.headers.get('authorization');
  const token = authHeader?.startsWith('Bearer ') ? authHeader.slice(7) : null;

  if (!token) {
    return NextResponse.json({ error: 'Missing authorization token' }, { status: 401 });
  }

  // Validate with Supabase
  const supabase = createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
  );

  const { data: { user }, error } = await supabase.auth.getUser(token);

  if (error || !user) {
    return NextResponse.json({ error: 'Invalid or expired token' }, { status: 401 });
  }

  return handler(req, user);
}

// Route handler usage
// app/api/protected/route.ts
export async function GET(req: NextRequest) {
  return withAuth(req, async (req, user) => {
    const data = await getUserData(user.id);
    return NextResponse.json(data);
  });
}
```

### API Key Authentication
```typescript
// lib/api-key.ts
import { timingSafeEqual } from 'crypto';

export async function validateApiKey(key: string): Promise<{ valid: boolean; clientId?: string }> {
  // Fetch expected key from DB by prefix
  const prefix = key.slice(0, 8); // first 8 chars identify the key
  const storedKey = await db.query.apiKeys.findFirst({
    where: eq(apiKeys.prefix, prefix),
  });

  if (!storedKey || !storedKey.active) {
    return { valid: false };
  }

  // Timing-safe comparison prevents timing attacks
  const provided = Buffer.from(key);
  const expected = Buffer.from(storedKey.hashedKey);

  if (provided.length !== expected.length) return { valid: false };

  const isValid = timingSafeEqual(provided, expected);
  return { valid: isValid, clientId: storedKey.clientId };
}

// Middleware
export function withApiKey(handler: Handler): Handler {
  return async (req, ctx) => {
    const apiKey = req.headers.get('x-api-key');
    if (!apiKey) return Response.json({ error: 'API key required' }, { status: 401 });

    const { valid, clientId } = await validateApiKey(apiKey);
    if (!valid) {
      await logSuspiciousRequest(req, 'INVALID_API_KEY');
      return Response.json({ error: 'Invalid API key' }, { status: 401 });
    }

    return handler(req, { ...ctx, clientId });
  };
}
```

### Role-Based Authorization
```typescript
// lib/rbac.ts
type Role = 'admin' | 'editor' | 'viewer';

const roleHierarchy: Record<Role, number> = {
  admin: 3,
  editor: 2,
  viewer: 1,
};

export function requireRole(minimumRole: Role) {
  return function withRole(handler: Handler): Handler {
    return async (req, ctx) => {
      const user = ctx.user;
      if (!user) return Response.json({ error: 'Unauthorized' }, { status: 401 });

      const userRoleLevel = roleHierarchy[user.role as Role] ?? 0;
      const requiredLevel = roleHierarchy[minimumRole];

      if (userRoleLevel < requiredLevel) {
        return Response.json({ error: 'Forbidden: insufficient permissions' }, { status: 403 });
      }

      return handler(req, ctx);
    };
  };
}

// Usage
const handler = pipe(withAuth, requireRole('admin'))(myHandler);
```

---

## CORS Configuration

```typescript
// lib/cors.ts
const ALLOWED_ORIGINS = [
  'https://myapp.com',
  'https://www.myapp.com',
  ...(process.env.NODE_ENV === 'development' ? ['http://localhost:3000'] : []),
];

export function corsHeaders(origin: string | null): HeadersInit {
  const allowedOrigin = origin && ALLOWED_ORIGINS.includes(origin) ? origin : ALLOWED_ORIGINS[0];
  return {
    'Access-Control-Allow-Origin': allowedOrigin,
    'Access-Control-Allow-Methods': 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Api-Key',
    'Access-Control-Max-Age': '86400',
    'Vary': 'Origin',
  };
}

// In route handler
export async function OPTIONS(req: NextRequest) {
  const origin = req.headers.get('origin');
  return new Response(null, { status: 204, headers: corsHeaders(origin) });
}

export async function POST(req: NextRequest) {
  const origin = req.headers.get('origin');
  // ... handler logic
  return NextResponse.json(result, { headers: corsHeaders(origin) });
}
```

---

## Security Headers

```javascript
// next.config.js
const securityHeaders = [
  // Prevent clickjacking
  { key: 'X-Frame-Options', value: 'SAMEORIGIN' },
  // Prevent MIME-type sniffing
  { key: 'X-Content-Type-Options', value: 'nosniff' },
  // Referrer policy
  { key: 'Referrer-Policy', value: 'strict-origin-when-cross-origin' },
  // Permissions policy
  { key: 'Permissions-Policy', value: 'camera=(), microphone=(), geolocation=()' },
  // HSTS (uncomment for production HTTPS-only sites)
  // { key: 'Strict-Transport-Security', value: 'max-age=63072000; includeSubDomains; preload' },
  // CSP — adjust to your needs
  {
    key: 'Content-Security-Policy',
    value: [
      "default-src 'self'",
      "script-src 'self' 'unsafe-eval' 'unsafe-inline'",  // 'unsafe-eval' needed for Next.js dev
      "style-src 'self' 'unsafe-inline'",
      "img-src 'self' data: https://*.supabase.co https://images.unsplash.com",
      "connect-src 'self' https://*.supabase.co wss://*.supabase.co",
      "font-src 'self'",
    ].join('; '),
  },
];

module.exports = {
  async headers() {
    return [
      {
        source: '/(.*)',
        headers: securityHeaders,
      },
    ];
  },
};
```

---

## Input Sanitization

```typescript
// lib/sanitize.ts
import DOMPurify from 'isomorphic-dompurify'; // npm install isomorphic-dompurify

// Strip HTML tags for plain text fields
export function sanitizeText(input: string): string {
  return DOMPurify.sanitize(input, { ALLOWED_TAGS: [] }).trim();
}

// Allow safe HTML subset (for rich text)
export function sanitizeHtml(html: string): string {
  return DOMPurify.sanitize(html, {
    ALLOWED_TAGS: ['b', 'i', 'em', 'strong', 'a', 'p', 'br', 'ul', 'li', 'ol'],
    ALLOWED_ATTR: ['href', 'target', 'rel'],
    ADD_ATTR: ['target'],
    FORBID_TAGS: ['script', 'style', 'iframe'],
  });
}

// Sanitize before DB write
export async function POST(req: NextRequest) {
  const body = await req.json();

  // Always use Zod for structural validation first
  const result = PostSchema.safeParse(body);
  if (!result.success) {
    return NextResponse.json({ errors: result.error.flatten() }, { status: 400 });
  }

  // Then sanitize string content
  const sanitized = {
    ...result.data,
    title: sanitizeText(result.data.title),
    body: sanitizeHtml(result.data.body),
  };

  // Drizzle/parameterized queries prevent SQL injection automatically
  const post = await db.insert(posts).values(sanitized).returning();
  return NextResponse.json(post);
}
```

---

## Supabase RLS as Defense Layer

```sql
-- Enable RLS on all tables
ALTER TABLE posts ENABLE ROW LEVEL SECURITY;

-- Users can only read published posts or their own drafts
CREATE POLICY "read_posts" ON posts FOR SELECT
  USING (published = true OR auth.uid() = author_id);

-- Users can only create posts as themselves
CREATE POLICY "create_posts" ON posts FOR INSERT
  WITH CHECK (auth.uid() = author_id);

-- Users can only update their own posts
CREATE POLICY "update_posts" ON posts FOR UPDATE
  USING (auth.uid() = author_id)
  WITH CHECK (auth.uid() = author_id);

-- Users can only delete their own posts
CREATE POLICY "delete_posts" ON posts FOR DELETE
  USING (auth.uid() = author_id);

-- Admin can do anything (based on JWT claim)
CREATE POLICY "admin_all" ON posts FOR ALL
  USING ((auth.jwt() ->> 'role') = 'admin');
```

```typescript
// Use Supabase client with user's JWT (RLS enforced automatically)
// api route:
const supabase = createRouteHandlerClient({ cookies });
const { data: { user } } = await supabase.auth.getUser();

// This query will be filtered by RLS — user can only see their own data
const { data } = await supabase.from('posts').select('*');
```

---

## Logging Suspicious Requests

```typescript
// lib/security-log.ts
interface SecurityEvent {
  type: 'RATE_LIMIT_HIT' | 'INVALID_TOKEN' | 'INVALID_API_KEY' | 'AUTH_FAILURE' | 'SUSPICIOUS_INPUT';
  ip: string;
  path: string;
  userAgent?: string;
  userId?: string;
  metadata?: Record<string, unknown>;
}

export async function logSecurityEvent(req: Request, event: Omit<SecurityEvent, 'ip' | 'path'>) {
  const ip = getClientIp(req);
  const url = new URL(req.url);

  const entry: SecurityEvent = {
    ...event,
    ip,
    path: url.pathname,
    userAgent: req.headers.get('user-agent') ?? undefined,
  };

  // Log to console (Fly.io captures these)
  console.warn('[SECURITY]', JSON.stringify(entry));

  // Optionally write to DB for analysis
  await db.insert(securityLogs).values({
    type: entry.type,
    ip: entry.ip,
    path: entry.path,
    metadata: entry.metadata ?? {},
  });
}

// DO NOT expose security details to the client
// Bad:
return NextResponse.json({ error: 'JWT expired at 2024-01-01, user ID: abc123' });
// Good:
return NextResponse.json({ error: 'Invalid or expired token' }, { status: 401 });
```

---

## Quick Reference

| Threat | Defense |
|---|---|
| Brute force login | Rate limit auth routes (5/15min per IP) |
| DDoS | Rate limit all routes + CDN WAF |
| SQL injection | Parameterized queries (Drizzle/Supabase always) |
| XSS | DOMPurify sanitization + CSP headers |
| CSRF | SameSite cookies + CSRF token for forms |
| Clickjacking | `X-Frame-Options: SAMEORIGIN` |
| Data leakage | Supabase RLS + response sanitization |
| Broken auth | JWT validation via Supabase auth.getUser() |
| API scraping | API key auth + rate limiting |
| Timing attacks | `timingSafeEqual` for secret comparison |

## GitNexus Index
This skill is indexed by GitNexus for knowledge graph traversal.
Index path: /Users/localuser/claude-skill-vault/skills/security/api-security-hardening/.gitnexus
Last indexed: 2026-05-23
