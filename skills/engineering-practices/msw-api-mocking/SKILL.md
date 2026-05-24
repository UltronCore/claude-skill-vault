---
name: msw-api-mocking
version: 1.0.0
description: Intercept and mock HTTP requests at the network level with MSW (Mock Service Worker) for tests and development
tools: [Bash, Read, Write, Edit]
category: testing
tags: [msw, mocking, api, service-worker, testing, fetch, rest, graphql]
author: claude-skill-vault
created: 2026-05-24
---

# MSW (Mock Service Worker) — API Mocking

## Overview

MSW intercepts HTTP requests at the network level using a Service Worker in the browser and Node.js HTTP interceptors in tests. Unlike mock functions that intercept at the code level, MSW lets your application code run unmodified while controlling what the network returns. Works with REST and GraphQL.

## When to Use

- Integration tests where components make real fetch/axios calls
- Development mode with a not-yet-ready backend
- Simulating API errors, timeouts, and edge cases
- Sharing mock handlers between browser (dev) and test (Node.js) environments
- Storybook development with realistic data

## Installation

```bash
npm install --save-dev msw

# Generate the service worker file for browser use
npx msw init public/ --save

# For TypeScript
npm install --save-dev @types/node
```

## Key Patterns

### Defining handlers

```typescript
// src/mocks/handlers.ts
import { http, HttpResponse, delay } from "msw";

export const handlers = [
  // GET request
  http.get("/api/users", () => {
    return HttpResponse.json([
      { id: 1, name: "Alice", email: "alice@example.com" },
      { id: 2, name: "Bob", email: "bob@example.com" },
    ]);
  }),

  // GET with path params
  http.get("/api/users/:id", ({ params }) => {
    const { id } = params;
    return HttpResponse.json({ id: Number(id), name: "Alice" });
  }),

  // POST with request body
  http.post("/api/users", async ({ request }) => {
    const body = await request.json() as { name: string; email: string };
    return HttpResponse.json(
      { id: 3, ...body },
      { status: 201 }
    );
  }),

  // Simulate error
  http.delete("/api/users/:id", () => {
    return HttpResponse.json(
      { error: "Unauthorized" },
      { status: 403 }
    );
  }),

  // Simulate network delay
  http.get("/api/slow-endpoint", async () => {
    await delay(2000);
    return HttpResponse.json({ data: "finally" });
  }),

  // Simulate network failure
  http.get("/api/unstable", () => {
    return HttpResponse.error();
  }),
];
```

### Browser setup (development)

```typescript
// src/mocks/browser.ts
import { setupWorker } from "msw/browser";
import { handlers } from "./handlers";

export const worker = setupWorker(...handlers);
```

```typescript
// src/main.tsx
async function enableMocking() {
  if (process.env.NODE_ENV !== "development") return;
  const { worker } = await import("./mocks/browser");
  return worker.start({
    onUnhandledRequest: "warn",
  });
}

enableMocking().then(() => {
  ReactDOM.createRoot(document.getElementById("root")!).render(<App />);
});
```

### Node.js test setup (Vitest / Jest)

```typescript
// src/mocks/node.ts
import { setupServer } from "msw/node";
import { handlers } from "./handlers";

export const server = setupServer(...handlers);
```

```typescript
// src/test/setup.ts
import { server } from "../mocks/node";

beforeAll(() => server.listen({ onUnhandledRequest: "error" }));
afterEach(() => server.resetHandlers());
afterAll(() => server.close());
```

### Per-test handler overrides

```typescript
import { http, HttpResponse } from "msw";
import { server } from "../mocks/node";

test("shows error state when API fails", async () => {
  server.use(
    http.get("/api/users", () => {
      return HttpResponse.json({ error: "Server error" }, { status: 500 });
    })
  );

  render(<UserList />);
  await screen.findByText("Failed to load users");
});

test("shows loading then data", async () => {
  server.use(
    http.get("/api/users", async () => {
      await delay(100);
      return HttpResponse.json([{ id: 1, name: "Test User" }]);
    })
  );

  render(<UserList />);
  expect(screen.getByText("Loading...")).toBeInTheDocument();
  await screen.findByText("Test User");
});
```

### GraphQL mocking

```typescript
import { graphql, HttpResponse } from "msw";

export const handlers = [
  graphql.query("GetUser", ({ variables }) => {
    return HttpResponse.json({
      data: {
        user: { id: variables.id, name: "Alice", email: "alice@example.com" },
      },
    });
  }),

  graphql.mutation("CreateUser", ({ variables }) => {
    return HttpResponse.json({
      data: {
        createUser: { id: 42, ...variables.input },
      },
    });
  }),
];
```

## Common Pitfalls

1. **Service worker not generated**: Run `npx msw init public/ --save` — the `mockServiceWorker.js` file must be in the public directory.
2. **`onUnhandledRequest: "error"`**: Use this in tests to catch missing handlers early; use `"warn"` in development.
3. **`server.resetHandlers()` in `afterEach`**: Without this, per-test handler overrides persist to the next test.
4. **Async body parsing**: Use `await request.json()` or `await request.text()` inside handlers — it's async.
5. **HTTPS in service worker**: Localhost HTTP works fine; production HTTPS requires the service worker to be on the same origin.

## Related Skills

- vitest-testing — unit test framework that pairs with MSW
- playwright-component-testing — browser-level tests that can also use MSW
- pact-contract-testing — API contract testing at the provider level

## GitNexus Index

```
domain: testing
maturity: stable
complexity: low-medium
supports: rest, graphql, fetch, axios, xhr
environments: browser (service worker), node.js
config-file: src/mocks/handlers.ts
```
