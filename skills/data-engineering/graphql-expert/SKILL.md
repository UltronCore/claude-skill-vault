---
name: graphql-expert
description: >
  GraphQL API design, queries, mutations, subscriptions, and schema optimization. Triggers on: GraphQL, gql, useQuery Apollo, graphql-request, schema.graphql, resolver, subscription, GraphQL codegen.
---

# GraphQL Expert

## When to Use
Use when building or consuming GraphQL APIs: schema design, writing resolvers, fixing N+1 queries, setting up codegen, or choosing a client library.

---

## Core Rules
- Always define nullable fields explicitly — never rely on implicit nullability
- Solve N+1 before shipping any list resolver — use DataLoader
- Codegen from the schema; never write types by hand
- Subscriptions are WebSocket-based — plan infrastructure accordingly
- Return typed errors (union types) instead of generic error strings

---

## Schema Design

### Naming Conventions
- Types: PascalCase (`UserProfile`)
- Fields: camelCase (`createdAt`)
- Queries: verb or noun (`user`, `listUsers`)
- Mutations: verb-noun (`createUser`, `deletePost`)
- Subscriptions: noun-Created/Updated/Deleted (`messageCreated`)

### Type Definitions
```graphql
# schema.graphql
type User {
  id: ID!
  email: String!
  name: String!
  posts: [Post!]!        # non-null list of non-null items
  createdAt: DateTime!
}

type Post {
  id: ID!
  title: String!
  body: String
  published: Boolean!
  author: User!
}

type Query {
  user(id: ID!): User          # nullable — returns null if not found
  users(limit: Int = 10, offset: Int = 0): [User!]!
  post(id: ID!): Post
}

type Mutation {
  createUser(input: CreateUserInput!): CreateUserResult!
  updateUser(id: ID!, input: UpdateUserInput!): UpdateUserResult!
  deleteUser(id: ID!): DeleteUserResult!
}

type Subscription {
  messageCreated(channelId: ID!): Message!
}

# Input types — always separate from output types
input CreateUserInput {
  email: String!
  name: String!
  password: String!
}

# Union result types for typed errors
union CreateUserResult = User | ValidationError | DuplicateEmailError

type ValidationError {
  field: String!
  message: String!
}

type DuplicateEmailError {
  email: String!
  message: String!
}
```

### Pagination Pattern (Cursor-based)
```graphql
type UserConnection {
  edges: [UserEdge!]!
  pageInfo: PageInfo!
  totalCount: Int!
}

type UserEdge {
  node: User!
  cursor: String!
}

type PageInfo {
  hasNextPage: Boolean!
  hasPreviousPage: Boolean!
  startCursor: String
  endCursor: String
}

type Query {
  users(first: Int, after: String, last: Int, before: String): UserConnection!
}
```

---

## Resolver Patterns (Node.js / TypeScript)

### Basic Resolver Structure
```typescript
// resolvers/user.resolver.ts
import { Resolvers } from '../generated/graphql'; // codegen types
import { UserService } from '../services/user.service';
import { Context } from '../types/context';

export const userResolvers: Resolvers = {
  Query: {
    user: async (_parent, { id }, ctx: Context) => {
      return ctx.services.user.findById(id);
    },
    users: async (_parent, { limit, offset }, ctx: Context) => {
      return ctx.services.user.findMany({ limit, offset });
    },
  },

  Mutation: {
    createUser: async (_parent, { input }, ctx: Context) => {
      // Auth check
      if (!ctx.user) throw new GraphQLError('Unauthorized', {
        extensions: { code: 'UNAUTHORIZED' },
      });

      try {
        return await ctx.services.user.create(input);
      } catch (err) {
        if (err instanceof DuplicateEmailError) {
          return { __typename: 'DuplicateEmailError', email: input.email, message: err.message };
        }
        throw err;
      }
    },
  },

  // Field resolver — runs for each User instance
  User: {
    posts: async (parent, _args, ctx: Context) => {
      // WARNING: this is the N+1 pattern — fix with DataLoader below
      return ctx.services.post.findByAuthorId(parent.id);
    },
  },
};
```

---

## N+1 Problem — DataLoader

```typescript
// loaders/post.loader.ts
import DataLoader from 'dataloader';
import { PostService } from '../services/post.service';

// One batch function: receives array of authorIds, returns array of Post[] in same order
export function createPostsByAuthorLoader(postService: PostService) {
  return new DataLoader<string, Post[]>(async (authorIds) => {
    const posts = await postService.findByAuthorIds([...authorIds]);

    // Group posts by authorId
    const grouped = new Map<string, Post[]>();
    for (const post of posts) {
      const arr = grouped.get(post.authorId) ?? [];
      arr.push(post);
      grouped.set(post.authorId, arr);
    }

    // Return in same order as input keys
    return authorIds.map((id) => grouped.get(id) ?? []);
  });
}

// context.ts — create loaders per-request (never share across requests)
export function createContext(): Context {
  const services = createServices();
  return {
    user: null,
    services,
    loaders: {
      postsByAuthor: createPostsByAuthorLoader(services.post),
    },
  };
}

// resolver — use loader instead of direct service call
User: {
  posts: (parent, _args, ctx) => ctx.loaders.postsByAuthor.load(parent.id),
},
```

---

## Code Generation (graphql-codegen)

### Install
```bash
npm install -D @graphql-codegen/cli @graphql-codegen/typescript @graphql-codegen/typescript-resolvers @graphql-codegen/typescript-react-apollo
```

### Config
```yaml
# codegen.yml
overwrite: true
schema: "src/schema.graphql"
documents: "src/**/*.graphql"  # client query files
generates:
  # Server: resolver types
  src/generated/graphql.ts:
    plugins:
      - typescript
      - typescript-resolvers
    config:
      contextType: "../types/context#Context"
      useIndexSignature: true

  # Client: typed hooks
  src/generated/graphql-hooks.ts:
    plugins:
      - typescript
      - typescript-operations
      - typescript-react-apollo
    config:
      withHooks: true
```

```bash
npx graphql-codegen --config codegen.yml --watch
```

---

## GraphQL Clients

### Apollo Client (full-featured, React)
```typescript
// lib/apollo.ts
import { ApolloClient, InMemoryCache, HttpLink, split } from '@apollo/client';
import { GraphQLWsLink } from '@apollo/client/link/subscriptions';
import { createClient } from 'graphql-ws';
import { getMainDefinition } from '@apollo/client/utilities';

const httpLink = new HttpLink({ uri: '/api/graphql' });

const wsLink = new GraphQLWsLink(
  createClient({ url: 'wss://example.com/api/graphql' })
);

// Route subscriptions to WebSocket, queries/mutations to HTTP
const splitLink = split(
  ({ query }) => {
    const def = getMainDefinition(query);
    return def.kind === 'OperationDefinition' && def.operation === 'subscription';
  },
  wsLink,
  httpLink
);

export const apolloClient = new ApolloClient({
  link: splitLink,
  cache: new InMemoryCache(),
});

// Usage in component (with codegen hooks)
const { data, loading, error } = useGetUserQuery({ variables: { id: '1' } });
```

### graphql-request (lightweight, server-to-server)
```typescript
import { GraphQLClient, gql } from 'graphql-request';

const client = new GraphQLClient('https://api.example.com/graphql', {
  headers: { authorization: `Bearer ${token}` },
});

const GET_USER = gql`
  query GetUser($id: ID!) {
    user(id: $id) {
      id
      name
      email
    }
  }
`;

const data = await client.request<{ user: User }>(GET_USER, { id: '1' });
```

### urql (lightweight, React, great DX)
```typescript
import { createClient, cacheExchange, fetchExchange } from 'urql';

const client = createClient({
  url: '/api/graphql',
  exchanges: [cacheExchange, fetchExchange],
});

// Component
const [result] = useQuery({ query: GET_USER, variables: { id: '1' } });
```

**Choose:**
- Apollo Client — complex apps, subscriptions, optimistic UI, normalized caching
- graphql-request — server-to-server, scripts, simple fetches
- urql — React apps wanting lighter bundle than Apollo

---

## Authentication in Resolvers

```typescript
// middleware: parse JWT and attach user to context
export function createContext({ req }: { req: Request }): Context {
  const token = req.headers.authorization?.replace('Bearer ', '');
  const user = token ? verifyJwt(token) : null;
  return { user, services: createServices() };
}

// Guard helper
function requireAuth(ctx: Context) {
  if (!ctx.user) {
    throw new GraphQLError('You must be logged in', {
      extensions: { code: 'UNAUTHENTICATED' },
    });
  }
  return ctx.user;
}

// Resolver usage
Mutation: {
  deletePost: async (_parent, { id }, ctx) => {
    const user = requireAuth(ctx);
    const post = await ctx.services.post.findById(id);
    if (post.authorId !== user.id) {
      throw new GraphQLError('Forbidden', { extensions: { code: 'FORBIDDEN' } });
    }
    return ctx.services.post.delete(id);
  },
},
```

---

## Persisted Queries

```typescript
// Apollo Server — automatic persisted queries (APQ)
import { ApolloServer } from '@apollo/server';
import { createPersistedQueryLink } from '@apollo/client/link/persisted-queries';
import { sha256 } from 'crypto-hash';

// Client
const persistedQueriesLink = createPersistedQueryLink({ sha256 });
const link = persistedQueriesLink.concat(httpLink);

// Server handles GET /graphql?extensions={"persistedQuery":{"sha256Hash":"..."}}
// Falls back to POST with full query if hash not found
```

---

## Error Handling

```typescript
import { GraphQLError } from 'graphql';
import { unwrapResolverError } from '@apollo/server/errors';

// Formatting errors before sending to client
const server = new ApolloServer({
  formatError: (formattedError, error) => {
    const originalError = unwrapResolverError(error);

    // Hide internal errors in production
    if (originalError instanceof DatabaseError) {
      return { message: 'Internal server error', extensions: { code: 'INTERNAL_ERROR' } };
    }
    return formattedError;
  },
});

// Standard error codes
// UNAUTHENTICATED — not logged in
// FORBIDDEN — logged in but not allowed
// BAD_USER_INPUT — invalid input
// NOT_FOUND — resource doesn't exist
// INTERNAL_SERVER_ERROR — unexpected
```

---

## Quick Reference

| Problem | Solution |
|---|---|
| N+1 queries | DataLoader per relation |
| Type safety | graphql-codegen |
| Subscriptions in Next.js | Separate WebSocket server or graphql-ws |
| Auth | Context + requireAuth helper |
| Typed errors | Union result types |
| Large responses | Cursor pagination + field selection |

## Related Skills
- `graphql-subscriptions` — real-time GraphQL
- `trpc-expert` — alternative API layer
- `openapi-spec-generation` — API documentation

## GitNexus Index
This skill is indexed by GitNexus for knowledge graph traversal.
Index path: /Users/localuser/.claude/skills/graphql-expert/.gitnexus
Last indexed: 2026-05-23
