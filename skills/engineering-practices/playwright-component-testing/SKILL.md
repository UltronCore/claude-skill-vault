---
name: playwright-component-testing
version: 1.0.0
description: Test individual UI components in a real browser with Playwright Component Testing — no full app required
tools: [Bash, Read, Write, Edit]
category: testing
tags: [playwright, component-testing, react, vue, svelte, browser, ui]
author: claude-skill-vault
created: 2026-05-24
---

# Playwright Component Testing

## Overview

Playwright Component Testing (CT) renders individual components in a real browser (Chromium, Firefox, WebKit) without needing a full running application. It bridges the gap between unit tests (fast but no real browser) and E2E tests (slow, requires full app). Use it for interactive component behavior, accessibility, and visual regression.

## When to Use

- Testing components that rely on browser APIs (intersection observer, resize observer, etc.)
- Visual regression testing at the component level
- Testing component accessibility with real browser tools
- Interactions that need real pointer events or focus management
- Components with complex state that JSDOM doesn't handle correctly

## Installation

```bash
# Add Playwright CT to an existing project
npm init playwright@latest -- --ct

# Choose your framework (react, vue, svelte, solid)
# This creates playwright-ct.config.ts and a template

# Install browsers
npx playwright install
```

## Key Patterns

### playwright-ct.config.ts

```typescript
import { defineConfig, devices } from "@playwright/experimental-ct-react";

export default defineConfig({
  testDir: "./src",
  snapshotDir: "./snapshots",
  timeout: 10 * 1000,
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  reporter: "html",
  use: {
    ctPort: 3100,
    trace: "on-first-retry",
  },
  projects: [
    { name: "chromium", use: { ...devices["Desktop Chrome"] } },
    { name: "firefox", use: { ...devices["Desktop Firefox"] } },
    { name: "webkit", use: { ...devices["Desktop Safari"] } },
  ],
});
```

### React component test

```typescript
// src/components/Modal.spec.tsx
import { test, expect } from "@playwright/experimental-ct-react";
import { Modal } from "./Modal";

test.describe("Modal", () => {
  test("renders with title and content", async ({ mount }) => {
    const component = await mount(
      <Modal title="Confirm Delete" isOpen onClose={() => {}}>
        <p>Are you sure?</p>
      </Modal>
    );
    await expect(component.getByText("Confirm Delete")).toBeVisible();
    await expect(component.getByText("Are you sure?")).toBeVisible();
  });

  test("calls onClose when close button clicked", async ({ mount }) => {
    let closed = false;
    const component = await mount(
      <Modal title="Test" isOpen onClose={() => { closed = true; }}>
        Content
      </Modal>
    );
    await component.getByRole("button", { name: "Close" }).click();
    expect(closed).toBe(true);
  });

  test("traps focus within modal", async ({ mount, page }) => {
    const component = await mount(
      <Modal title="Focus Test" isOpen onClose={() => {}}>
        <button>First</button>
        <button>Last</button>
      </Modal>
    );
    await page.keyboard.press("Tab");
    await expect(component.getByRole("button", { name: "First" })).toBeFocused();
    await page.keyboard.press("Tab");
    await expect(component.getByRole("button", { name: "Last" })).toBeFocused();
    await page.keyboard.press("Tab"); // Should cycle back
    await expect(component.getByRole("button", { name: "Close" })).toBeFocused();
  });
});
```

### Visual snapshot testing

```typescript
test("matches visual snapshot", async ({ mount }) => {
  const component = await mount(<Button variant="primary" label="Submit" />);
  await expect(component).toHaveScreenshot("button-primary.png");
});

// Update snapshots:
// npx playwright test --update-snapshots
```

### Testing with context providers

```typescript
// src/test/mount-with-providers.tsx
import { mount as playwrightMount } from "@playwright/experimental-ct-react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { ThemeProvider } from "./ThemeProvider";

export function mount(component: React.ReactElement) {
  const queryClient = new QueryClient({
    defaultOptions: { queries: { retry: false } },
  });
  return playwrightMount(
    <QueryClientProvider client={queryClient}>
      <ThemeProvider>{component}</ThemeProvider>
    </QueryClientProvider>
  );
}
```

### Running tests

```bash
# Run all CT tests
npx playwright test --config=playwright-ct.config.ts

# Run with UI mode
npx playwright test --config=playwright-ct.config.ts --ui

# Run specific component
npx playwright test Modal --config=playwright-ct.config.ts

# Update visual snapshots
npx playwright test --update-snapshots --config=playwright-ct.config.ts
```

## Common Pitfalls

1. **CT vs E2E config**: Use a separate `playwright-ct.config.ts` for component tests and `playwright.config.ts` for E2E. They share the same binary but different configs.
2. **No routing**: CT doesn't start a dev server. Components can't navigate to routes — test routing separately in E2E.
3. **Snapshot drift**: Visual snapshots are OS and browser-version sensitive. Pin browser versions in CI.
4. **Provider wrapping**: Components that use React Context need providers. Create a custom `mount` helper.
5. **Port conflicts**: Default CT port is 3100 — ensure it's not in use.

## Related Skills

- vitest-testing — fast unit tests without real browser
- playwright — full E2E browser testing
- storybook-interaction-testing — component testing inside Storybook

## GitNexus Index

```
domain: testing
maturity: stable
complexity: medium
browsers: chromium, firefox, webkit
frameworks: react, vue, svelte, solid
config-file: playwright-ct.config.ts
```
