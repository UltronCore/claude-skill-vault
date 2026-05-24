---
name: vitest-testing
version: 1.0.0
description: Write fast, Vite-native unit and integration tests with Vitest — Jest-compatible API with instant HMR
tools: [Bash, Read, Write, Edit]
category: testing
tags: [vitest, vite, testing, unit-tests, jest, typescript, react, vue]
author: claude-skill-vault
created: 2026-05-24
---

# Vitest — Vite-Native Testing Framework

## Overview

Vitest is a blazing-fast test runner built on Vite. It's Jest-compatible (same API), uses the same config as your Vite project, supports TypeScript natively, and has instant HMR for tests. It's the default choice for Vite/Vue/React/SvelteKit projects.

## When to Use

- Unit and integration testing in any Vite-based project
- Migrating from Jest for faster test execution
- Testing TypeScript code without transpilation config
- Component testing with React Testing Library or Vue Testing Library
- Snapshot testing, mocking, and code coverage

## Installation

```bash
# Install Vitest and optional UI
npm install --save-dev vitest @vitest/ui @vitest/coverage-v8

# For React component testing
npm install --save-dev @testing-library/react @testing-library/jest-dom jsdom

# Verify
npx vitest --version
```

## Key Patterns

### vite.config.ts with Vitest

```typescript
// vite.config.ts
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
  test: {
    globals: true,
    environment: "jsdom",
    setupFiles: ["./src/test/setup.ts"],
    coverage: {
      provider: "v8",
      reporter: ["text", "json", "html"],
      exclude: ["node_modules/", "src/test/"],
    },
  },
});
```

### Setup file

```typescript
// src/test/setup.ts
import "@testing-library/jest-dom";
```

### Unit test example

```typescript
// src/utils/currency.test.ts
import { describe, it, expect, vi, beforeEach } from "vitest";
import { formatCurrency, convertCurrency } from "./currency";

describe("formatCurrency", () => {
  it("formats USD correctly", () => {
    expect(formatCurrency(1234.56, "USD")).toBe("$1,234.56");
  });

  it("handles zero", () => {
    expect(formatCurrency(0, "USD")).toBe("$0.00");
  });

  it("handles negative values", () => {
    expect(formatCurrency(-50, "USD")).toBe("-$50.00");
  });
});

describe("convertCurrency", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("converts using the exchange rate", async () => {
    const mockFetch = vi.fn().mockResolvedValue({
      json: () => Promise.resolve({ rate: 1.08 }),
    });
    vi.stubGlobal("fetch", mockFetch);

    const result = await convertCurrency(100, "USD", "EUR");
    expect(result).toBe(108);
    expect(mockFetch).toHaveBeenCalledWith(
      expect.stringContaining("USD/EUR")
    );
  });
});
```

### React component test

```typescript
// src/components/Button.test.tsx
import { render, screen, fireEvent } from "@testing-library/react";
import { describe, it, expect, vi } from "vitest";
import { Button } from "./Button";

describe("Button", () => {
  it("renders with label", () => {
    render(<Button label="Click me" onClick={() => {}} />);
    expect(screen.getByText("Click me")).toBeInTheDocument();
  });

  it("calls onClick when clicked", () => {
    const onClick = vi.fn();
    render(<Button label="Click" onClick={onClick} />);
    fireEvent.click(screen.getByText("Click"));
    expect(onClick).toHaveBeenCalledTimes(1);
  });

  it("is disabled when loading", () => {
    render(<Button label="Submit" onClick={() => {}} loading />);
    expect(screen.getByRole("button")).toBeDisabled();
  });
});
```

### Mocking modules

```typescript
import { vi } from "vitest";

// Mock a module
vi.mock("../services/api", () => ({
  fetchUser: vi.fn().mockResolvedValue({ id: 1, name: "Alice" }),
  updateUser: vi.fn().mockResolvedValue({ success: true }),
}));

// Mock with factory function
vi.mock("../utils/logger", () => {
  return {
    default: {
      info: vi.fn(),
      error: vi.fn(),
      warn: vi.fn(),
    },
  };
});

// Spy on a method
const spy = vi.spyOn(userService, "getUser");
spy.mockResolvedValueOnce({ id: 1, name: "Bob" });
```

### Running tests

```bash
# Run all tests
npx vitest

# Run in watch mode (default)
npx vitest watch

# Run once (CI mode)
npx vitest run

# Run with UI
npx vitest --ui

# Run specific file
npx vitest src/utils/currency.test.ts

# Coverage report
npx vitest run --coverage

# Update snapshots
npx vitest run --update-snapshots
```

### package.json scripts

```json
{
  "scripts": {
    "test": "vitest",
    "test:run": "vitest run",
    "test:ui": "vitest --ui",
    "test:coverage": "vitest run --coverage"
  }
}
```

## Common Pitfalls

1. **Missing `globals: true`**: Without this, you must import `describe`, `it`, `expect` from Vitest in every file.
2. **Environment mismatch**: Use `environment: "jsdom"` for browser APIs; `environment: "node"` for server-only code.
3. **ESM module mocking**: Some CJS modules need `vi.mock()` hoisting — place mocks at the top of the file.
4. **`vi.clearAllMocks()` in `beforeEach`**: Always clear mocks between tests to prevent state leakage.
5. **Coverage thresholds**: Set `coverage.thresholds` in config to fail CI when coverage drops below a target.

## Related Skills

- playwright-component-testing — browser-level component tests
- msw-api-mocking — network-level API mocking for integration tests
- storybook-interaction-testing — UI behavior tests in Storybook

## GitNexus Index

```
domain: testing
maturity: stable
complexity: low
compatible-with: jest, vite, react, vue, svelte
config-file: vite.config.ts (test block) or vitest.config.ts
coverage: v8, istanbul
```
