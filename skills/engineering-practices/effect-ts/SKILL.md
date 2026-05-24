---
name: effect-ts
description: Build robust TypeScript applications using Effect-TS — a functional programming library for managing side effects, errors, concurrency, and dependencies with full type safety. Use this skill whenever the user mentions Effect, Effect-TS, functional effects in TypeScript, typed error handling, dependency injection with layers, or wants to eliminate runtime surprises through explicit effect types. Trigger for "effect library", "fp-ts alternative", "typed errors TypeScript", or any Effect ecosystem question.
---

# Effect-TS: Functional Effects for TypeScript

Effect is a TypeScript library that makes building complex, concurrent, and resilient applications manageable. It encodes side effects, errors, and dependencies in types — so the compiler catches issues before they reach production.

## Installation

```bash
npm install effect
# Optional ecosystem packages
npm install @effect/platform @effect/schema @effect/sql
```

## Core Concepts

### Effect Type: `Effect<A, E, R>`

```typescript
import { Effect } from 'effect'

// Effect<A, E, R> means:
// A = success type
// E = error type  
// R = required services/context

// Pure value — never fails, needs nothing
const greet = Effect.succeed('Hello, World!')
// type: Effect<string, never, never>

// May fail — typed error, needs nothing
const divide = (a: number, b: number): Effect.Effect<number, Error, never> =>
  b === 0
    ? Effect.fail(new Error('Division by zero'))
    : Effect.succeed(a / b)

// Run an effect
Effect.runPromise(greet).then(console.log) // "Hello, World!"
Effect.runSync(Effect.succeed(42)) // 42
```

### Error Handling

```typescript
import { Effect, Data } from 'effect'

// Tagged errors (recommended — discriminated unions)
class DatabaseError extends Data.TaggedError('DatabaseError')<{
  message: string
  cause?: unknown
}> {}

class NotFoundError extends Data.TaggedError('NotFoundError')<{
  resource: string
  id: string
}> {}

// Function with typed errors
const findUser = (id: string): Effect.Effect<User, NotFoundError | DatabaseError, never> =>
  Effect.tryPromise({
    try: () => db.users.findById(id),
    catch: (e) => new DatabaseError({ message: 'DB query failed', cause: e }),
  }).pipe(
    Effect.flatMap((user) =>
      user
        ? Effect.succeed(user)
        : Effect.fail(new NotFoundError({ resource: 'User', id }))
    )
  )

// Handle errors — compiler ensures all branches covered
const result = findUser('123').pipe(
  Effect.catchTag('NotFoundError', (e) =>
    Effect.succeed({ id: e.id, name: 'Anonymous' })
  ),
  Effect.catchTag('DatabaseError', (e) =>
    Effect.logError(`DB error: ${e.message}`).pipe(
      Effect.flatMap(() => Effect.fail(e))
    )
  )
)
```

### Dependency Injection with Layers

```typescript
import { Effect, Context, Layer } from 'effect'

// Define a service interface
class UserRepository extends Context.Tag('UserRepository')<
  UserRepository,
  {
    findById: (id: string) => Effect.Effect<User | null, DatabaseError>
    create: (data: CreateUserInput) => Effect.Effect<User, DatabaseError>
  }
>() {}

class EmailService extends Context.Tag('EmailService')<
  EmailService,
  {
    send: (to: string, subject: string, body: string) => Effect.Effect<void, EmailError>
  }
>() {}

// Use the services (R type captures requirements)
const createUser = (input: CreateUserInput) =>
  Effect.gen(function* () {
    const repo = yield* UserRepository
    const email = yield* EmailService

    const user = yield* repo.create(input)
    yield* email.send(user.email, 'Welcome!', `Hi ${user.name}!`)
    return user
  })
// type: Effect<User, DatabaseError | EmailError, UserRepository | EmailService>

// Implement services as Layers
const UserRepositoryLive = Layer.succeed(UserRepository, {
  findById: (id) =>
    Effect.tryPromise({
      try: () => prisma.user.findUnique({ where: { id } }),
      catch: (e) => new DatabaseError({ message: String(e) }),
    }),
  create: (data) =>
    Effect.tryPromise({
      try: () => prisma.user.create({ data }),
      catch: (e) => new DatabaseError({ message: String(e) }),
    }),
})

const EmailServiceLive = Layer.succeed(EmailService, {
  send: (to, subject, body) =>
    Effect.tryPromise({
      try: () => sendgrid.send({ to, subject, html: body }),
      catch: (e) => new EmailError({ message: String(e) }),
    }),
})

// Compose layers
const AppLayer = Layer.mergeAll(UserRepositoryLive, EmailServiceLive)

// Run with all dependencies provided
Effect.runPromise(
  createUser({ name: 'Alice', email: 'alice@example.com' }).pipe(
    Effect.provide(AppLayer)
  )
)
```

### Generators for Readable Code

```typescript
import { Effect } from 'effect'

// Effect.gen gives you async/await-like syntax
const processOrder = (orderId: string) =>
  Effect.gen(function* () {
    // yield* unwraps effects and propagates errors
    const order = yield* findOrder(orderId)
    const user = yield* findUser(order.userId)
    const inventory = yield* checkInventory(order.items)

    if (!inventory.available) {
      yield* Effect.fail(new InsufficientStockError({ orderId }))
    }

    const charged = yield* chargePayment(user.paymentMethod, order.total)
    yield* updateInventory(order.items)
    yield* sendConfirmation(user.email, order)

    return { orderId, charged: charged.amount }
  })
```

### Concurrency

```typescript
import { Effect } from 'effect'

// Run effects in parallel
const [users, products, orders] = yield* Effect.all(
  [fetchUsers(), fetchProducts(), fetchOrders()],
  { concurrency: 'unbounded' }
)

// Limit concurrency
const results = yield* Effect.forEach(
  userIds,
  (id) => fetchUserData(id),
  { concurrency: 5 } // max 5 concurrent
)

// Race — first to succeed wins
const fastest = yield* Effect.race(
  fetchFromRegion('us-east'),
  fetchFromRegion('eu-west')
)

// Timeout
const withTimeout = yield* Effect.timeout(
  fetchSlowResource(),
  '5 seconds'
)
```

### Schema Validation

```typescript
import { Schema, Effect } from 'effect'

const UserSchema = Schema.Struct({
  id: Schema.String,
  name: Schema.String.pipe(Schema.minLength(1)),
  email: Schema.String.pipe(Schema.pattern(/^[^@]+@[^@]+\.[^@]+$/)),
  age: Schema.optional(Schema.Number.pipe(Schema.between(0, 150))),
})

type User = Schema.Schema.Type<typeof UserSchema>

// Decode and validate
const parseUser = (input: unknown) =>
  Schema.decodeUnknown(UserSchema)(input).pipe(
    // Schema.decodeUnknown returns Effect<User, ParseError>
    Effect.mapError((e) => new ValidationError({ message: String(e) }))
  )
```

### Retries and Resilience

```typescript
import { Effect, Schedule } from 'effect'

// Retry with exponential backoff
const resilientFetch = (url: string) =>
  Effect.tryPromise({
    try: () => fetch(url).then((r) => r.json()),
    catch: (e) => new NetworkError({ message: String(e) }),
  }).pipe(
    Effect.retry(
      Schedule.exponential('100 millis').pipe(
        Schedule.jittered,
        Schedule.upTo('30 seconds')
      )
    )
  )

// Circuit breaker pattern
const withCircuitBreaker = resilientFetch('https://api.example.com').pipe(
  Effect.timeout('5 seconds'),
  Effect.orElse(() => Effect.succeed(cachedData))
)
```

### Resource Management

```typescript
import { Effect, Scope } from 'effect'

// Acquire/release resources safely (like try-with-resources)
const dbConnection = Effect.acquireRelease(
  Effect.tryPromise({
    try: () => pool.connect(),
    catch: (e) => new DatabaseError({ message: String(e) }),
  }),
  (conn) => Effect.promise(() => conn.release())
)

// Usage — release is guaranteed even on error
const withDb = Effect.scoped(
  Effect.gen(function* () {
    const conn = yield* dbConnection
    return yield* queryWithConnection(conn, 'SELECT * FROM users')
  })
)
```

## Ecosystem

| Package | Purpose |
|---|---|
| `@effect/platform` | HTTP client/server, file system, terminal |
| `@effect/schema` | Schema definition and validation |
| `@effect/sql` | Type-safe SQL with multiple drivers |
| `@effect/rpc` | Remote procedure calls |
| `@effect/opentelemetry` | Tracing and metrics |

## When to Use Effect-TS

- Complex business logic with multiple failure modes
- Applications needing dependency injection without frameworks
- Code where you want the compiler to enforce error handling
- Services requiring retry, timeout, and circuit-breaker patterns
- Any TypeScript codebase where "it compiles = it (mostly) works" is the goal

## GitNexus Index

This skill is indexed by GitNexus for knowledge graph traversal.
Index path: /Users/localuser/.claude/skills/effect-ts/.gitnexus
Last indexed: 2026-05-24
