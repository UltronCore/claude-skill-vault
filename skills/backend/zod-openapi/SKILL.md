---
name: zod-openapi
description: Auto-generate OpenAPI 3.x specs from Zod schemas and wire them into Express, Fastify, Hono, or any Node.js framework. Use this skill whenever the user wants to generate OpenAPI docs from Zod, create a type-safe API with auto-generated Swagger UI, or avoid writing OpenAPI YAML/JSON by hand. Trigger for "zod openapi", "openapi from zod schemas", "swagger from typescript types", "auto-generate api docs", or @asteasolutions/zod-to-openapi questions.
---

# Zod + OpenAPI: Auto-Generate API Documentation

Stop writing OpenAPI YAML by hand. Define your schemas once with Zod, and get full OpenAPI 3.x specs, Swagger UI, and TypeScript types — all from a single source of truth.

## Popular Approaches

### 1. `@asteasolutions/zod-to-openapi` (most flexible)

```bash
npm install @asteasolutions/zod-to-openapi zod
```

```typescript
import {
  OpenAPIRegistry,
  OpenApiGeneratorV3,
  extendZodWithOpenApi,
} from '@asteasolutions/zod-to-openapi'
import { z } from 'zod'

// Extend Zod with OpenAPI metadata support
extendZodWithOpenApi(z)

const registry = new OpenAPIRegistry()

// Define schemas with OpenAPI metadata
const UserSchema = registry.register(
  'User',
  z.object({
    id: z.string().uuid().openapi({ example: '550e8400-e29b-41d4-a716-446655440000' }),
    name: z.string().min(1).openapi({ example: 'Alice Smith' }),
    email: z.string().email().openapi({ example: 'alice@example.com' }),
    role: z.enum(['admin', 'user', 'viewer']).openapi({ example: 'user' }),
    createdAt: z.string().datetime().openapi({ example: '2024-01-01T00:00:00Z' }),
  }).openapi('User')
)

const CreateUserSchema = z.object({
  name: z.string().min(1),
  email: z.string().email(),
  role: z.enum(['admin', 'user', 'viewer']).default('user'),
}).openapi('CreateUser')

const ErrorSchema = z.object({
  error: z.string(),
  code: z.string(),
}).openapi('Error')

// Register API paths
registry.registerPath({
  method: 'get',
  path: '/users',
  summary: 'List all users',
  tags: ['Users'],
  responses: {
    200: {
      description: 'List of users',
      content: {
        'application/json': { schema: z.array(UserSchema) },
      },
    },
  },
})

registry.registerPath({
  method: 'post',
  path: '/users',
  summary: 'Create a new user',
  tags: ['Users'],
  request: {
    body: {
      content: { 'application/json': { schema: CreateUserSchema } },
      required: true,
    },
  },
  responses: {
    201: {
      description: 'User created',
      content: { 'application/json': { schema: UserSchema } },
    },
    422: {
      description: 'Validation error',
      content: { 'application/json': { schema: ErrorSchema } },
    },
  },
})

registry.registerPath({
  method: 'get',
  path: '/users/{id}',
  summary: 'Get user by ID',
  tags: ['Users'],
  request: {
    params: z.object({ id: z.string().uuid() }),
  },
  responses: {
    200: { description: 'User found', content: { 'application/json': { schema: UserSchema } } },
    404: { description: 'Not found', content: { 'application/json': { schema: ErrorSchema } } },
  },
})

// Generate spec
const generator = new OpenApiGeneratorV3(registry.definitions)
const spec = generator.generateDocument({
  openapi: '3.0.0',
  info: { title: 'My API', version: '1.0.0', description: 'User management API' },
  servers: [{ url: 'https://api.myapp.com', description: 'Production' }],
})

// Export as JSON or YAML
import fs from 'fs'
fs.writeFileSync('openapi.json', JSON.stringify(spec, null, 2))
```

### 2. Serve Swagger UI Alongside Your API

```typescript
import express from 'express'
import swaggerUi from 'swagger-ui-express'
import { spec } from './openapi' // your generated spec

const app = express()
app.use(express.json())

// Serve Swagger UI at /docs
app.use('/docs', swaggerUi.serve, swaggerUi.setup(spec))
app.get('/openapi.json', (req, res) => res.json(spec))

// Your actual routes with validation
import { z } from 'zod'

app.get('/users', async (req, res) => {
  const users = await db.user.findMany()
  res.json(users)
})

app.post('/users', async (req, res) => {
  const result = CreateUserSchema.safeParse(req.body)
  if (!result.success) {
    return res.status(422).json({ error: 'Validation failed', code: 'VALIDATION_ERROR' })
  }
  const user = await db.user.create({ data: result.data })
  res.status(201).json(user)
})

app.listen(3000, () => {
  console.log('API: http://localhost:3000')
  console.log('Docs: http://localhost:3000/docs')
})
```

### 3. With Hono (built-in OpenAPI support)

```bash
npm install hono @hono/zod-openapi @hono/swagger-ui
```

```typescript
import { OpenAPIHono, createRoute, z } from '@hono/zod-openapi'

const app = new OpenAPIHono()

const UserSchema = z.object({
  id: z.string().openapi({ example: 'user_123' }),
  name: z.string().openapi({ example: 'Alice' }),
}).openapi('User')

const listUsersRoute = createRoute({
  method: 'get',
  path: '/users',
  tags: ['Users'],
  responses: {
    200: {
      content: { 'application/json': { schema: z.array(UserSchema) } },
      description: 'List users',
    },
  },
})

app.openapi(listUsersRoute, async (c) => {
  const users = await getUsers()
  return c.json(users, 200) // typed — must match schema
})

// Auto-generated docs
app.doc('/openapi.json', {
  openapi: '3.0.0',
  info: { title: 'My API', version: '1.0.0' },
})

// Swagger UI
import { swaggerUI } from '@hono/swagger-ui'
app.get('/docs', swaggerUI({ url: '/openapi.json' }))

export default app
```

### 4. With Fastify (fastify-zod-openapi)

```bash
npm install fastify fastify-zod-openapi @fastify/swagger @fastify/swagger-ui zod
```

```typescript
import Fastify from 'fastify'
import fastifyZodOpenApi, { serializerCompiler, validatorCompiler } from 'fastify-zod-openapi'
import fastifySwagger from '@fastify/swagger'
import fastifySwaggerUi from '@fastify/swagger-ui'
import { z } from 'zod'

const app = Fastify()

app.setSerializerCompiler(serializerCompiler)
app.setValidatorCompiler(validatorCompiler)

await app.register(fastifyZodOpenApi)
await app.register(fastifySwagger, {
  openapi: {
    info: { title: 'My API', version: '1.0.0' },
  },
})
await app.register(fastifySwaggerUi, { routePrefix: '/docs' })

const CreateUserBody = z.object({
  name: z.string(),
  email: z.string().email(),
})

app.post('/users', {
  schema: {
    body: CreateUserBody,
    response: {
      201: z.object({ id: z.string(), name: z.string(), email: z.string() }),
    },
  },
  handler: async (req, reply) => {
    const user = await createUser(req.body)
    return reply.status(201).send(user)
  },
})

await app.ready()
await app.listen({ port: 3000 })
```

## Security Schemes

```typescript
// Add API key or Bearer auth to your spec
registry.registerComponent('securitySchemes', 'BearerAuth', {
  type: 'http',
  scheme: 'bearer',
  bearerFormat: 'JWT',
})

registry.registerComponent('securitySchemes', 'ApiKey', {
  type: 'apiKey',
  in: 'header',
  name: 'X-API-Key',
})

// Apply to routes
registry.registerPath({
  method: 'delete',
  path: '/users/{id}',
  security: [{ BearerAuth: [] }],
  // ...
})
```

## Output OpenAPI YAML

```bash
npm install js-yaml
```

```typescript
import yaml from 'js-yaml'
import fs from 'fs'

fs.writeFileSync('openapi.yaml', yaml.dump(spec))
```

## CI: Validate Spec on Every Commit

```bash
# Install redocly CLI
npm install -g @redocly/cli

# Validate
redocly lint openapi.json

# Bundle into single file
redocly bundle openapi.json -o dist/openapi.json
```

## Key Patterns

- Define schemas in a `schemas/` directory and import them everywhere (routes, validation, OpenAPI)
- Use `registry.register()` to give schemas names — they appear as `$ref` in the spec
- Add `.openapi({ example: ... })` to schemas for better documentation
- Generate the spec at build time and serve as a static file — don't regenerate per request
- Use `z.discriminatedUnion` for polymorphic response types

## GitNexus Index

This skill is indexed by GitNexus for knowledge graph traversal.
Index path: /Users/localuser/.claude/skills/zod-openapi/.gitnexus
Last indexed: 2026-05-24
