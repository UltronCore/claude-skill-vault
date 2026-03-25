# Testing Next Stack

**Category:** automation
**Status:** active
**Version:** v1

## What it does
Scaffolds a comprehensive testing infrastructure for Next.js applications including Vitest unit tests, React Testing Library component tests, and Playwright E2E tests with integrated axe-core accessibility scanning, test utilities, mock factories, and coverage configuration.

## When to use
- Starting a new Next.js project that needs a complete testing setup from scratch
- Migrating an existing project from Jest to Vitest
- Adding Playwright E2E testing alongside existing unit/component tests
- Standardizing testing patterns and utilities across a team or project

## What it produces
Generates vitest.config.ts, playwright.config.ts, test setup files, custom render utilities with providers, mock data factories, example unit/component/E2E test files, and updated package.json test scripts.

## Related skills
- playwright-flow-recorder
- a11y-checker-ci
- github-actions-ci-workflow
- nextjs-fullstack-scaffold
