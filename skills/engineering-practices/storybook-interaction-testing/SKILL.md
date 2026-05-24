---
name: storybook-interaction-testing
version: 1.0.0
description: Write interaction tests directly in Storybook stories using play functions and the testing-library API
tools: [Bash, Read, Write, Edit]
category: testing
tags: [storybook, interaction-testing, play-functions, testing-library, visual, react, vue]
author: claude-skill-vault
created: 2026-05-24
---

# Storybook Interaction Testing

## Overview

Storybook Interaction Testing uses `play` functions inside stories to simulate user interactions and assert UI behavior. Tests run inside the browser against the rendered component and can be executed in CI with the `storybook/test-runner`. This gives you a single source of truth for component documentation, visual review, and automated behavior tests.

## When to Use

- Testing component interactions alongside component documentation
- Verifying UI state after user events (click, type, submit)
- Running visual + interaction tests together in CI
- Catching regressions in complex multi-state components
- Teams already using Storybook who want to add testing without a separate test file

## Installation

```bash
# Add interaction testing addon
npm install --save-dev @storybook/test @storybook/addon-interactions

# Add the test runner (for CI)
npm install --save-dev @storybook/test-runner

# Update .storybook/main.ts to add the addon
```

## Key Patterns

### Configure addon in .storybook/main.ts

```typescript
// .storybook/main.ts
import type { StorybookConfig } from "@storybook/react-vite";

const config: StorybookConfig = {
  stories: ["../src/**/*.stories.@(ts|tsx)"],
  addons: [
    "@storybook/addon-essentials",
    "@storybook/addon-interactions", // <-- add this
  ],
  framework: "@storybook/react-vite",
};
export default config;
```

### Story with play function

```typescript
// src/components/LoginForm/LoginForm.stories.tsx
import type { Meta, StoryObj } from "@storybook/react";
import { expect, fn, userEvent, within } from "@storybook/test";
import { LoginForm } from "./LoginForm";

const meta: Meta<typeof LoginForm> = {
  component: LoginForm,
  title: "Forms/LoginForm",
};
export default meta;
type Story = StoryObj<typeof LoginForm>;

export const Default: Story = {};

export const SuccessfulLogin: Story = {
  args: {
    onLogin: fn(),
  },
  play: async ({ canvasElement, args }) => {
    const canvas = within(canvasElement);

    // Type into fields
    await userEvent.type(
      canvas.getByLabelText("Email"),
      "alice@example.com"
    );
    await userEvent.type(
      canvas.getByLabelText("Password"),
      "secret123"
    );

    // Submit
    await userEvent.click(canvas.getByRole("button", { name: "Log in" }));

    // Assert callback was called
    await expect(args.onLogin).toHaveBeenCalledWith({
      email: "alice@example.com",
      password: "secret123",
    });
  },
};

export const ValidationErrors: Story = {
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement);

    // Submit empty form
    await userEvent.click(canvas.getByRole("button", { name: "Log in" }));

    // Assert error messages
    await expect(
      canvas.getByText("Email is required")
    ).toBeInTheDocument();
    await expect(
      canvas.getByText("Password is required")
    ).toBeInTheDocument();
  },
};

export const LoadingState: Story = {
  args: {
    onLogin: fn(async () => {
      await new Promise((r) => setTimeout(r, 2000));
    }),
  },
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement);

    await userEvent.type(canvas.getByLabelText("Email"), "alice@example.com");
    await userEvent.type(canvas.getByLabelText("Password"), "password");
    await userEvent.click(canvas.getByRole("button", { name: "Log in" }));

    await expect(canvas.getByRole("button", { name: "Logging in..." })).toBeDisabled();
  },
};
```

### Running in CI with test-runner

```bash
# Start Storybook in background and run tests
npx concurrently -k -s first -n "SB,TEST" \
  "npx storybook dev --port 6006 --quiet" \
  "npx wait-on tcp:6006 && npx test-storybook"
```

```yaml
# .github/workflows/storybook-tests.yml
name: Storybook Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 22
          cache: npm
      - run: npm ci
      - run: npm run build-storybook --quiet
      - run: |
          npx concurrently -k -s first -n "SB,TEST" \
            "npx http-server storybook-static --port 6006 --silent" \
            "npx wait-on tcp:6006 && npx test-storybook"
```

### MSW integration in Storybook

```typescript
// .storybook/preview.ts
import { initialize, mswLoader } from "msw-storybook-addon";
initialize();

const preview = {
  loaders: [mswLoader],
};
export default preview;
```

```typescript
// story with API mock
export const WithData: Story = {
  parameters: {
    msw: {
      handlers: [
        http.get("/api/users", () =>
          HttpResponse.json([{ id: 1, name: "Alice" }])
        ),
      ],
    },
  },
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement);
    await canvas.findByText("Alice");
  },
};
```

## Common Pitfalls

1. **`await` in play functions**: All user events and queries must be awaited or tests will pass before the action completes.
2. **`within(canvasElement)` scope**: Always scope queries to `canvasElement` to avoid selecting elements outside your component.
3. **`fn()` for spies**: Use `fn()` from `@storybook/test` (not `jest.fn()` or `vi.fn()`) for story-level mock functions.
4. **Test runner vs Storybook UI**: The `test-runner` executes play functions headlessly; the UI shows them interactively. Both use the same play function.
5. **Addon order**: `@storybook/addon-interactions` must come after essentials in the addons array.

## Related Skills

- vitest-testing — unit tests for non-UI logic
- playwright-component-testing — browser-level component tests outside Storybook
- msw-api-mocking — API mocking that works in Storybook and tests

## GitNexus Index

```
domain: testing
maturity: stable
complexity: medium
frameworks: react, vue, svelte, angular
config-file: .storybook/main.ts
ci-runner: @storybook/test-runner
```
