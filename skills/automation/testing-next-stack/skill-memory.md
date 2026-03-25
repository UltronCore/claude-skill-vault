# Skill Memory: Testing Next Stack

## Purpose
Provides a complete testing scaffold for Next.js projects covering three layers: Vitest for unit/logic tests, React Testing Library for component interaction tests, and Playwright for E2E user flows. Includes axe-core accessibility assertions at both component and page levels, shared test utilities with provider wrappers, and mock data factories.

## Category notes
Belongs in automation as it sets up the automated testing infrastructure that enables continuous quality verification, not one-off test writing.

## Relationships
Foundational skill for test infrastructure; playwright-flow-recorder generates test files that target this setup. a11y-checker-ci extends the accessibility patterns introduced here to the CI pipeline. Often used together with nextjs-fullstack-scaffold when starting a new project.

## Maintenance notes
None
