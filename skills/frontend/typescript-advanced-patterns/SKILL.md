---
name: typescript-advanced-patterns
description: Master advanced TypeScript patterns including discriminated unions, template literal types, conditional types, mapped types, branded types, variance, and builder patterns. Covers type-level programming, infer keyword, and runtime-safe type narrowing.
version: 1.0.0
tags: [typescript, types, advanced, generics, conditional-types, mapped-types, branded-types, type-narrowing, frontend, backend]
---

# TypeScript Advanced Patterns

## Overview

Advanced TypeScript moves beyond basic annotations into type-level programming — computing types from other types, encoding business invariants in the type system, and making illegal states unrepresentable. These patterns eliminate entire categories of bugs at compile time and serve as self-documenting contracts between modules. The key tools are conditional types, mapped types, template literal types, and the `infer` keyword.

## When to Use

- Modeling state machines or domain entities where certain combinations are impossible (discriminated unions)
- Building reusable library utilities that need to be polymorphic over shapes and keys
- Preventing passing raw primitives where a validated/branded type is required (branded types)
- Creating type-safe event systems or API clients from a single source of truth
- Eliminating runtime type checks by proving constraints at compile time
- Refactoring a large codebase and needing precise impact analysis through the type system

## Step-by-Step Workflow

### 1. Discriminated Unions and Exhaustive Checks

```typescript
// Model state machines — impossible states become type errors
type OrderStatus =
  | { status: "pending"; createdAt: Date }
  | { status: "paid"; paidAt: Date; transactionId: string }
  | { status: "shipped"; shippedAt: Date; trackingNumber: string }
  | { status: "delivered"; deliveredAt: Date }
  | { status: "cancelled"; cancelledAt: Date; reason: string };

// exhaustive() forces the switch to handle ALL branches
function assertNever(x: never, message = "Unexpected value"): never {
  throw new Error(`${message}: ${JSON.stringify(x)}`);
}

function getOrderMessage(order: OrderStatus): string {
  switch (order.status) {
    case "pending":
      return `Order placed at ${order.createdAt.toLocaleDateString()}`;
    case "paid":
      return `Payment confirmed: ${order.transactionId}`;
    case "shipped":
      return `Tracking: ${order.trackingNumber}`;
    case "delivered":
      return `Delivered on ${order.deliveredAt.toLocaleDateString()}`;
    case "cancelled":
      return `Cancelled: ${order.reason}`;
    default:
      return assertNever(order); // Compile error if any case is missing
  }
}

// Pattern: Result type for explicit error handling (no exceptions)
type Result<T, E = Error> =
  | { ok: true; value: T }
  | { ok: false; error: E };

function ok<T>(value: T): Result<T, never> {
  return { ok: true, value };
}
function err<E>(error: E): Result<never, E> {
  return { ok: false, error };
}

async function fetchUser(id: string): Promise<Result<User, "not-found" | "network-error">> {
  try {
    const user = await db.users.findById(id);
    return user ? ok(user) : err("not-found");
  } catch {
    return err("network-error");
  }
}

const result = await fetchUser("123");
if (result.ok) {
  console.log(result.value.name);  // TypeScript knows this is User
} else {
  console.error(result.error);     // TypeScript knows this is "not-found" | "network-error"
}
```

### 2. Branded Types — Prevent Primitive Confusion

```typescript
// Without branding: easy to swap userId and orderId (both strings)
// With branding: type error at compile time

declare const __brand: unique symbol;
type Brand<T, B> = T & { readonly [__brand]: B };

type UserId = Brand<string, "UserId">;
type OrderId = Brand<string, "OrderId">;
type Email = Brand<string, "Email">;
type PositiveInt = Brand<number, "PositiveInt">;

// Smart constructors validate at the boundary
function makeUserId(id: string): UserId {
  if (!id.startsWith("usr_")) throw new Error("Invalid user ID format");
  return id as UserId;
}

function makeEmail(raw: string): Email {
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(raw)) throw new Error("Invalid email");
  return raw.toLowerCase() as Email;
}

function makePositiveInt(n: number): PositiveInt {
  if (!Number.isInteger(n) || n <= 0) throw new Error("Must be positive integer");
  return n as PositiveInt;
}

// Functions require the branded type — can't accidentally swap
function getOrdersForUser(userId: UserId): Promise<Order[]> { /* ... */ }
function cancelOrder(orderId: OrderId): Promise<void> { /* ... */ }

const uid = makeUserId("usr_abc123");
const oid = makeOrderId("ord_xyz789");

getOrdersForUser(uid);   // OK
getOrdersForUser(oid);   // TYPE ERROR: OrderId not assignable to UserId
cancelOrder(uid);        // TYPE ERROR: UserId not assignable to OrderId
```

### 3. Conditional Types and infer

```typescript
// Extract the resolved type from a Promise
type Awaited<T> = T extends Promise<infer U> ? Awaited<U> : T;

// Extract function parameters and return types
type Parameters<T extends (...args: any) => any> =
  T extends (...args: infer P) => any ? P : never;

type ReturnType<T extends (...args: any) => any> =
  T extends (...args: any) => infer R ? R : never;

// Deep partial — make every nested property optional
type DeepPartial<T> = T extends object
  ? { [K in keyof T]?: DeepPartial<T[K]> }
  : T;

// Flatten nested arrays
type Flatten<T> = T extends Array<infer Item> ? Item : T;

// Extract keys by value type
type KeysOfType<Obj, Type> = {
  [K in keyof Obj]: Obj[K] extends Type ? K : never
}[keyof Obj];

interface Config {
  name: string;
  port: number;
  debug: boolean;
  timeout: number;
}

type StringKeys = KeysOfType<Config, string>;   // "name"
type NumberKeys = KeysOfType<Config, number>;   // "port" | "timeout"

// Build a setter type from an object
type Setters<T> = {
  [K in keyof T as `set${Capitalize<string & K>}`]: (value: T[K]) => void;
};

type ConfigSetters = Setters<Config>;
// { setName: (value: string) => void; setPort: (value: number) => void; ... }
```

### 4. Template Literal Types

```typescript
// Type-safe event system from a map of event payloads
type EventMap = {
  "user:created": { userId: string; email: string };
  "order:placed": { orderId: string; total: number };
  "order:cancelled": { orderId: string; reason: string };
};

type EventName = keyof EventMap;

// Create handler type: on("user:created", handler) is fully typed
type EventHandler<E extends EventName> = (payload: EventMap[E]) => void;

class EventBus {
  private handlers = new Map<string, Set<Function>>();

  on<E extends EventName>(event: E, handler: EventHandler<E>): void {
    if (!this.handlers.has(event)) this.handlers.set(event, new Set());
    this.handlers.get(event)!.add(handler);
  }

  emit<E extends EventName>(event: E, payload: EventMap[E]): void {
    this.handlers.get(event)?.forEach(h => h(payload));
  }
}

const bus = new EventBus();
bus.on("user:created", ({ userId, email }) => {  // ← typed payload
  console.log(`New user: ${userId}, ${email}`);
});
bus.emit("user:created", { userId: "u1", email: "a@b.com" });  // ← validated

// Route type-safety from path strings
type RouteParams<T extends string> =
  T extends `${string}:${infer Param}/${infer Rest}`
    ? { [K in Param | keyof RouteParams<Rest>]: string }
    : T extends `${string}:${infer Param}`
    ? { [K in Param]: string }
    : {};

type Params = RouteParams<"/users/:userId/orders/:orderId">;
// { userId: string; orderId: string }

function buildUrl<T extends string>(
  template: T,
  params: RouteParams<T>
): string {
  return Object.entries(params).reduce(
    (url, [key, val]) => url.replace(`:${key}`, val as string),
    template
  );
}

const url = buildUrl("/users/:userId/orders/:orderId", {
  userId: "u123",
  orderId: "o456"
});
// "/users/u123/orders/o456"
```

### 5. Builder Pattern with Method Chaining

```typescript
// Type-safe query builder — each method returns a narrowed type
interface QueryConfig {
  table?: string;
  conditions?: string[];
  limit?: number;
  offset?: number;
  orderBy?: string;
}

type RequiredFields<T, K extends keyof T> = T & Required<Pick<T, K>>;

class QueryBuilder<Config extends QueryConfig = QueryConfig> {
  constructor(private config: Config = {} as Config) {}

  from<T extends string>(table: T): QueryBuilder<Config & { table: T }> {
    return new QueryBuilder({ ...this.config, table });
  }

  where(condition: string): QueryBuilder<Config> {
    return new QueryBuilder({
      ...this.config,
      conditions: [...(this.config.conditions ?? []), condition],
    });
  }

  limitTo(n: number): QueryBuilder<Config & { limit: number }> {
    return new QueryBuilder({ ...this.config, limit: n });
  }

  // build() only available when 'table' is set
  build(
    this: QueryBuilder<RequiredFields<Config, "table">>
  ): string {
    const { table, conditions, limit, offset, orderBy } = this.config;
    let sql = `SELECT * FROM ${table}`;
    if (conditions?.length) sql += ` WHERE ${conditions.join(" AND ")}`;
    if (orderBy) sql += ` ORDER BY ${orderBy}`;
    if (limit !== undefined) sql += ` LIMIT ${limit}`;
    if (offset !== undefined) sql += ` OFFSET ${offset}`;
    return sql;
  }
}

// Usage:
const query = new QueryBuilder()
  .from("users")
  .where("active = true")
  .limitTo(10)
  .build();  // OK — table is set

const broken = new QueryBuilder()
  .where("active = true")
  .build();  // TYPE ERROR: build() not available without .from()
```

## Key Commands Reference

```bash
# TypeScript compiler checks
npx tsc --noEmit               # Type check without emitting JS
npx tsc --strict               # Enable all strict checks
npx tsc --exactOptionalPropertyTypes  # Stricter optional handling

# Useful tsconfig.json strict settings
# "strict": true
# "noUncheckedIndexedAccess": true    # arr[0] is T | undefined
# "exactOptionalPropertyTypes": true  # {} !== { x?: undefined }
# "noImplicitOverride": true          # Force 'override' keyword

# Type introspection in code
type Expand<T> = T extends infer U ? { [K in keyof U]: U[K] } : never;
// Use Expand<MyComplexType> in IDE to see the fully expanded type

# ts-expect-error for forced type tests
// @ts-expect-error  (preferred over @ts-ignore — errors if type IS assignable)
const x: string = 42;

# Type coverage tool
npx type-coverage --detail --strict  # % of any-free code
```

## Common Patterns

### Pattern 1: Opaque Types for API Boundaries

```typescript
// Prevent leaking internal types across module boundaries
// api/types.ts — public surface
export type UserResponse = {
  readonly id: string;
  readonly email: string;
  readonly createdAt: string;  // ISO string for JSON
};

// Never expose database models to API callers
import type { User } from "@/db/models";  // Only used internally

export function toUserResponse(user: User): UserResponse {
  return {
    id: user.id,
    email: user.email,
    createdAt: user.createdAt.toISOString(),
  };
}
```

### Pattern 2: Satisfies Operator for Literal Inference

```typescript
// 'satisfies' validates shape WITHOUT widening types
const palette = {
  red: [255, 0, 0],
  green: "#00ff00",
  blue: [0, 0, 255],
} satisfies Record<string, string | number[]>;

// palette.red is inferred as [number, number, number], not (string | number[])
// palette.green is inferred as "#00ff00" (literal), not string
palette.red.map(x => x * 2);  // OK — TypeScript knows it's an array
palette.green.toUpperCase();   // OK — TypeScript knows it's a string
```

### Pattern 3: Variadic Tuple Types

```typescript
// Type-safe pipe/compose functions
type Pipe<T extends any[]> = T extends [infer First, ...infer Rest]
  ? Rest extends [(arg: First) => infer Next, ...any[]]
    ? Pipe<[Next, ...Rest]>
    : First
  : never;

function pipe<A>(value: A): A;
function pipe<A, B>(value: A, fn1: (a: A) => B): B;
function pipe<A, B, C>(value: A, fn1: (a: A) => B, fn2: (b: B) => C): C;
function pipe<A, B, C, D>(
  value: A,
  fn1: (a: A) => B,
  fn2: (b: B) => C,
  fn3: (c: C) => D
): D;
function pipe(value: any, ...fns: Function[]) {
  return fns.reduce((acc, fn) => fn(acc), value);
}

const result = pipe(
  "hello world",
  (s: string) => s.toUpperCase(),        // string
  (s: string) => s.split(" "),           // string[]
  (arr: string[]) => arr.join("-"),      // string
);
// result: string = "HELLO-WORLD"
```

## Pitfalls to Avoid

1. **Using `any` to escape the type system**: Each `any` creates a hole where runtime errors can sneak through. Prefer `unknown` (must narrow before use), `never` (for impossible branches), or proper generics. If you need to work with truly unknown shapes, use `unknown` + type guards or Zod for validation at the boundary.

2. **Over-engineering with conditional types when simpler alternatives exist**: Complex chains of conditional types are hard to read and debug. Before writing a conditional type, check if a mapped type, intersection, or discriminated union solves it more clearly. Type complexity compounds — every layer of indirection makes inference errors harder to understand.

3. **Forgetting that TypeScript types are structural, not nominal**: Two identical-shaped interfaces are assignable to each other even if named differently. This is why branded types matter for domain primitives — without them, a `string` for userId and a `string` for orderId are interchangeable to the type checker.

## Related Skills

- `typescript-expert` — Day-to-day TypeScript best practices and patterns
- `zod-expert` — Runtime validation that complements compile-time TypeScript
- `api-contracts-and-zod-validation` — End-to-end type safety from API to client
- `react-best-practices` — TypeScript in React component patterns
- `functional-python` — Functional programming concepts that translate to TypeScript

## GitNexus Index

```json
{
  "skill": "typescript-advanced-patterns",
  "category": "backend",
  "triggers": ["discriminated union", "branded types", "conditional types", "mapped types", "template literal types", "infer keyword", "type narrowing", "builder pattern typescript", "exhaustive check", "result type typescript"],
  "outputs": ["Brand<T,B>", "Result<T,E>", "assertNever", "DeepPartial", "KeysOfType", "EventBus", "QueryBuilder", "RouteParams", "makeUserId"],
  "complexity": "high",
  "tools": ["typescript", "tsc", "type-coverage"]
}
```
