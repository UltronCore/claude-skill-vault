# Skill Memory: GitHub Actions CI Workflow

## Purpose
Generates complete GitHub Actions workflow YAML files for lint, test, build, and deploy pipelines. Includes multi-level caching strategies for node_modules and Next.js build cache, preview deployment automation with PR URL comments, and support for multiple deployment providers.

## Category notes
Belongs in automation as it directly configures the automated CI/CD infrastructure rather than application-level code.

## Relationships
Often used alongside eslint-prettier-husky-config (for lint jobs), testing-next-stack (for test jobs), and a11y-checker-ci (for accessibility jobs). Serves as the orchestration layer for other automation skills.

## Maintenance notes
None
