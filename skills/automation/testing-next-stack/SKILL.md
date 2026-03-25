---
name: testing-next-stack
description: Scaffolds comprehensive testing setup for Next.js applications including Vitest unit tests, React Testing Library component tests, Playwright E2E flows, accessibility testing via axe-core, and CI accessibility gates with PR reporting. Use when setting up test infrastructure, generating test files, adding accessibility checks, configuring A11y CI pipelines, or adding WCAG compliance gates to pull requests. Trigger terms include setup testing, scaffold tests, vitest, RTL, playwright, e2e tests, component tests, unit tests, accessibility testing, a11y tests, axe-core, a11y ci, wcag ci, accessibility pipeline, accessibility reports.
---

# Testing Next Stack

Scaffold complete testing infrastructure for Next.js applications with modern testing tools.

## Overview

To create a comprehensive testing setup for Next.js applications, use this skill to generate:
- Vitest configuration for fast unit tests
- React Testing Library setup for component testing
- Playwright configuration for E2E testing
- Accessibility testing with axe-core
- Test utilities and helpers
- Example test files demonstrating best practices

## When to Use

Use this skill when:
- Starting a new Next.js project requiring test infrastructure
- Migrating from Jest to Vitest
- Adding E2E testing with Playwright
- Implementing accessibility testing requirements
- Creating test utilities for worldbuilding app features (entities, relationships, timelines)
- Standardizing testing patterns across projects

## Setup Process

### 1. Analyze Project Structure

To understand the project layout, examine:
- Package.json for existing dependencies
- Next.js version and configuration
- TypeScript or JavaScript setup
- Existing testing infrastructure
- Component architecture

### 2. Install Dependencies

Generate package.json additions using `scripts/generate_test_deps.py`:

```bash
python scripts/generate_test_deps.py --nextjs-version <version> --typescript
```

Install required packages:
- `vitest` - Fast unit test runner
- `@testing-library/react` - Component testing utilities
- `@testing-library/jest-dom` - Custom matchers
- `@testing-library/user-event` - User interaction simulation
- `@playwright/test` - E2E testing framework
- `@axe-core/playwright` - Accessibility testing
- `@vitejs/plugin-react` - Vite React plugin
- `jsdom` - DOM implementation for Vitest

### 3. Generate Configuration Files

Create configuration files using templates from `assets/`:

**Vitest Configuration** (`vitest.config.ts`):
- Use template from `assets/vitest.config.ts`
- Configure path aliases matching Next.js
- Set up test environment (jsdom)
- Configure coverage reporting

**Playwright Configuration** (`playwright.config.ts`):
- Use template from `assets/playwright.config.ts`
- Configure browsers (chromium, firefox, webkit)
- Set baseURL for development server
- Configure screenshot and video capture
- Set up test artifacts directory

**Test Setup** (`test/setup.ts`):
- Use template from `assets/test-setup.ts`
- Import @testing-library/jest-dom
- Configure global test utilities
- Set up mock implementations

### 4. Create Test Utilities

Generate utility functions in `test/utils/`:

**Render Utilities** (`test/utils/render.tsx`):
- Custom render function wrapping providers
- Context providers (auth, theme, data)
- Router mocking for Next.js
- Query client setup for React Query

**Mock Factories** (`test/utils/factories.ts`):
- Entity mock data generators
- Relationship mock data
- User mock data
- API response mocks

**Test Helpers** (`test/utils/helpers.ts`):
- Async test utilities
- DOM query shortcuts
- Accessibility test helpers
- Custom matchers

### 5. Generate Example Tests

Create example test files demonstrating patterns:

**Unit Test Example** (`test/unit/example.test.ts`):
- Use template from `assets/examples/unit-test.ts`
- Demonstrate pure function testing
- Show async function testing
- Include edge case coverage

**Component Test Example** (`test/component/example.test.tsx`):
- Use template from `assets/examples/component-test.tsx`
- Demonstrate rendering and assertions
- Show user interaction testing
- Include accessibility checks with axe

**E2E Test Example** (`test/e2e/example.spec.ts`):
- Use template from `assets/examples/e2e-test.ts`
- Demonstrate user flow testing
- Show authentication flows
- Include accessibility scanning

### 6. Update Package Scripts

Add test scripts to package.json:

```json
{
  "scripts": {
    "test": "vitest",
    "test:ui": "vitest --ui",
    "test:coverage": "vitest --coverage",
    "test:e2e": "playwright test",
    "test:e2e:ui": "playwright test --ui",
    "test:e2e:debug": "playwright test --debug"
  }
}
```

## Test Patterns

### Unit Testing with Vitest

To test utility functions and business logic:

```typescript
import { describe, it, expect } from 'vitest'
import { validateEntityRelationship } from '@/lib/validation'

describe('validateEntityRelationship', () => {
  it('validates valid relationship', () => {
    const result = validateEntityRelationship({
      sourceId: '1',
      targetId: '2',
      type: 'BELONGS_TO'
    })
    expect(result.isValid).toBe(true)
  })

  it('rejects self-referential relationship', () => {
    const result = validateEntityRelationship({
      sourceId: '1',
      targetId: '1',
      type: 'BELONGS_TO'
    })
    expect(result.isValid).toBe(false)
  })
})
```

### Component Testing with RTL

To test React components:

```typescript
import { render, screen } from '@/test/utils/render'
import { userEvent } from '@testing-library/user-event'
import { axe } from '@axe-core/playwright'
import EntityCard from '@/components/EntityCard'

describe('EntityCard', () => {
  it('renders entity information', () => {
    render(<EntityCard entity={mockEntity} />)
    expect(screen.getByText(mockEntity.name)).toBeInTheDocument()
  })

  it('handles edit action', async () => {
    const onEdit = vi.fn()
    render(<EntityCard entity={mockEntity} onEdit={onEdit} />)

    await userEvent.click(screen.getByRole('button', { name: /edit/i }))
    expect(onEdit).toHaveBeenCalledWith(mockEntity.id)
  })

  it('has no accessibility violations', async () => {
    const { container } = render(<EntityCard entity={mockEntity} />)
    const results = await axe(container)
    expect(results.violations).toHaveLength(0)
  })
})
```

### E2E Testing with Playwright

To test complete user flows:

```typescript
import { test, expect } from '@playwright/test'
import { injectAxe, checkA11y } from '@axe-core/playwright'

test('user creates new entity', async ({ page }) => {
  await page.goto('/entities')

  // Inject axe for accessibility testing
  await injectAxe(page)

  // Navigate to create form
  await page.getByRole('button', { name: /create entity/i }).click()

  // Fill form
  await page.getByLabel(/name/i).fill('New Character')
  await page.getByLabel(/type/i).selectOption('character')
  await page.getByLabel(/description/i).fill('A mysterious traveler')

  // Submit
  await page.getByRole('button', { name: /save/i }).click()

  // Verify success
  await expect(page.getByText('New Character')).toBeVisible()

  // Check accessibility
  await checkA11y(page)
})
```

## Accessibility Testing

### Component-Level A11y

To add accessibility assertions in component tests:

```typescript
import { render } from '@/test/utils/render'
import { axe, toHaveNoViolations } from 'jest-axe'

expect.extend(toHaveNoViolations)

it('meets accessibility standards', async () => {
  const { container } = render(<MyComponent />)
  const results = await axe(container)
  expect(results).toHaveNoViolations()
})
```

### E2E A11y Scanning

To scan entire pages for accessibility issues:

```typescript
import { test } from '@playwright/test'
import { injectAxe, checkA11y, getViolations } from '@axe-core/playwright'

test('homepage accessibility', async ({ page }) => {
  await page.goto('/')
  await injectAxe(page)

  // Check entire page
  await checkA11y(page)

  // Or check specific element
  await checkA11y(page, '#main-content')

  // Or get violations for custom reporting
  const violations = await getViolations(page)
  expect(violations).toHaveLength(0)
})
```

## Coverage Configuration

To generate code coverage reports, configure Vitest coverage in `vitest.config.ts`:

```typescript
export default defineConfig({
  test: {
    coverage: {
      provider: 'v8',
      reporter: ['text', 'json', 'html'],
      exclude: [
        'node_modules/',
        'test/',
        '**/*.config.{ts,js}',
        '**/*.d.ts'
      ],
      thresholds: {
        lines: 80,
        functions: 80,
        branches: 80,
        statements: 80
      }
    }
  }
})
```

## Resources

Consult the following resources for detailed information:

- `references/vitest-setup.md` - Vitest configuration details
- `references/rtl-patterns.md` - React Testing Library best practices
- `references/playwright-setup.md` - Playwright configuration guide
- `references/a11y-testing.md` - Accessibility testing guidelines
- `assets/vitest.config.ts` - Vitest configuration template
- `assets/playwright.config.ts` - Playwright configuration template
- `assets/test-setup.ts` - Test setup template
- `assets/examples/` - Example test files

## A11y CI Pipeline

Add automated accessibility gates to CI with PR reporting.

### Setup

```bash
npm install -D @axe-core/playwright pa11y-ci
```

### GitHub Actions workflow

```yaml
name: Accessibility Tests
on:
  pull_request:
    branches: [main]

jobs:
  a11y:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '20', cache: 'npm' }
      - run: npm ci
      - run: npm run build
      - run: npm start &
      - run: npx wait-on http://localhost:3000 -t 60000
      - run: npm run test:a11y
      - name: Comment PR
        if: github.event_name == 'pull_request' && always()
        uses: actions/github-script@v7
        with:
          script: |
            const fs = require('fs')
            const report = fs.readFileSync('accessibility-report.md', 'utf8')
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: report
            })
```

### Violation thresholds

```typescript
// In your a11y test
const results = await new AxeBuilder({ page }).analyze()
const critical = results.violations.filter(v => v.impact === 'critical')
expect(critical).toHaveLength(0)  // Zero critical violations required
```

### WCAG compliance levels

```typescript
const results = await new AxeBuilder({ page })
  .withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa'])
  .analyze()
```

## Next Steps

After scaffolding the testing infrastructure:

1. Run `npm install` to install dependencies
2. Execute `npm test` to verify Vitest setup
3. Execute `npm run test:e2e` to verify Playwright setup
4. Review and customize configuration files
5. Add tests for existing components and features
6. Configure CI/CD pipeline with test execution
7. Set up coverage reporting in CI
8. Document testing guidelines for team
