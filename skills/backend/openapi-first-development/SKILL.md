---
name: openapi-first-development
description: Design APIs with OpenAPI 3.1 first, then generate server stubs, client SDKs, validation middleware, and documentation. Covers schema design, Zod/JSON Schema integration, contract testing with Dredd/Schemathesis, and type-safe API clients.
version: 1.0.0
tags: [openapi, api-design, swagger, code-generation, contract-testing, typescript, python, fastapi, backend]
---

# OpenAPI-First Development

## Overview

OpenAPI-first development treats the API specification as the single source of truth — written before any implementation code. This contract-first approach enables parallel frontend/backend development, automatic SDK generation, request/response validation, and contract testing. OpenAPI 3.1 (aligned with JSON Schema) supports full bidirectional type generation; tools like openapi-typescript, fastapi, and oapi-codegen consume the spec and produce type-safe implementations.

## When to Use

- Multiple teams (frontend, mobile, third-party) consuming the same API
- Building a public API where the contract must be stable and documented
- Wanting auto-generated SDKs in TypeScript, Python, Go, or Java
- Enforcing request/response validation without writing it manually
- Contract testing to verify implementations match the spec
- API versioning where you need to detect breaking changes automatically

## Step-by-Step Workflow

### 1. Writing the OpenAPI 3.1 Specification

```yaml
# openapi.yaml — the source of truth
openapi: "3.1.0"
info:
  title: Order Management API
  version: "1.0.0"
  description: Manages orders and fulfillment for the e-commerce platform

servers:
  - url: https://api.acme.com/v1
    description: Production
  - url: http://localhost:8000/v1
    description: Local development

security:
  - bearerAuth: []

paths:
  /orders:
    get:
      operationId: listOrders
      summary: List orders for the authenticated user
      tags: [orders]
      parameters:
        - name: status
          in: query
          schema:
            $ref: "#/components/schemas/OrderStatus"
        - name: page
          in: query
          schema:
            type: integer
            minimum: 1
            default: 1
        - name: limit
          in: query
          schema:
            type: integer
            minimum: 1
            maximum: 100
            default: 20
      responses:
        "200":
          description: Paginated list of orders
          content:
            application/json:
              schema:
                $ref: "#/components/schemas/OrderListResponse"
        "401":
          $ref: "#/components/responses/Unauthorized"

    post:
      operationId: createOrder
      summary: Create a new order
      tags: [orders]
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: "#/components/schemas/CreateOrderRequest"
      responses:
        "201":
          description: Order created successfully
          content:
            application/json:
              schema:
                $ref: "#/components/schemas/Order"
        "400":
          $ref: "#/components/responses/ValidationError"

  /orders/{orderId}:
    get:
      operationId: getOrder
      summary: Get a specific order
      tags: [orders]
      parameters:
        - $ref: "#/components/parameters/OrderId"
      responses:
        "200":
          content:
            application/json:
              schema:
                $ref: "#/components/schemas/Order"
        "404":
          $ref: "#/components/responses/NotFound"

components:
  securitySchemes:
    bearerAuth:
      type: http
      scheme: bearer
      bearerFormat: JWT

  parameters:
    OrderId:
      name: orderId
      in: path
      required: true
      schema:
        type: string
        format: uuid

  schemas:
    OrderStatus:
      type: string
      enum: [pending, paid, shipped, delivered, cancelled]

    Order:
      type: object
      required: [id, status, total, createdAt, items]
      properties:
        id:
          type: string
          format: uuid
        status:
          $ref: "#/components/schemas/OrderStatus"
        total:
          type: number
          format: double
          minimum: 0
        createdAt:
          type: string
          format: date-time
        items:
          type: array
          items:
            $ref: "#/components/schemas/OrderItem"

    OrderItem:
      type: object
      required: [productId, quantity, price]
      properties:
        productId:
          type: string
          format: uuid
        quantity:
          type: integer
          minimum: 1
        price:
          type: number
          minimum: 0

    CreateOrderRequest:
      type: object
      required: [items]
      properties:
        items:
          type: array
          minItems: 1
          items:
            type: object
            required: [productId, quantity]
            properties:
              productId:
                type: string
                format: uuid
              quantity:
                type: integer
                minimum: 1

    OrderListResponse:
      type: object
      required: [items, total, page, limit]
      properties:
        items:
          type: array
          items:
            $ref: "#/components/schemas/Order"
        total:
          type: integer
        page:
          type: integer
        limit:
          type: integer

  responses:
    Unauthorized:
      description: Authentication required
      content:
        application/json:
          schema:
            $ref: "#/components/schemas/Error"
    NotFound:
      description: Resource not found
      content:
        application/json:
          schema:
            $ref: "#/components/schemas/Error"
    ValidationError:
      description: Request validation failed
      content:
        application/json:
          schema:
            $ref: "#/components/schemas/ValidationErrorResponse"

    Error:
      type: object
      required: [error, message]
      properties:
        error:
          type: string
        message:
          type: string

    ValidationErrorResponse:
      type: object
      required: [error, details]
      properties:
        error:
          type: string
        details:
          type: array
          items:
            type: object
            properties:
              field:
                type: string
              message:
                type: string
```

### 2. TypeScript Client Generation

```bash
# npm install openapi-typescript openapi-fetch
# Generate types from spec
npx openapi-typescript openapi.yaml -o src/api/types.ts
```

```typescript
// src/api/client.ts — type-safe API client
import createClient from "openapi-fetch";
import type { paths } from "./types";  // Generated from openapi-typescript

const client = createClient<paths>({
  baseUrl: process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:8000/v1",
  headers: { "Content-Type": "application/json" },
});

// Add auth token
export function createAuthenticatedClient(token: string) {
  return createClient<paths>({
    baseUrl: process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:8000/v1",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${token}`,
    },
  });
}

// Usage — fully type-safe with autocomplete
async function listOrders(token: string, status?: string) {
  const api = createAuthenticatedClient(token);
  const { data, error } = await api.GET("/orders", {
    params: { query: { status, limit: 20, page: 1 } },
  });

  if (error) throw new Error(`Failed to list orders: ${error.message}`);
  return data;  // Typed as OrderListResponse
}

async function createOrder(token: string, items: Array<{ productId: string; quantity: number }>) {
  const api = createAuthenticatedClient(token);
  const { data, error } = await api.POST("/orders", {
    body: { items },
  });

  if (error) throw new Error(error.message);
  return data;  // Typed as Order
}
```

### 3. FastAPI Implementation (Python Auto-Validates from Spec)

```python
# pip install fastapi[standard] pydantic
# FastAPI generates OpenAPI automatically from Pydantic models
# OR validate against an external spec with fastapi-openapi-utils

from fastapi import FastAPI, HTTPException, Depends, Query
from pydantic import BaseModel, UUID4, Field
from datetime import datetime
from enum import Enum
import uuid

app = FastAPI(
    title="Order Management API",
    version="1.0.0",
    openapi_url="/openapi.json"
)

class OrderStatus(str, Enum):
    pending = "pending"
    paid = "paid"
    shipped = "shipped"
    delivered = "delivered"
    cancelled = "cancelled"

class OrderItem(BaseModel):
    product_id: UUID4
    quantity: int = Field(ge=1)
    price: float = Field(ge=0)

class Order(BaseModel):
    id: UUID4
    status: OrderStatus
    total: float = Field(ge=0)
    created_at: datetime
    items: list[OrderItem]

class CreateOrderRequest(BaseModel):
    items: list[dict]  # Validated below

class OrderListResponse(BaseModel):
    items: list[Order]
    total: int
    page: int
    limit: int

@app.get("/v1/orders", response_model=OrderListResponse)
async def list_orders(
    status: OrderStatus | None = Query(None),
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    current_user=Depends(get_current_user)
):
    orders = await db.get_orders(user_id=current_user.id, status=status,
                                  page=page, limit=limit)
    return OrderListResponse(**orders)

@app.post("/v1/orders", response_model=Order, status_code=201)
async def create_order(
    request: CreateOrderRequest,
    current_user=Depends(get_current_user)
):
    order = await db.create_order(user_id=current_user.id, items=request.items)
    return order
```

### 4. Contract Testing with Schemathesis

```bash
# pip install schemathesis
# Automatically tests all endpoints against the OpenAPI spec

# Run against local server
schemathesis run http://localhost:8000/openapi.json \
  --checks all \
  --header "Authorization: Bearer <test-token>"

# Stateful testing (uses response data in subsequent requests)
schemathesis run http://localhost:8000/openapi.json \
  --stateful=links \
  --hypothesis-max-examples=50

# CI integration
schemathesis run openapi.yaml \
  --base-url http://localhost:8000 \
  --checks not_a_server_error \
  --exitcode-on-errors 1
```

```python
# tests/test_api_contract.py — pytest integration
import schemathesis
from schemathesis.checks import not_a_server_error, response_conformance

schema = schemathesis.from_file("openapi.yaml", base_url="http://localhost:8000")

@schema.parametrize()
def test_api_conforms_to_spec(case):
    """Every endpoint returns responses matching the OpenAPI spec."""
    response = case.call()
    case.validate_response(response)

@schema.parametrize(endpoint="/orders")
def test_orders_endpoint(case):
    """Test orders endpoint specifically with auth."""
    response = case.call(headers={"Authorization": "Bearer test-token"})
    case.validate_response(response, checks=[not_a_server_error, response_conformance])
```

## Key Commands Reference

```bash
# Validate OpenAPI spec
npx @redocly/cli lint openapi.yaml
npx @redocly/cli bundle openapi.yaml -o dist/openapi.yaml  # Bundle $refs

# Generate TypeScript types
npx openapi-typescript openapi.yaml -o src/api/types.ts

# Generate Python client
pip install openapi-generator-cli
openapi-generator-cli generate \
  -i openapi.yaml \
  -g python \
  -o generated/python-client

# Generate Go client
openapi-generator-cli generate \
  -i openapi.yaml \
  -g go \
  -o generated/go-client

# Serve documentation
npx @redocly/cli preview-docs openapi.yaml
# Opens Redoc UI at http://localhost:8080

# Detect breaking changes between versions
npx @optic/api-check diff openapi-v1.yaml openapi-v2.yaml

# Contract testing
schemathesis run openapi.yaml --base-url http://localhost:8000 --checks all

# Mock server from spec (for frontend dev without backend)
npx prism mock openapi.yaml
# Serves mock responses at http://localhost:4010
```

## Common Patterns

### Pattern 1: Zod Schema from OpenAPI Types

```typescript
// Generate Zod schemas matching OpenAPI types for runtime validation
import { z } from "zod";
import type { components } from "./types";  // From openapi-typescript

// Create Zod schema matching the OpenAPI CreateOrderRequest schema
const CreateOrderRequestSchema = z.object({
  items: z.array(z.object({
    productId: z.string().uuid(),
    quantity: z.number().int().min(1),
  })).min(1),
});

// Use in Next.js Server Action
export async function submitOrder(formData: FormData) {
  const raw = Object.fromEntries(formData);
  const result = CreateOrderRequestSchema.safeParse(raw);
  if (!result.success) {
    return { error: result.error.flatten() };
  }
  // result.data is typed as z.infer<typeof CreateOrderRequestSchema>
  return createOrder(result.data);
}
```

### Pattern 2: OpenAPI Mock Server in Tests

```typescript
// Use Prism as a mock server in integration tests
import { createServer } from "@stoplight/prism-http";
import { readFileSync } from "fs";

let mockServer: any;

beforeAll(async () => {
  mockServer = await createServer(
    JSON.parse(readFileSync("openapi.yaml", "utf-8")),
    { mock: { dynamic: true } }  // Dynamic examples
  );
  await mockServer.listen(4010);
});

afterAll(() => mockServer.close());

test("client handles 404 correctly", async () => {
  // Prism returns 404 for /orders/nonexistent based on spec
  const result = await getOrder("00000000-0000-0000-0000-000000000000");
  expect(result).toBeNull();
});
```

### Pattern 3: Breaking Change Detection in CI

```yaml
# .github/workflows/api-check.yml
name: API Contract Check
on: [pull_request]

jobs:
  check-breaking-changes:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with: { fetch-depth: 0 }

      - name: Install Optic
        run: npm install -g @useoptic/optic

      - name: Check for breaking changes
        run: |
          git show HEAD~1:openapi.yaml > /tmp/old-spec.yaml
          optic diff /tmp/old-spec.yaml openapi.yaml \
            --check breaking-changes \
            --fail-on-breaking-changes
```

## Pitfalls to Avoid

1. **Writing the spec after the implementation**: The entire value of OpenAPI-first is lost when the spec is reverse-engineered from existing code. Specs written after implementation tend to drift from the real behavior, miss edge cases, and become documentation-only artifacts rather than contracts. Write the spec first, review it with consumers, then generate stubs and implement.

2. **Not using `operationId` on every operation**: Without `operationId`, generated SDK method names become `get_v1_orders_order_id_get` instead of `getOrder`. Always set unique, descriptive operation IDs — they become the method names in every generated SDK and are used in contract test reports.

3. **Defining errors as generic `{}` objects**: Vague error schemas (`type: object`) provide no value for SDK consumers who need to handle specific error shapes. Define concrete error response schemas with required fields (`error`, `message`, `details`), reference them in every error response, and generate error types that SDK users can type-check in catch blocks.

## Related Skills

- `api-design-reviewer` — Code review and design feedback for APIs
- `api-security-hardening` — Security overlays for OpenAPI specs
- `grpc-services` — Alternative API design for internal services
- `zod-expert` — Zod schema patterns that complement OpenAPI types
- `api-gateway-design` — Gateway layer that validates against OpenAPI specs

## GitNexus Index

```json
{
  "skill": "openapi-first-development",
  "category": "backend",
  "triggers": ["openapi", "swagger", "api-first", "contract testing", "openapi-typescript", "API specification", "schemathesis", "prism mock server", "breaking changes API", "SDK generation", "openapi 3.1"],
  "outputs": ["openapi.yaml spec", "openapi-typescript types", "createClient<paths>", "schemathesis run", "Schemathesis test", "CreateOrderRequestSchema", "optic diff breaking-changes"],
  "complexity": "medium",
  "tools": ["openapi", "openapi-typescript", "openapi-fetch", "schemathesis", "prism", "fastapi", "redocly", "optic"]
}
```
