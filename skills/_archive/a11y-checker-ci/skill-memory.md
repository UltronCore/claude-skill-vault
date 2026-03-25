# Skill Memory: A11y Checker CI

## Purpose
Configures automated WCAG accessibility compliance checks in CI/CD pipelines using axe-core with Playwright or pa11y-ci. Produces markdown reports posted as PR comments with violation severity levels, affected elements, and remediation guidance. Supports both GitHub Actions and GitLab CI.

## Category notes
Belongs in automation because its primary function is wiring accessibility checks into automated pipeline workflows, not writing accessibility features in application code.

## Relationships
Complements github-actions-ci-workflow (pipeline orchestration) and testing-next-stack (broader test infrastructure). Works directly with playwright-flow-recorder test files.

## Maintenance notes
None
