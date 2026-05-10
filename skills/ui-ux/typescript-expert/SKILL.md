---
name: typescript-expert
description: >
  Advanced TypeScript patterns: generics, utility types, conditional types, template literals, discriminated unions, and type narrowing. Triggers on: TypeScript generics, Omit, Pick, Partial, Record, infer, satisfies, as const, discriminated union, keyof typeof.
---

# TypeScript Expert

## When to Use

Trigger this skill whenever you need advanced TypeScript patterns beyond basic typing: building reusable generic utilities, modeling complex domain types with discriminated unions, narrowing types safely, or writing type-safe API integrations.

---

## Utility Type Cheat Sheet

```typescript
// ─── BUILT-IN UTILITY TYPES ───────────────────────────────────────────────────

type User = {
  id: string
  name: string
  email: string
  password: string
  createdAt: Date
  role: 'admin' | 'user' | 'guest'
}

// Pick — select specific keys
type PublicUser = Pick<User, 'id' | 'name' | 'email'>

// Omit — remove specific keys
type SafeUser = Omit<User, 'password'>

// Partial — all keys optional
type UserUpdate = Partial<User>

// Required — all keys required (reverses Partial)
type StrictUser = Required<User>

// Record — map a union of keys to a type
type RolePermissions = Record<User['role'], string[]>
const perms: RolePermissions = {
  admin: ['read', 'write', 'delete'],
  user: ['read', 'write'],
  guest: ['read'],
}

// Extract — keep union members assignable to type
type AdminOrUser = Extract<User['role'], 'admin' | 'user'>  // 'admin' | 'user'

// Exclude — remove union members assignable to type
type NonAdmin = Exclude<User['role'], 'admin'>  // 'user' | 'guest'

// ReturnType — infer a function's return type
async function fetchUser(id: string): Promise<User> { /* ... */ return {} as User }
type FetchResult = ReturnType<typeof fetchUser>  // Promise<User>
type Awaited<T> = T extends Promise<infer R> ? R : T
type ResolvedUser = Awaited<FetchResult>  // User

// Parameters — infer a function's parameter tuple
function createEvent(name: string, data: Record<string, unknown>, ts: Date) {}
type CreateEventParams = Parameters<typeof createEvent>
// [name: string, data: Record<string, unknown>, ts: Date]

// NonNullable — removes null and undefined
type MaybeString = string | null | undefined
type DefiniteString = NonNullable<MaybeString>  // string
```

---

## Generic Constraints

```typescript
// Basic constraint
function getProperty<T, K extends keyof T>(obj: T, key: K): T[K] {
  return obj[key]
}

// Multiple constraints with intersection
function merge<T extends object, U extends object>(a: T, b: U): T & U {
  return { ...a, ...b }
}

// Constrain to objects with a specific shape
function findById<T extends { id: string }>(items: T[], id: string): T | undefined {
  return items.find(item => item.id === id)
}

// Default generic parameters
type ApiResponse<T = unknown> = {
  data: T
  error: string | null
  status: number
}

// Constrain to known keys of another type
type SubsetOf<T, K extends keyof T> = Pick<T, K>

// Builder pattern with generics
class QueryBuilder<T extends Record<string, unknown>> {
  private filters: Partial<T> = {}

  where<K extends keyof T>(key: K, value: T[K]): this {
    this.filters[key] = value
    return this
  }

  build(): Partial<T> {
    return this.filters
  }
}
```

---

## Conditional Types with `infer`

```typescript
// Unwrap a Promise
type Awaited<T> = T extends Promise<infer R> ? R : T

// Unwrap an array
type ElementType<T> = T extends (infer E)[] ? E : never

// Extract the first argument type of a function
type FirstParam<T extends (...args: any[]) => any> =
  T extends (first: infer F, ...rest: any[]) => any ? F : never

// Deep readonly (recursive conditional type)
type DeepReadonly<T> = {
  readonly [K in keyof T]: T[K] extends object ? DeepReadonly<T[K]> : T[K]
}

// Flatten nested arrays
type Flatten<T> = T extends Array<infer Item> ? Item : T

// Extract route params from a path string
type ExtractRouteParams<T extends string> =
  T extends `${infer _Start}:${infer Param}/${infer Rest}`
    ? Param | ExtractRouteParams<`/${Rest}`>
    : T extends `${infer _Start}:${infer Param}`
    ? Param
    : never

// Usage: '/users/:userId/posts/:postId' → 'userId' | 'postId'
type Params = ExtractRouteParams<'/users/:userId/posts/:postId'>

// Conditional return types based on input
function parse<T extends string | number>(
  value: T
): T extends string ? number : string {
  return (typeof value === 'string' ? Number(value) : String(value)) as any
}
```

---

## Template Literal Types

```typescript
// Event name generation
type EventName<T extends string> = `on${Capitalize<T>}`
type ClickEvent = EventName<'click'>  // 'onClick'

// CSS property keys
type CSSProperty = 'margin' | 'padding' | 'border'
type CSSDirection = 'Top' | 'Right' | 'Bottom' | 'Left'
type DirectionalCSS = `${CSSProperty}${CSSDirection}`
// 'marginTop' | 'marginRight' | ... | 'borderLeft'

// API route construction
type ApiVersion = 'v1' | 'v2'
type Resource = 'users' | 'posts' | 'comments'
type ApiRoute = `/${ApiVersion}/${Resource}`  // '/v1/users' | '/v2/posts' | ...

// Type-safe event emitter
type Events = {
  'user:created': { user: User }
  'user:deleted': { userId: string }
  'post:published': { postId: string; title: string }
}

type EventKey = keyof Events
type EventPayload<K extends EventKey> = Events[K]

function emit<K extends EventKey>(event: K, payload: EventPayload<K>): void {
  // implementation
}

emit('user:created', { user: {} as User })  // fully typed
// emit('user:created', { userId: '1' })   // TS error ✓
```

---

## Discriminated Unions

```typescript
// Pattern: shared discriminant field with literal type
type LoadingState = { status: 'loading' }
type SuccessState<T> = { status: 'success'; data: T }
type ErrorState = { status: 'error'; error: Error; code: number }

type AsyncState<T> = LoadingState | SuccessState<T> | ErrorState

// Narrowing in a component
function UserCard({ state }: { state: AsyncState<User> }) {
  if (state.status === 'loading') return <Skeleton />
  if (state.status === 'error') return <ErrorMessage error={state.error} />
  // TypeScript knows state.data: User here
  return <div>{state.data.name}</div>
}

// Action discriminated unions (Redux-style)
type Action =
  | { type: 'INCREMENT'; payload: number }
  | { type: 'DECREMENT'; payload: number }
  | { type: 'RESET' }

function reducer(state: number, action: Action): number {
  switch (action.type) {
    case 'INCREMENT': return state + action.payload  // payload typed
    case 'DECREMENT': return state - action.payload
    case 'RESET': return 0
    // No 'payload' access here — TS enforces it ✓
  }
}
```

---

## Exhaustive Checks

```typescript
// Use never to ensure all union members are handled
function assertNever(value: never): never {
  throw new Error(`Unhandled case: ${JSON.stringify(value)}`)
}

type Shape = 
  | { kind: 'circle'; radius: number }
  | { kind: 'rect'; width: number; height: number }
  | { kind: 'triangle'; base: number; height: number }

function area(shape: Shape): number {
  switch (shape.kind) {
    case 'circle': return Math.PI * shape.radius ** 2
    case 'rect': return shape.width * shape.height
    case 'triangle': return (shape.base * shape.height) / 2
    default: return assertNever(shape)  // TS error if a case is missing ✓
  }
}
```

---

## `satisfies` Operator

```typescript
// satisfies: validates type without widening — preserves literal inference

// Problem with explicit annotation: loses specific types
const palette1: Record<string, string[]> = {
  red: ['#FF0000'],
  green: ['#00FF00'],
}
palette1.red.toUpperCase()  // error — TS widens to string[], doesn't know it's string

// satisfies: validates shape AND keeps literals
const palette = {
  red: ['#FF0000', '#CC0000'],
  green: '#00FF00',           // also valid — can be string too
  blue: [0, 0, 255],
} satisfies Record<string, string | string[] | number[]>

// TypeScript infers the specific types:
palette.red.map(c => c.toUpperCase())  // ✓ known as string[]
palette.green.toUpperCase()             // ✓ known as string

// Use with config objects
const routes = {
  home: '/',
  user: '/users/:id',
  post: '/posts/:slug',
} satisfies Record<string, `/${string}`>

routes.home  // type is '/', not string
```

---

## `as const` Assertions

```typescript
// Without as const — widened to string[]
const sizes = ['sm', 'md', 'lg']
// type: string[]

// With as const — readonly literal tuple
const SIZES = ['sm', 'md', 'lg'] as const
// type: readonly ['sm', 'md', 'lg']

type Size = typeof SIZES[number]  // 'sm' | 'md' | 'lg'

// Object literals
const CONFIG = {
  apiUrl: 'https://api.example.com',
  timeout: 5000,
  retries: 3,
} as const

type Config = typeof CONFIG
// { readonly apiUrl: 'https://api.example.com'; readonly timeout: 5000; readonly retries: 3 }

// Enum alternative with as const
const Direction = {
  UP: 'UP',
  DOWN: 'DOWN',
  LEFT: 'LEFT',
  RIGHT: 'RIGHT',
} as const

type Direction = typeof Direction[keyof typeof Direction]  // 'UP' | 'DOWN' | 'LEFT' | 'RIGHT'

function move(dir: Direction) { /* ... */ }
move(Direction.UP)    // ✓
move('UP')            // ✓ (literal type matches)
// move('diagonal')   // ✗ TS error
```

---

## Type-Safe API Response Patterns

```typescript
// Generic API wrapper with proper error typing
type ApiSuccess<T> = { ok: true; data: T }
type ApiError = { ok: false; error: string; statusCode: number }
type ApiResult<T> = ApiSuccess<T> | ApiError

async function apiFetch<T>(url: string): Promise<ApiResult<T>> {
  try {
    const res = await fetch(url)
    if (!res.ok) {
      return { ok: false, error: res.statusText, statusCode: res.status }
    }
    const data = await res.json() as T
    return { ok: true, data }
  } catch (err) {
    return { ok: false, error: String(err), statusCode: 0 }
  }
}

// Usage — fully narrowed
const result = await apiFetch<User[]>('/api/users')
if (result.ok) {
  result.data.map(u => u.name)   // User[] ✓
} else {
  console.error(result.error)    // string ✓
}

// Zod + TypeScript integration
import { z } from 'zod'

const UserSchema = z.object({
  id: z.string().uuid(),
  name: z.string().min(1),
  email: z.string().email(),
  role: z.enum(['admin', 'user', 'guest']),
})

type User = z.infer<typeof UserSchema>  // type derived from schema

async function getUser(id: string): Promise<User> {
  const res = await fetch(`/api/users/${id}`)
  const raw = await res.json()
  return UserSchema.parse(raw)  // runtime + compile-time safety
}
```

---

## Type Narrowing Patterns

```typescript
// Type guard functions
function isUser(value: unknown): value is User {
  return (
    typeof value === 'object' &&
    value !== null &&
    'id' in value &&
    'name' in value &&
    typeof (value as User).id === 'string'
  )
}

// Assertion functions (throws if wrong type)
function assertIsString(val: unknown): asserts val is string {
  if (typeof val !== 'string') throw new TypeError(`Expected string, got ${typeof val}`)
}

// in operator narrowing
type Cat = { meow(): void }
type Dog = { bark(): void }

function speak(animal: Cat | Dog) {
  if ('meow' in animal) {
    animal.meow()   // Cat ✓
  } else {
    animal.bark()   // Dog ✓
  }
}

// instanceof narrowing
function formatError(err: unknown): string {
  if (err instanceof Error) return err.message   // Error ✓
  if (typeof err === 'string') return err
  return 'Unknown error'
}
```
