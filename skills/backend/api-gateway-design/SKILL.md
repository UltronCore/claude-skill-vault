---
name: api-gateway-design
description: Design and implement API gateways for microservices. Covers Kong, AWS API Gateway, custom gateway with Node.js, authentication/authorization, rate limiting, request transformation, load balancing, and observability.
version: 1.0.0
tags: [api-gateway, kong, aws-api-gateway, rate-limiting, authentication, microservices, proxy]
---

# API Gateway Design

## Overview

An API gateway is the single entry point for all client requests in a microservices architecture. It handles cross-cutting concerns — authentication, rate limiting, request routing, SSL termination, response caching, and observability — so individual services don't have to. This skill covers Kong (self-hosted), AWS API Gateway, and building custom gateways with Node.js/Fastify for teams that need programmatic control.

## When to Use

- Consolidating multiple backend services behind a single URL for clients
- Implementing consistent authentication/authorization across all APIs
- Rate limiting or throttling per API key, user, or plan tier
- A/B testing, canary deployments, or blue/green routing at the API layer
- Request/response transformation (versioning, field filtering, format conversion)
- Centralized logging, metrics, and distributed tracing for all API traffic

## Step-by-Step Workflow

### 1. Kong Gateway Setup
```bash
# Docker Compose: Kong + PostgreSQL
version: "3.8"
services:
  kong-db:
    image: postgres:15
    environment:
      POSTGRES_DB: kong
      POSTGRES_USER: kong
      POSTGRES_PASSWORD: kongpass
    volumes:
      - kong-db-data:/var/lib/postgresql/data

  kong-migrations:
    image: kong:3.6
    command: kong migrations bootstrap
    environment:
      KONG_DATABASE: postgres
      KONG_PG_HOST: kong-db
      KONG_PG_DATABASE: kong
      KONG_PG_USER: kong
      KONG_PG_PASSWORD: kongpass
    depends_on: [kong-db]

  kong:
    image: kong:3.6
    environment:
      KONG_DATABASE: postgres
      KONG_PG_HOST: kong-db
      KONG_PG_DATABASE: kong
      KONG_PG_USER: kong
      KONG_PG_PASSWORD: kongpass
      KONG_PROXY_LISTEN: "0.0.0.0:8000, 0.0.0.0:8443 ssl"
      KONG_ADMIN_LISTEN: "0.0.0.0:8001"
      KONG_DECLARATIVE_CONFIG: /kong/declarative/kong.yml
    ports:
      - "8000:8000"   # HTTP proxy
      - "8443:8443"   # HTTPS proxy
      - "8001:8001"   # Admin API
    depends_on: [kong-migrations]

volumes:
  kong-db-data:
```

```yaml
# kong.yml — declarative config (DB-less mode)
_format_version: "3.0"

services:
  - name: user-service
    url: http://user-service:3000
    routes:
      - name: users-route
        paths: ["/api/v1/users"]
        strip_path: false
    plugins:
      - name: rate-limiting
        config:
          minute: 100
          policy: local
      - name: jwt
        config:
          secret_is_base64: false

  - name: product-service
    url: http://product-service:4000
    routes:
      - name: products-route
        paths: ["/api/v1/products"]

consumers:
  - username: mobile-app
    jwt_secrets:
      - secret: "my-jwt-secret-key"
```

### 2. Kong Admin API — Runtime Configuration
```bash
# Create service (points to backend)
curl -X POST http://localhost:8001/services \
  -H "Content-Type: application/json" \
  -d '{
    "name": "orders-service",
    "url": "http://orders-service:5000",
    "connect_timeout": 5000,
    "read_timeout": 30000
  }'

# Create route (maps URL to service)
curl -X POST http://localhost:8001/services/orders-service/routes \
  -H "Content-Type: application/json" \
  -d '{
    "name": "orders-route",
    "paths": ["/api/v1/orders"],
    "methods": ["GET", "POST", "PATCH"],
    "preserve_host": false,
    "strip_path": false
  }'

# Add JWT auth plugin to service
curl -X POST http://localhost:8001/services/orders-service/plugins \
  -d "name=jwt"

# Add rate limiting (100 req/min per consumer)
curl -X POST http://localhost:8001/services/orders-service/plugins \
  -H "Content-Type: application/json" \
  -d '{
    "name": "rate-limiting",
    "config": {
      "minute": 100,
      "hour": 5000,
      "policy": "redis",
      "redis_host": "redis",
      "redis_port": 6379
    }
  }'

# Add request transformer (inject headers before forwarding)
curl -X POST http://localhost:8001/services/orders-service/plugins \
  -H "Content-Type: application/json" \
  -d '{
    "name": "request-transformer",
    "config": {
      "add": {
        "headers": ["X-Gateway-Version:1.0", "X-Request-Source:kong"]
      },
      "remove": {
        "headers": ["Authorization"]
      }
    }
  }'

# Create consumer with API key
curl -X POST http://localhost:8001/consumers \
  -d "username=partner-app"
curl -X POST http://localhost:8001/consumers/partner-app/key-auth \
  -d "key=my-secret-api-key-123"
```

### 3. Custom Node.js API Gateway
```typescript
// gateway/src/server.ts
import Fastify from "fastify";
import { createProxyMiddleware } from "http-proxy-middleware";
import { Redis } from "ioredis";
import jwt from "jsonwebtoken";

const app = Fastify({ logger: true });
const redis = new Redis(process.env.REDIS_URL!);

// Service registry
const SERVICES: Record<string, string> = {
  "/api/users": "http://user-service:3000",
  "/api/orders": "http://order-service:5000",
  "/api/products": "http://product-service:4000",
};

// JWT Authentication middleware
app.addHook("preHandler", async (request, reply) => {
  const publicPaths = ["/health", "/api/auth/login", "/api/auth/register"];
  if (publicPaths.some((p) => request.url.startsWith(p))) return;

  const token = request.headers.authorization?.replace("Bearer ", "");
  if (!token) {
    reply.status(401).send({ error: "Missing authorization header" });
    return;
  }

  try {
    const payload = jwt.verify(token, process.env.JWT_SECRET!) as any;
    (request as any).user = payload;
    (request as any).userId = payload.sub;
  } catch {
    reply.status(401).send({ error: "Invalid or expired token" });
  }
});

// Rate limiting middleware
app.addHook("preHandler", async (request, reply) => {
  const userId = (request as any).userId ?? request.ip;
  const key = `ratelimit:${userId}:${Math.floor(Date.now() / 60000)}`;

  const count = await redis.incr(key);
  if (count === 1) await redis.expire(key, 60);

  const limit = 100;
  reply.header("X-RateLimit-Limit", limit);
  reply.header("X-RateLimit-Remaining", Math.max(0, limit - count));

  if (count > limit) {
    reply.status(429).send({
      error: "Rate limit exceeded",
      retryAfter: 60 - (Date.now() / 1000 % 60),
    });
  }
});

// Request routing and proxying
app.all("/*", async (request, reply) => {
  const url = new URL(request.url, "http://localhost");
  const serviceKey = Object.keys(SERVICES).find((prefix) =>
    url.pathname.startsWith(prefix)
  );

  if (!serviceKey) {
    return reply.status(404).send({ error: "Service not found" });
  }

  const targetUrl = SERVICES[serviceKey] + url.pathname + url.search;

  // Add tracing headers
  const traceId = request.headers["x-trace-id"] ?? crypto.randomUUID();
  const upstreamHeaders: Record<string, string> = {
    ...Object.fromEntries(
      Object.entries(request.headers).filter(([k]) =>
        !["host", "connection"].includes(k)
      )
    ),
    "X-Trace-Id": traceId as string,
    "X-Gateway-Version": "1.0.0",
    "X-User-Id": (request as any).userId ?? "",
    "X-Forwarded-For": request.ip,
  };

  const response = await fetch(targetUrl, {
    method: request.method,
    headers: upstreamHeaders,
    body: request.method !== "GET" ? JSON.stringify(request.body) : undefined,
  });

  reply.status(response.status);
  reply.header("X-Trace-Id", traceId);

  const data = await response.json();
  return reply.send(data);
});

// Health check
app.get("/health", async () => ({ status: "ok", timestamp: new Date().toISOString() }));

app.listen({ port: 8000, host: "0.0.0.0" });
```

### 4. AWS API Gateway Configuration
```typescript
// CDK: AWS API Gateway with Lambda integrations
import * as cdk from "aws-cdk-lib";
import * as apigateway from "aws-cdk-lib/aws-apigateway";
import * as lambda from "aws-cdk-lib/aws-lambda";

export class ApiGatewayStack extends cdk.Stack {
  constructor(scope: cdk.App, id: string) {
    super(scope, id);

    // Create REST API
    const api = new apigateway.RestApi(this, "MyApi", {
      restApiName: "My Service API",
      deployOptions: {
        stageName: "prod",
        throttlingRateLimit: 1000,   // req/sec
        throttlingBurstLimit: 2000,
        loggingLevel: apigateway.MethodLoggingLevel.INFO,
        dataTraceEnabled: true,
        metricsEnabled: true,
      },
      defaultCorsPreflightOptions: {
        allowOrigins: apigateway.Cors.ALL_ORIGINS,
        allowMethods: ["GET", "POST", "PUT", "PATCH", "DELETE"],
        allowHeaders: ["Content-Type", "Authorization", "X-API-Key"],
      },
    });

    // Cognito authorizer
    const authorizer = new apigateway.CognitoUserPoolsAuthorizer(this, "Authorizer", {
      cognitoUserPools: [userPool],
      authorizerName: "CognitoAuth",
      identitySource: "method.request.header.Authorization",
    });

    // Lambda integration with usage plan
    const usersLambda = new lambda.Function(this, "UsersHandler", {
      runtime: lambda.Runtime.NODEJS_20_X,
      code: lambda.Code.fromAsset("dist/users"),
      handler: "index.handler",
    });

    const users = api.root.addResource("users");
    users.addMethod("GET", new apigateway.LambdaIntegration(usersLambda), {
      authorizer,
      authorizationType: apigateway.AuthorizationType.COGNITO,
      apiKeyRequired: true,  // Require API key for metering
    });

    // API Key + Usage Plan (rate limiting per tier)
    const plan = api.addUsagePlan("BasicPlan", {
      name: "Basic",
      throttle: { rateLimit: 10, burstLimit: 20 },
      quota: { limit: 10000, period: apigateway.Period.MONTH },
    });

    const key = api.addApiKey("BasicKey");
    plan.addApiKey(key);
    plan.addApiStage({ api, stage: api.deploymentStage });
  }
}
```

### 5. Request/Response Transformation
```typescript
// Transform legacy API responses to v2 format at the gateway
app.addHook("onSend", async (request, reply, payload) => {
  if (!request.url.startsWith("/api/v2/")) return payload;

  const data = JSON.parse(payload as string);

  // Wrap legacy response in v2 envelope
  const transformed = {
    data: data,
    meta: {
      requestId: reply.getHeader("X-Trace-Id"),
      timestamp: new Date().toISOString(),
      version: "2.0",
    },
  };

  return JSON.stringify(transformed);
});

// Field-level response filtering (remove sensitive fields)
function filterSensitiveFields(obj: any, fields: string[]): any {
  if (Array.isArray(obj)) return obj.map((item) => filterSensitiveFields(item, fields));
  if (obj && typeof obj === "object") {
    return Object.fromEntries(
      Object.entries(obj)
        .filter(([key]) => !fields.includes(key))
        .map(([key, val]) => [key, filterSensitiveFields(val, fields)])
    );
  }
  return obj;
}
```

## Key Commands Reference

```bash
# Kong admin operations
curl http://localhost:8001/  # Check Kong status
curl http://localhost:8001/services  # List services
curl http://localhost:8001/routes    # List routes
curl http://localhost:8001/plugins   # List active plugins
curl http://localhost:8001/consumers # List consumers

# Kong declarative config
kong config init  # Generate sample config
kong config db_import kong.yml  # Import config
kong config db_export > backup.yml  # Export current config

# Test rate limiting
for i in {1..110}; do curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8000/api/users; done

# Kong plugin management
curl -X DELETE http://localhost:8001/plugins/<plugin-id>
curl -X PATCH http://localhost:8001/plugins/<plugin-id> -d "config.minute=200"

# AWS API Gateway
aws apigateway get-rest-apis
aws apigateway get-resources --rest-api-id <id>
aws apigateway create-deployment --rest-api-id <id> --stage-name prod
```

## Common Patterns

### Pattern 1: Canary Routing (10% to v2)
```yaml
# Kong canary plugin
plugins:
  - name: canary
    config:
      percentage: 10     # 10% of traffic goes to canary
      upstream_host: order-service-v2
      upstream_port: 5001
      upstream_uri: /api/orders
      hash: consumer    # Sticky routing by consumer (consistent UX)
```

### Pattern 2: Response Caching
```yaml
# Kong proxy-cache plugin
plugins:
  - name: proxy-cache
    config:
      response_code: [200, 301, 404]
      request_method: [GET, HEAD]
      content_type: ["application/json"]
      cache_ttl: 300     # 5 minutes
      strategy: memory
```

### Pattern 3: Circuit Breaker at Gateway
```typescript
// Track upstream failures, open circuit on threshold
class GatewayCircuitBreaker {
  private failures = new Map<string, number>();
  private openUntil = new Map<string, number>();

  async proxy(service: string, request: Request): Promise<Response> {
    const openUntilTime = this.openUntil.get(service) ?? 0;
    if (Date.now() < openUntilTime) {
      return new Response(JSON.stringify({ error: "Service unavailable" }), {
        status: 503,
        headers: { "Retry-After": String(Math.ceil((openUntilTime - Date.now()) / 1000)) },
      });
    }

    try {
      const response = await fetch(SERVICES[service], { signal: AbortSignal.timeout(5000) });
      this.failures.set(service, 0);  // Reset on success
      return response;
    } catch (error) {
      const fails = (this.failures.get(service) ?? 0) + 1;
      this.failures.set(service, fails);
      if (fails >= 5) {
        this.openUntil.set(service, Date.now() + 30_000);  // Open for 30s
      }
      throw error;
    }
  }
}
```

## Pitfalls to Avoid

1. **Gateway as a monolith**: Don't put business logic in the gateway. The gateway should route, authenticate, rate-limit, and transform — not validate business rules or query databases. Business logic in the gateway creates a centralized point of failure and violates service ownership. Keep it thin.

2. **No timeout configuration**: Without explicit timeouts on upstream connections, a slow backend service causes gateway threads to hang indefinitely. Set `connect_timeout`, `read_timeout`, and `write_timeout` on every service definition. Use circuit breakers to fast-fail when a service is consistently slow or down.

3. **Per-request JWT verification without caching**: Verifying a JWT on every request is fast (~1ms), but calling a remote auth service for token introspection on every request adds 5-50ms latency. Cache token validation results in Redis with the token's TTL as the cache TTL. Invalidate on logout by maintaining a token blocklist.

## Related Skills

- `service-mesh-istio` — Service-to-service security and traffic management (complements gateway)
- `circuit-breaker-patterns` — Upstream resilience patterns
- `redis-patterns` — Rate limiting and token cache storage
- `opentelemetry-instrumentation` — Distributed tracing across gateway + services

## GitNexus Index

```json
{
  "skill": "api-gateway-design",
  "category": "backend",
  "triggers": ["api gateway", "kong", "aws api gateway", "rate limiting", "api proxy", "gateway authentication", "microservices gateway"],
  "outputs": ["kong config", "gateway service", "rate limiter", "auth middleware", "proxy route"],
  "complexity": "high",
  "tools": ["kong", "aws-api-gateway", "fastify", "redis", "jwt", "docker"]
}
```
