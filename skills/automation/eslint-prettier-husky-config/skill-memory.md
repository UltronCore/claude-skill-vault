# Skill Memory: ESLint Prettier Husky Config

## Purpose
Sets up the full code quality toolchain for Next.js and React projects: ESLint v9 flat config with React/TypeScript/a11y rules, Prettier formatting, Husky git hooks that run lint-staged on pre-commit, and a GitHub Actions workflow that fails CI on lint or formatting issues.

## Category notes
Belongs in automation because it establishes automated enforcement of code style and quality standards via git hooks and CI pipelines rather than manually applying formatting.

## Relationships
Pairs naturally with github-actions-ci-workflow for pipeline setup and testing-next-stack for broader test infrastructure. Often applied together when scaffolding a new project.

## Maintenance notes
None
