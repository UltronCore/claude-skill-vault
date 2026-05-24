---
name: pact-contract-testing
version: 1.0.0
description: Consumer-driven contract testing for APIs with Pact — verify provider and consumer agree on the API contract
tools: [Bash, Read, Write, Edit]
category: testing
tags: [pact, contract-testing, api, consumer-driven, microservices, rest, graphql]
author: claude-skill-vault
created: 2026-05-24
---

# Pact — Consumer-Driven Contract Testing

## Overview

Pact is a consumer-driven contract testing framework. The consumer defines expectations (a "pact" / contract) of the provider API, and the provider verifies it can meet those expectations. This catches API breaking changes before they reach production without requiring both services to be running simultaneously.

## When to Use

- Microservices where teams own separate services and coordinate via API
- Catching breaking API changes before deployment
- Replacing slow/fragile integration tests that require both services live
- Teams using continuous deployment who need fast, reliable API compatibility checks
- Services with multiple consumers that need to know who is affected by a change

## Installation

```bash
# JavaScript/TypeScript consumer + provider
npm install --save-dev @pact-foundation/pact

# Python consumer + provider
pip install pact-python

# Go
go get github.com/pact-foundation/pact-go/v2

# Java/Kotlin — add to build.gradle
# testImplementation 'au.com.dius.pact.consumer:junit5:4.6.x'
```

## Key Patterns

### Consumer test (JavaScript/TypeScript)

```typescript
// src/__tests__/userClient.pact.test.ts
import { PactV3, MatchersV3 } from "@pact-foundation/pact";
import path from "path";
import { fetchUser } from "../services/userClient";

const { like, integer, string } = MatchersV3;

const provider = new PactV3({
  consumer: "WebApp",
  provider: "UserService",
  dir: path.resolve(process.cwd(), "pacts"),
  port: 8080,
});

describe("UserService consumer", () => {
  describe("GET /users/:id", () => {
    it("returns a user when the user exists", async () => {
      await provider
        .given("user 1 exists")
        .uponReceiving("a request for user 1")
        .withRequest({
          method: "GET",
          path: "/users/1",
          headers: { Accept: "application/json" },
        })
        .willRespondWith({
          status: 200,
          headers: { "Content-Type": "application/json" },
          body: {
            id: integer(1),
            name: string("Alice"),
            email: string("alice@example.com"),
          },
        })
        .executeTest(async (mockServer) => {
          const user = await fetchUser(mockServer.url, 1);
          expect(user.id).toBe(1);
          expect(user.name).toBe("Alice");
        });
    });

    it("returns 404 when the user does not exist", async () => {
      await provider
        .given("user 99 does not exist")
        .uponReceiving("a request for a non-existent user")
        .withRequest({ method: "GET", path: "/users/99" })
        .willRespondWith({ status: 404 })
        .executeTest(async (mockServer) => {
          await expect(fetchUser(mockServer.url, 99)).rejects.toThrow("404");
        });
    });
  });
});
```

### Provider verification (JavaScript/TypeScript)

```typescript
// src/__tests__/userService.pact.verify.test.ts
import { Verifier } from "@pact-foundation/pact";
import path from "path";
import app from "../app";

describe("Pact provider verification", () => {
  let server: ReturnType<typeof app.listen>;

  beforeAll(() => {
    server = app.listen(3001);
  });

  afterAll(() => server.close());

  it("validates the pacts with the WebApp consumer", async () => {
    await new Verifier({
      provider: "UserService",
      providerBaseUrl: "http://localhost:3001",

      // Load pacts from local dir (or Pact Broker)
      pactUrls: [
        path.resolve(__dirname, "../../pacts/WebApp-UserService.json"),
      ],

      // Set up provider state (seed database)
      stateHandlers: {
        "user 1 exists": async () => {
          await db.seed({ id: 1, name: "Alice", email: "alice@example.com" });
        },
        "user 99 does not exist": async () => {
          await db.clear();
        },
      },
    }).verifyProvider();
  });
});
```

### Pact Broker workflow

```bash
# Publish pacts to broker after consumer tests pass
npx pact-broker publish ./pacts \
  --broker-base-url https://your-broker.pactflow.io \
  --broker-token $PACT_BROKER_TOKEN \
  --consumer-app-version $(git rev-parse HEAD) \
  --branch $(git branch --show-current)

# Can-I-Deploy check before deployment
npx pact-broker can-i-deploy \
  --pacticipant UserService \
  --version $(git rev-parse HEAD) \
  --to-environment production \
  --broker-base-url https://your-broker.pactflow.io \
  --broker-token $PACT_BROKER_TOKEN
```

### GitHub Actions CI

```yaml
# .github/workflows/pact.yml
name: Pact Tests
on: [push, pull_request]

jobs:
  consumer:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: 22, cache: npm }
      - run: npm ci
      - run: npm test -- --testPathPattern=pact
        env:
          PACT_BROKER_TOKEN: ${{ secrets.PACT_BROKER_TOKEN }}
      - name: Publish pacts
        run: |
          npx pact-broker publish ./pacts \
            --broker-base-url ${{ vars.PACT_BROKER_URL }} \
            --broker-token ${{ secrets.PACT_BROKER_TOKEN }} \
            --consumer-app-version ${{ github.sha }} \
            --branch ${{ github.ref_name }}

  provider:
    needs: consumer
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: 22, cache: npm }
      - run: npm ci
      - run: npm test -- --testPathPattern=pact.verify
        env:
          PACT_BROKER_TOKEN: ${{ secrets.PACT_BROKER_TOKEN }}
```

### Python consumer (pact-python)

```python
# tests/test_user_client_pact.py
import pytest
from pact import Consumer, Provider
from src.user_client import get_user

@pytest.fixture(scope="module")
def pact():
    pact = Consumer("WebApp").has_pact_with(
        Provider("UserService"),
        host_name="localhost",
        port=8080,
        pact_dir="./pacts",
    )
    pact.start_service()
    yield pact
    pact.stop_service()

def test_get_existing_user(pact):
    expected = {"id": 1, "name": "Alice", "email": "alice@example.com"}

    (
        pact
        .given("user 1 exists")
        .upon_receiving("a request for user 1")
        .with_request("GET", "/users/1")
        .will_respond_with(200, body=expected)
    )

    with pact:
        user = get_user("http://localhost:8080", 1)
        assert user["name"] == "Alice"
```

## Common Pitfalls

1. **Consumer defines structure, not behavior**: Pact tests that the contract is met structurally. Don't test business logic in pact tests.
2. **Provider state setup**: Providers must implement `stateHandlers` that match every `given()` string exactly — case-sensitive.
3. **Pact Broker vs local pacts**: Local pact files work for small setups; use Pact Broker or PactFlow for multi-team setups with `can-i-deploy`.
4. **Overly strict matchers**: Use `like()`, `integer()`, `string()` etc. instead of exact values — contracts should describe shape, not hardcode data.
5. **Publish on consumer test success only**: Only publish pacts from a passing consumer test run, otherwise broken contracts will block provider verification.

## Related Skills

- msw-api-mocking — mock APIs at the network level in tests and Storybook
- vitest-testing — unit test framework that runs consumer pact tests
- testcontainers-integration — run real dependencies for integration tests

## GitNexus Index

```
domain: testing
maturity: stable
complexity: medium-high
language: javascript, typescript, python, go, java
config-file: pact.config.ts or inline in test
broker: pactflow.io, self-hosted pact-broker
```
