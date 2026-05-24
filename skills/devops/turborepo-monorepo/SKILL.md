---
name: turborepo-monorepo
version: 1.0.0
description: Speed up monorepo builds with Turborepo's intelligent task scheduling, caching, and parallelism
tools: [Bash, Read, Write, Edit]
category: developer-tooling
tags: [turborepo, monorepo, build, caching, nx, pnpm, workspaces]
author: claude-skill-vault
created: 2026-05-24
---

# Turborepo — High-Performance Monorepo Builds

## Overview

Turborepo is a high-performance build system for JavaScript/TypeScript monorepos. It caches build outputs locally and in the cloud, runs tasks in parallel based on dependency graphs, and can cut CI times by 90%+ through intelligent caching.

## When to Use

- Managing a JS/TS monorepo with multiple packages or apps
- Slow CI builds that repeat unchanged work
- Coordinating build, test, lint, and type-check across packages
- Sharing code between multiple Next.js apps, Expo apps, or libraries

## Installation

```bash
# Create a new turborepo (recommended)
npx create-turbo@latest

# Add Turborepo to an existing monorepo
npm install -D turbo
# or
pnpm add -D turbo -w

# Verify
npx turbo --version
```

## Key Patterns

### turbo.json configuration

```json
{
  "$schema": "https://turbo.build/schema.json",
  "tasks": {
    "build": {
      "dependsOn": ["^build"],
      "inputs": ["src/**", "package.json", "tsconfig.json"],
      "outputs": ["dist/**", ".next/**"]
    },
    "test": {
      "dependsOn": ["build"],
      "inputs": ["src/**", "tests/**"],
      "outputs": []
    },
    "lint": {
      "inputs": ["src/**", ".eslintrc*"],
      "outputs": []
    },
    "type-check": {
      "dependsOn": ["^build"],
      "inputs": ["src/**", "tsconfig.json"],
      "outputs": []
    },
    "dev": {
      "cache": false,
      "persistent": true
    }
  }
}
```

### Monorepo structure

```
my-monorepo/
├── apps/
│   ├── web/          # Next.js app
│   └── mobile/       # Expo app
├── packages/
│   ├── ui/           # Shared component library
│   ├── config/       # Shared config (ESLint, TypeScript)
│   └── utils/        # Shared utilities
├── turbo.json
└── package.json (workspaces)
```

### Running tasks

```bash
# Run build for all packages
turbo build

# Run build only for changed packages
turbo build --filter=[HEAD^1]

# Run dev for specific apps
turbo dev --filter=web --filter=mobile

# Run test with verbose output
turbo test --verbosity=2

# Dry run to see what would execute
turbo build --dry-run

# Force re-run ignoring cache
turbo build --force
```

### Remote caching (Vercel)

```bash
# Login to Vercel for remote caching
npx turbo login

# Link to Vercel remote cache
npx turbo link

# Or set env vars for CI
TURBO_TOKEN=<token> TURBO_TEAM=<team> turbo build
```

### Package dependencies

```json
// packages/ui/package.json
{
  "name": "@myorg/ui",
  "main": "./src/index.ts",
  "exports": {
    ".": "./src/index.ts"
  }
}

// apps/web/package.json
{
  "dependencies": {
    "@myorg/ui": "workspace:*"
  }
}
```

### CI integration

```yaml
# .github/workflows/ci.yml
name: CI
on: [push]
env:
  TURBO_TOKEN: ${{ secrets.TURBO_TOKEN }}
  TURBO_TEAM: ${{ vars.TURBO_TEAM }}
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 2
      - uses: pnpm/action-setup@v3
      - uses: actions/setup-node@v4
        with:
          node-version: 22
          cache: pnpm
      - run: pnpm install --frozen-lockfile
      - run: pnpm turbo build test lint
```

## Common Pitfalls

1. **Missing `outputs` configuration**: If you don't declare outputs, caching won't restore build artifacts.
2. **`^build` syntax**: The `^` prefix means "run this task in all dependencies first." Missing this breaks incremental builds.
3. **`persistent` tasks**: Dev servers and watch tasks need `"cache": false` and `"persistent": true`.
4. **Workspace protocol**: Use `"workspace:*"` (pnpm) or `"*"` (npm/yarn) for internal package references.
5. **Cache invalidation**: Add all relevant `inputs` (config files, env files) to avoid stale cache hits.

## Related Skills

- moonrepo-build-system — alternative build system with task inheritance
- monorepo-architect — overall monorepo strategy
- changesets-versioning — versioning and changelogs in monorepos

## GitNexus Index

```
domain: developer-tooling
maturity: stable
complexity: medium
language: javascript, typescript
config-file: turbo.json
remote-cache: vercel, custom
```
