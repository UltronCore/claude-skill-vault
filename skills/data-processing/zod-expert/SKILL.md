---
name: zod-expert
description: >
  Zod v3 schema validation: complex schemas, transformations, refinements, and TypeScript type inference. Triggers on: z.object, z.string, z.number, zod, ZodSchema, z.infer, .parse(), .safeParse(), z.union, z.discriminatedUnion.
---

# Zod Expert

## When to Use
Use for runtime validation at API boundaries, form validation, environment variable parsing, and anywhere you need type-safe data coercion.

---

## Core Rules
- Always use `.safeParse()` at API boundaries — never throw-on-fail in request handlers
- Derive TypeScript types from schemas with `z.infer<>` — never duplicate types
- Use `.transform()` to normalize data (trim, lowercase, coerce dates)
- Use `.superRefine()` for cross-field validation
- Parse at the edge (API route, server action) — trust inside, validate outside

---

## Install

```bash
npm install zod
```

---

## Primitive Types

```typescript
import { z } from 'zod';

z.string()
z.string().min(1).max(255)
z.string().email()
z.string().url()
z.string().uuid()
z.string().regex(/^\d{5}$/)
z.string().startsWith('https')
z.string().trim()                // transform: trims whitespace
z.string().toLowerCase()        // transform: lowercases
z.string().optional()           // string | undefined
z.string().nullable()           // string | null
z.string().nullish()            // string | null | undefined
z.string().default('fallback')  // sets default if undefined

z.number().min(0).max(100)
z.number().int()                // integer only
z.number().positive()
z.number().nonnegative()
z.number().finite()

z.boolean()
z.date()
z.literal('admin')             // exactly 'admin'
z.enum(['a', 'b', 'c'])
z.nativeEnum(MyEnum)           // TypeScript enum
z.undefined()
z.null()
z.any()
z.unknown()                    // like any but type-safe
z.never()
```

---

## Object Schemas

```typescript
const UserSchema = z.object({
  id: z.string().uuid(),
  email: z.string().email().toLowerCase().trim(),
  name: z.string().min(1).max(100),
  age: z.number().int().min(0).max(150).optional(),
  role: z.enum(['admin', 'user', 'viewer']).default('user'),
  metadata: z.record(z.string(), z.unknown()).optional(),
});

// Type inference
type User = z.infer<typeof UserSchema>;
// { id: string; email: string; name: string; age?: number; role: 'admin' | 'user' | 'viewer'; metadata?: Record<string, unknown> }

// Object modifiers
UserSchema.partial()             // all fields optional
UserSchema.required()           // all fields required (removes optional)
UserSchema.pick({ id: true, email: true })  // only specified fields
UserSchema.omit({ metadata: true })         // all except specified
UserSchema.extend({ bio: z.string() })      // add fields
UserSchema.merge(OtherSchema)               // merge two schemas

// Strip unknown keys (default), passthrough, or strict
z.object({ name: z.string() }).strip()       // default: drops unknown keys
z.object({ name: z.string() }).passthrough() // keeps unknown keys
z.object({ name: z.string() }).strict()      // errors on unknown keys
```

---

## Arrays & Collections

```typescript
z.array(z.string())                  // string[]
z.array(z.string()).min(1)           // at least 1
z.array(z.string()).max(10)
z.array(z.string()).length(5)        // exactly 5
z.array(z.string()).nonempty()       // min 1

// Tuple
z.tuple([z.string(), z.number(), z.boolean()])

// Record
z.record(z.string())                 // Record<string, string>
z.record(z.string(), z.number())     // Record<string, number>

// Map / Set
z.map(z.string(), z.number())
z.set(z.string())
```

---

## Union & Discriminated Union

```typescript
// Union — tries each schema in order
const StringOrNumber = z.union([z.string(), z.number()]);

// Discriminated union — faster, clearer errors
const ApiResponse = z.discriminatedUnion('type', [
  z.object({ type: z.literal('success'), data: z.array(UserSchema) }),
  z.object({ type: z.literal('error'), message: z.string(), code: z.number() }),
  z.object({ type: z.literal('empty') }),
]);

type ApiResponse = z.infer<typeof ApiResponse>;
// { type: 'success'; data: User[] } | { type: 'error'; message: string; code: number } | { type: 'empty' }

// Intersection
const WithTimestamps = z.object({
  createdAt: z.date(),
  updatedAt: z.date(),
});
const UserWithTimestamps = UserSchema.and(WithTimestamps);
```

---

## Transformations

```typescript
// .transform() — parse input, return different shape
const TrimmedEmail = z.string().email().transform((val) => val.toLowerCase().trim());
type TrimmedEmail = z.infer<typeof TrimmedEmail>; // string

// Coerce types (great for form data, query params — which are always strings)
const AgeSchema = z.coerce.number().int().min(0);   // "25" → 25
const DateSchema = z.coerce.date();                 // "2024-01-01" → Date
const BoolSchema = z.coerce.boolean();              // "true" → true

// Transform object shape
const ApiUserSchema = z.object({ user_name: z.string(), user_email: z.string().email() })
  .transform(({ user_name, user_email }) => ({
    name: user_name,
    email: user_email,
  }));
// Input:  { user_name: 'Example User', user_email: 'b@example.com' }
// Output: { name: 'Example User', email: 'b@example.com' }

// z.preprocess — run code before parsing
const NumberFromString = z.preprocess(
  (val) => (typeof val === 'string' ? parseInt(val, 10) : val),
  z.number()
);
```

---

## Refinements

```typescript
// .refine() — add custom validation
const PasswordSchema = z.string()
  .min(8, 'At least 8 characters')
  .refine(
    (val) => /[A-Z]/.test(val),
    { message: 'Must contain at least one uppercase letter' }
  )
  .refine(
    (val) => /[0-9]/.test(val),
    { message: 'Must contain at least one number' }
  );

// .superRefine() — cross-field validation, multiple issues
const SignupSchema = z
  .object({
    password: z.string().min(8),
    confirmPassword: z.string(),
    startDate: z.coerce.date(),
    endDate: z.coerce.date(),
  })
  .superRefine((data, ctx) => {
    if (data.password !== data.confirmPassword) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: 'Passwords do not match',
        path: ['confirmPassword'],  // attach error to specific field
      });
    }
    if (data.endDate <= data.startDate) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: 'End date must be after start date',
        path: ['endDate'],
      });
    }
  });
```

---

## Async Validation

```typescript
const UniqueEmailSchema = z.string().email().refine(
  async (email) => {
    const existing = await db.query.users.findFirst({ where: eq(users.email, email) });
    return !existing;
  },
  { message: 'Email already in use' }
);

// Must use parseAsync / safeParseAsync for schemas with async refinements
const result = await UniqueEmailSchema.safeParseAsync(input);
```

---

## Error Handling

```typescript
// .parse() — throws ZodError on invalid input
try {
  const user = UserSchema.parse(rawData);
} catch (err) {
  if (err instanceof z.ZodError) {
    console.log(err.errors);
    // [{ path: ['email'], message: 'Invalid email', code: 'invalid_string' }]
  }
}

// .safeParse() — returns result object (preferred at API boundaries)
const result = UserSchema.safeParse(rawData);
if (!result.success) {
  // Flatten errors for easy consumption
  const errors = result.error.flatten();
  // errors.fieldErrors: { email: ['Invalid email'], name: ['Too short'] }
  // errors.formErrors: string[] (top-level errors)

  return Response.json({ errors: errors.fieldErrors }, { status: 400 });
}

const user = result.data; // typed as User

// Format errors for API response
function formatZodError(error: z.ZodError) {
  return error.errors.reduce((acc, { path, message }) => {
    const key = path.join('.');
    acc[key] = message;
    return acc;
  }, {} as Record<string, string>);
}
```

---

## Schema Reuse Patterns

```typescript
// Base schema — shared fields
const BaseEntitySchema = z.object({
  id: z.string().uuid(),
  createdAt: z.coerce.date(),
  updatedAt: z.coerce.date(),
});

// Create input — no id/timestamps
const CreateUserSchema = z.object({
  email: z.string().email().trim().toLowerCase(),
  name: z.string().min(1).max(100).trim(),
  role: z.enum(['admin', 'user']).default('user'),
});

// Update input — all optional
const UpdateUserSchema = CreateUserSchema.partial();

// Full user — base + create fields
const UserSchema = BaseEntitySchema.merge(CreateUserSchema);

// API response — omit sensitive fields
const PublicUserSchema = UserSchema.omit({ role: true });

type CreateUserInput = z.infer<typeof CreateUserSchema>;
type UpdateUserInput = z.infer<typeof UpdateUserSchema>;
type User = z.infer<typeof UserSchema>;
type PublicUser = z.infer<typeof PublicUserSchema>;
```

---

## Zod with React Hook Form

```typescript
// Install: npm install react-hook-form @hookform/resolvers zod
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';

const SignupSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8),
  name: z.string().min(1),
});
type SignupForm = z.infer<typeof SignupSchema>;

export function SignupForm() {
  const { register, handleSubmit, formState: { errors } } = useForm<SignupForm>({
    resolver: zodResolver(SignupSchema),
    defaultValues: { email: '', password: '', name: '' },
  });

  const onSubmit = async (data: SignupForm) => {
    // data is fully typed and validated
    await createUser(data);
  };

  return (
    <form onSubmit={handleSubmit(onSubmit)}>
      <input {...register('email')} />
      {errors.email && <p>{errors.email.message}</p>}
      <input {...register('password')} type="password" />
      {errors.password && <p>{errors.password.message}</p>}
      <button type="submit">Sign Up</button>
    </form>
  );
}
```

---

## Environment Variables

```typescript
// lib/env.ts — parse and validate at startup
const EnvSchema = z.object({
  DATABASE_URL: z.string().url(),
  NEXT_PUBLIC_SUPABASE_URL: z.string().url(),
  NEXT_PUBLIC_SUPABASE_ANON_KEY: z.string().min(1),
  SUPABASE_SERVICE_ROLE_KEY: z.string().min(1),
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().default(3000),
});

export const env = EnvSchema.parse(process.env);
// Throws at startup if any required env var is missing/invalid
```

---

## Quick Reference

| Task | Pattern |
|---|---|
| Parse (throw on fail) | `Schema.parse(data)` |
| Parse (safe) | `Schema.safeParse(data)` |
| Async validation | `Schema.safeParseAsync(data)` |
| Infer TypeScript type | `type T = z.infer<typeof Schema>` |
| Cross-field validation | `.superRefine((data, ctx) => ctx.addIssue(...))` |
| Flatten errors | `result.error.flatten().fieldErrors` |
| Optional vs nullable | `.optional()` = undefined, `.nullable()` = null |
| Coerce from string | `z.coerce.number()` / `z.coerce.date()` |
| Form validation | `zodResolver(Schema)` with react-hook-form |

## Related Skills
- `api-contracts-and-zod-validation` — API validation
- `form-generator-rhf-zod` — form validation
- `instructor` — structured output validation

## GitNexus Index
This skill is indexed by GitNexus for knowledge graph traversal.
Index path: /Users/localuser/.claude/skills/zod-expert/.gitnexus
Last indexed: 2026-05-23
