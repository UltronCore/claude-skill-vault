---
name: oauth2-oidc-implementation
description: Implement OAuth 2.0 and OpenID Connect flows for secure authentication and authorization. Covers authorization code + PKCE, client credentials, refresh token rotation, JWT validation, provider integration (Google, GitHub, Auth0), and FastAPI/Next.js examples.
version: 1.0.0
tags: [oauth2, oidc, jwt, pkce, authentication, authorization, fastapi, nextjs, auth0, google-oauth]
---

# OAuth 2.0 and OpenID Connect Implementation

## Overview

OAuth 2.0 is the authorization framework for delegating API access; OpenID Connect (OIDC) adds an identity layer on top via ID tokens. Together they power "Login with Google/GitHub" flows, machine-to-machine API auth (client credentials), and fine-grained resource access. The authorization code + PKCE flow is the secure standard for public clients (SPAs, mobile apps) — never use implicit flow or auth code without PKCE in new applications.

## When to Use

- Building "Login with [Provider]" social auth buttons
- Issuing and validating JWTs for your own API
- Machine-to-machine auth where a service calls another service's API
- Fine-grained permission scopes (read:orders vs write:orders)
- Replacing session-based auth with stateless JWT auth in APIs
- Implementing multi-tenant SaaS where each org has its own identity provider

## Step-by-Step Workflow

### 1. Authorization Code + PKCE Flow (SPA/Mobile)

```typescript
// pkce.ts — browser-side PKCE implementation
// PKCE prevents authorization code interception attacks

export async function generatePKCE(): Promise<{ verifier: string; challenge: string }> {
  // Code verifier: 43-128 random chars
  const verifier = Array.from(crypto.getRandomValues(new Uint8Array(64)))
    .map(b => b.toString(16).padStart(2, "0"))
    .join("")
    .slice(0, 128);

  // Code challenge: BASE64URL(SHA256(verifier))
  const hash = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(verifier));
  const challenge = btoa(String.fromCharCode(...new Uint8Array(hash)))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=/g, "");

  return { verifier, challenge };
}

export function buildAuthUrl(params: {
  authEndpoint: string;
  clientId: string;
  redirectUri: string;
  scopes: string[];
  codeChallenge: string;
  state: string;
}): string {
  const url = new URL(params.authEndpoint);
  url.searchParams.set("response_type", "code");
  url.searchParams.set("client_id", params.clientId);
  url.searchParams.set("redirect_uri", params.redirectUri);
  url.searchParams.set("scope", params.scopes.join(" "));
  url.searchParams.set("code_challenge", params.codeChallenge);
  url.searchParams.set("code_challenge_method", "S256");
  url.searchParams.set("state", params.state); // CSRF protection
  return url.toString();
}

// auth.ts — initiate login flow
export async function initiateLogin() {
  const { verifier, challenge } = await generatePKCE();
  const state = crypto.randomUUID();

  // Store for callback verification
  sessionStorage.setItem("pkce_verifier", verifier);
  sessionStorage.setItem("oauth_state", state);

  const loginUrl = buildAuthUrl({
    authEndpoint: "https://accounts.google.com/o/oauth2/v2/auth",
    clientId: process.env.NEXT_PUBLIC_GOOGLE_CLIENT_ID!,
    redirectUri: `${window.location.origin}/auth/callback`,
    scopes: ["openid", "email", "profile"],
    codeChallenge: challenge,
    state,
  });

  window.location.href = loginUrl;
}

// callback.ts — handle the redirect back from provider
export async function handleCallback(searchParams: URLSearchParams) {
  const code = searchParams.get("code");
  const state = searchParams.get("state");
  const storedState = sessionStorage.getItem("oauth_state");
  const verifier = sessionStorage.getItem("pkce_verifier");

  if (!code || state !== storedState) {
    throw new Error("Invalid OAuth callback");
  }

  sessionStorage.removeItem("pkce_verifier");
  sessionStorage.removeItem("oauth_state");

  // Exchange code for tokens — done server-side to keep client_secret hidden
  const response = await fetch("/api/auth/token", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ code, verifier }),
  });

  const tokens = await response.json();
  return tokens; // { access_token, id_token, refresh_token }
}
```

### 2. Token Exchange Server-Side (Next.js Route Handler)

```typescript
// app/api/auth/token/route.ts
import { NextRequest, NextResponse } from "next/server";

export async function POST(request: NextRequest) {
  const { code, verifier } = await request.json();

  const tokenResponse = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "authorization_code",
      code,
      redirect_uri: `${process.env.NEXT_PUBLIC_BASE_URL}/auth/callback`,
      client_id: process.env.GOOGLE_CLIENT_ID!,
      client_secret: process.env.GOOGLE_CLIENT_SECRET!, // NEVER expose to client
      code_verifier: verifier,
    }),
  });

  const tokens = await tokenResponse.json();
  if (!tokenResponse.ok) {
    return NextResponse.json({ error: tokens.error }, { status: 400 });
  }

  // Validate ID token and extract user info
  const payload = await verifyIdToken(tokens.id_token);

  // Create session (httpOnly cookie — never store tokens in localStorage)
  const response = NextResponse.json({ user: { id: payload.sub, email: payload.email } });
  response.cookies.set("session", await createSession(payload), {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "lax",
    maxAge: 60 * 60 * 24 * 7, // 7 days
    path: "/",
  });

  return response;
}

async function verifyIdToken(idToken: string): Promise<any> {
  // Fetch Google's public keys and verify JWT signature
  const keysResponse = await fetch("https://www.googleapis.com/oauth2/v3/certs");
  const { keys } = await keysResponse.json();

  // Use jose library for JWT verification
  const { createRemoteJWKSet, jwtVerify } = await import("jose");
  const JWKS = createRemoteJWKSet(new URL("https://www.googleapis.com/oauth2/v3/certs"));

  const { payload } = await jwtVerify(idToken, JWKS, {
    audience: process.env.GOOGLE_CLIENT_ID,
    issuer: ["https://accounts.google.com", "accounts.google.com"],
  });

  return payload;
}

async function createSession(payload: any): Promise<string> {
  // Create your own JWT session token
  const { SignJWT } = await import("jose");
  const secret = new TextEncoder().encode(process.env.SESSION_SECRET!);
  return new SignJWT({ sub: payload.sub, email: payload.email })
    .setProtectedHeader({ alg: "HS256" })
    .setIssuedAt()
    .setExpirationTime("7d")
    .sign(secret);
}
```

### 3. FastAPI JWT Authentication

```python
# pip install fastapi python-jose[cryptography] passlib[bcrypt] pydantic
from fastapi import FastAPI, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from jose import JWTError, jwt
from passlib.context import CryptContext
from pydantic import BaseModel
from datetime import datetime, timedelta
import os

SECRET_KEY = os.getenv("JWT_SECRET_KEY", "change-in-production")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 30
REFRESH_TOKEN_EXPIRE_DAYS = 30

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/token")
app = FastAPI()

class TokenPair(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"

class TokenData(BaseModel):
    user_id: str
    scopes: list[str] = []

def create_access_token(user_id: str, scopes: list[str]) -> str:
    expires = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    return jwt.encode({
        "sub": user_id,
        "scopes": scopes,
        "exp": expires,
        "type": "access",
    }, SECRET_KEY, algorithm=ALGORITHM)

def create_refresh_token(user_id: str) -> str:
    expires = datetime.utcnow() + timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS)
    return jwt.encode({
        "sub": user_id,
        "exp": expires,
        "type": "refresh",
        "jti": str(__import__("uuid").uuid4()),  # Unique ID for revocation
    }, SECRET_KEY, algorithm=ALGORITHM)

async def get_current_user(token: str = Depends(oauth2_scheme)) -> TokenData:
    credentials_exc = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        if payload.get("type") != "access":
            raise credentials_exc
        user_id = payload.get("sub")
        if not user_id:
            raise credentials_exc
        return TokenData(user_id=user_id, scopes=payload.get("scopes", []))
    except JWTError:
        raise credentials_exc

def require_scope(scope: str):
    """Dependency factory for scope-based authorization."""
    async def check_scope(token_data: TokenData = Depends(get_current_user)):
        if scope not in token_data.scopes:
            raise HTTPException(status_code=403, detail=f"Missing scope: {scope}")
        return token_data
    return check_scope

@app.post("/auth/token", response_model=TokenPair)
async def login(form: OAuth2PasswordRequestForm = Depends()):
    # Validate credentials against database
    user = await authenticate_user(form.username, form.password)
    if not user:
        raise HTTPException(status_code=401, detail="Invalid credentials")

    return TokenPair(
        access_token=create_access_token(user.id, scopes=user.scopes),
        refresh_token=create_refresh_token(user.id),
    )

@app.post("/auth/refresh", response_model=TokenPair)
async def refresh_tokens(refresh_token: str):
    try:
        payload = jwt.decode(refresh_token, SECRET_KEY, algorithms=[ALGORITHM])
        if payload.get("type") != "refresh":
            raise HTTPException(status_code=401, detail="Invalid token type")

        # Refresh token rotation: invalidate old, issue new pair
        user_id = payload["sub"]
        await invalidate_refresh_token(payload["jti"])  # Stored in Redis/DB

        user = await get_user_by_id(user_id)
        return TokenPair(
            access_token=create_access_token(user.id, user.scopes),
            refresh_token=create_refresh_token(user.id),
        )
    except JWTError:
        raise HTTPException(status_code=401, detail="Invalid refresh token")

# Protected routes with scope requirements
@app.get("/orders")
async def list_orders(token: TokenData = Depends(require_scope("read:orders"))):
    return {"user_id": token.user_id, "orders": []}

@app.post("/orders")
async def create_order(token: TokenData = Depends(require_scope("write:orders"))):
    return {"created": True, "user_id": token.user_id}
```

### 4. Client Credentials Flow (Machine-to-Machine)

```python
# M2M: service-to-service authentication without a user
import httpx
import time
from functools import lru_cache

class ClientCredentialsTokenManager:
    """Cache and auto-refresh client credentials tokens."""

    def __init__(self, token_url: str, client_id: str, client_secret: str, audience: str):
        self.token_url = token_url
        self.client_id = client_id
        self.client_secret = client_secret
        self.audience = audience
        self._token: str | None = None
        self._expires_at: float = 0

    async def get_token(self) -> str:
        # Return cached token if still valid (with 60s buffer)
        if self._token and time.time() < self._expires_at - 60:
            return self._token

        async with httpx.AsyncClient() as client:
            response = await client.post(self.token_url, data={
                "grant_type": "client_credentials",
                "client_id": self.client_id,
                "client_secret": self.client_secret,
                "audience": self.audience,
            })
            response.raise_for_status()
            data = response.json()

        self._token = data["access_token"]
        self._expires_at = time.time() + data["expires_in"]
        return self._token

    async def get_headers(self) -> dict:
        token = await self.get_token()
        return {"Authorization": f"Bearer {token}"}

# Usage: service that calls another internal API
token_manager = ClientCredentialsTokenManager(
    token_url="https://auth.example.com/oauth/token",
    client_id=os.getenv("SERVICE_CLIENT_ID"),
    client_secret=os.getenv("SERVICE_CLIENT_SECRET"),
    audience="https://api.internal.example.com",
)

async def call_internal_api(endpoint: str) -> dict:
    headers = await token_manager.get_headers()
    async with httpx.AsyncClient() as client:
        response = await client.get(f"https://api.internal.example.com{endpoint}", headers=headers)
        response.raise_for_status()
        return response.json()
```

### 5. Auth0 Integration

```typescript
// Next.js Auth0 integration with @auth0/nextjs-auth0
// npm install @auth0/nextjs-auth0

// app/api/auth/[auth0]/route.ts
import { handleAuth, handleLogin, handleCallback, handleLogout } from "@auth0/nextjs-auth0";

export const GET = handleAuth({
  login: handleLogin({
    authorizationParams: {
      scope: "openid profile email read:orders",
      audience: "https://api.example.com",
    },
  }),
  callback: handleCallback({
    afterCallback: async (req, session) => {
      // Sync user to your database after first login
      await upsertUser({ id: session.user.sub, email: session.user.email });
      return session;
    },
  }),
  logout: handleLogout({ returnTo: "/" }),
});

// middleware.ts — protect routes
import { withMiddlewareAuthRequired } from "@auth0/nextjs-auth0/edge";
export default withMiddlewareAuthRequired();
export const config = { matcher: ["/dashboard/:path*", "/api/protected/:path*"] };

// app/api/orders/route.ts — verify Auth0 JWT on API routes
import { getSession, withApiAuthRequired } from "@auth0/nextjs-auth0";
import { NextRequest } from "next/server";

export const GET = withApiAuthRequired(async (req: NextRequest) => {
  const { user } = await getSession(req)!;
  // user.sub, user.email available
  return Response.json({ orders: [] });
});
```

### 6. JWT Validation Middleware

```python
# Reusable JWT validation middleware for any Python web framework
import jwt
import httpx
from functools import lru_cache
from typing import Any

@lru_cache(maxsize=1)
def get_jwks(jwks_uri: str) -> dict:
    """Fetch and cache JWKS public keys."""
    response = httpx.get(jwks_uri, timeout=5.0)
    response.raise_for_status()
    return response.json()

def validate_jwt(
    token: str,
    jwks_uri: str,
    audience: str,
    issuer: str,
) -> dict[str, Any]:
    """Validate a JWT against JWKS public keys."""
    import jwt as pyjwt
    from jwt import PyJWKClient

    jwks_client = PyJWKClient(jwks_uri, cache_jwk_set=True, lifespan=3600)
    signing_key = jwks_client.get_signing_key_from_jwt(token)

    return pyjwt.decode(
        token,
        signing_key.key,
        algorithms=["RS256", "RS384", "RS512", "ES256"],
        audience=audience,
        issuer=issuer,
        options={"verify_exp": True, "verify_nbf": True},
    )

# FastAPI dependency using Auth0 JWKS
from fastapi import Request, HTTPException

async def verify_auth0_token(request: Request) -> dict:
    auth = request.headers.get("Authorization", "")
    if not auth.startswith("Bearer "):
        raise HTTPException(401, "Missing Bearer token")
    token = auth[7:]
    try:
        return validate_jwt(
            token,
            jwks_uri=f"https://{os.getenv('AUTH0_DOMAIN')}/.well-known/jwks.json",
            audience=os.getenv("AUTH0_AUDIENCE"),
            issuer=f"https://{os.getenv('AUTH0_DOMAIN')}/",
        )
    except Exception as e:
        raise HTTPException(401, f"Invalid token: {e}")
```

## Key Commands Reference

```bash
# Test OAuth flows locally
pip install authlib requests-oauthlib httpx python-jose[cryptography]
npm install jose @auth0/nextjs-auth0 next-auth

# Generate a strong JWT secret
openssl rand -hex 32

# Decode a JWT (without verification — for debugging)
echo "eyJ..." | cut -d. -f2 | base64 -d 2>/dev/null | jq .
# Or use: jwt.io in browser

# Test client credentials flow with curl
curl -X POST https://auth.example.com/oauth/token \
  -d grant_type=client_credentials \
  -d client_id=$CLIENT_ID \
  -d client_secret=$CLIENT_SECRET \
  -d audience=https://api.example.com

# Verify JWT signature with jose CLI
npm install -g jose
jose verify --key public.pem --alg RS256 token.jwt

# Auth0 CLI
npm install -g auth0-cli
auth0 login
auth0 apps create --name "MyApp" --type native --callbacks "http://localhost:3000/callback"
auth0 users list
```

## Common Patterns

### Pattern 1: Refresh Token Rotation with Redis

```python
import redis.asyncio as redis
import uuid

r = redis.from_url(os.getenv("REDIS_URL", "redis://localhost:6379"))

async def issue_refresh_token(user_id: str) -> str:
    token_id = str(uuid.uuid4())
    token = create_refresh_token_with_jti(user_id, token_id)
    # Store token_id in Redis with 30-day TTL
    await r.setex(f"refresh:{user_id}:{token_id}", 30 * 24 * 3600, "valid")
    return token

async def validate_and_rotate_refresh_token(refresh_token: str) -> tuple[str, str]:
    payload = jwt.decode(refresh_token, SECRET_KEY, algorithms=[ALGORITHM])
    user_id = payload["sub"]
    token_id = payload["jti"]

    # Check if token is still valid (not revoked or already used)
    key = f"refresh:{user_id}:{token_id}"
    exists = await r.exists(key)
    if not exists:
        # Possible token reuse attack — revoke all tokens for this user
        await r.delete(*await r.keys(f"refresh:{user_id}:*"))
        raise ValueError("Refresh token already used or revoked")

    # Revoke old token
    await r.delete(key)

    # Issue new pair
    new_access = create_access_token(user_id, ["read:orders"])
    new_refresh = await issue_refresh_token(user_id)
    return new_access, new_refresh
```

### Pattern 2: Scope-Based API Access

```python
# Hierarchical scopes: read:* implies read:orders, read:products
SCOPE_HIERARCHY = {
    "admin": ["read:*", "write:*", "delete:*"],
    "read:*": ["read:orders", "read:products", "read:users"],
    "write:*": ["write:orders", "write:products"],
}

def expand_scopes(scopes: list[str]) -> set[str]:
    """Expand wildcard scopes to concrete scopes."""
    expanded = set(scopes)
    for scope in scopes:
        if scope in SCOPE_HIERARCHY:
            expanded.update(expand_scopes(SCOPE_HIERARCHY[scope]))
    return expanded

def has_scope(token_scopes: list[str], required_scope: str) -> bool:
    return required_scope in expand_scopes(token_scopes)
```

### Pattern 3: PKCE State Management in React

```tsx
// hooks/useOAuth.ts
import { useCallback } from "react";
import { generatePKCE, buildAuthUrl, handleCallback } from "@/lib/pkce";

export function useOAuth() {
  const login = useCallback(async (provider: "google" | "github") => {
    const { verifier, challenge } = await generatePKCE();
    const state = crypto.randomUUID();
    sessionStorage.setItem("pkce_verifier", verifier);
    sessionStorage.setItem("oauth_state", state);

    const authUrl = buildAuthUrl({
      authEndpoint: provider === "google"
        ? "https://accounts.google.com/o/oauth2/v2/auth"
        : "https://github.com/login/oauth/authorize",
      clientId: process.env.NEXT_PUBLIC_OAUTH_CLIENT_ID!,
      redirectUri: `${window.location.origin}/auth/callback`,
      scopes: ["openid", "email", "profile"],
      codeChallenge: challenge,
      state,
    });
    window.location.href = authUrl;
  }, []);

  return { login };
}
```

## Pitfalls to Avoid

1. **Storing tokens in localStorage**: JWTs in localStorage are accessible to any JavaScript on the page, including injected XSS payloads. Always store tokens in httpOnly, Secure, SameSite=Lax cookies (server-sets them, JS can't read them). For SPAs, use the BFF (Backend for Frontend) pattern: the SPA hits your own API, which manages tokens in cookies.

2. **Not rotating refresh tokens**: Issuing a long-lived refresh token that can be used unlimited times creates a huge attack surface. Implement refresh token rotation (each use invalidates the old token and issues a new one) with reuse detection — if an already-used token is presented, revoke all tokens for that user (possible stolen token).

3. **Skipping JWT signature validation**: Never use `jwt.decode(token, options={"verify_signature": False})` in production. Always verify the signature against the issuer's JWKS public keys. Also verify `exp`, `nbf`, `iss`, and `aud` claims — many security vulnerabilities stem from trusting unsigned or mis-issued tokens.

## Related Skills

- `api-security-hardening` — Rate limiting, API key rotation, and endpoint protection
- `auth-route-protection-checker` — Audit existing routes for missing auth guards
- `supabase-auth-ssr-setup` — Supabase Auth with SSR and row-level security
- `soc2-compliance` — Audit logging and access control requirements for SOC 2

## GitNexus Index

```json
{
  "skill": "oauth2-oidc-implementation",
  "category": "security",
  "triggers": ["oauth2", "oidc", "openid connect", "jwt authentication", "pkce", "authorization code", "refresh token", "client credentials", "login with google", "auth0 integration"],
  "outputs": ["generatePKCE", "buildAuthUrl", "create_access_token", "get_current_user", "ClientCredentialsTokenManager", "validate_jwt"],
  "complexity": "high",
  "tools": ["python-jose", "jose", "auth0", "fastapi", "next.js", "pydantic", "httpx"]
}
```
