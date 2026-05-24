---
name: moonrepo-build-system
version: 1.0.0
description: Use moon for task orchestration, toolchain management, and project graph in polyglot monorepos
tools: [Bash, Read, Write, Edit]
category: developer-tooling
tags: [moonrepo, moon, monorepo, build, tasks, toolchain, rust]
author: claude-skill-vault
created: 2026-05-24
---

# Moonrepo — Build System and Monorepo Tool

## Overview

Moon (moonrepo) is a Rust-powered build system for polyglot monorepos. It manages toolchains (Node.js, Rust, Go, Python), provides a project graph, enforces task dependencies, and includes a built-in code generation system. It's more opinionated than Turborepo but supports multiple languages natively.

## When to Use

- Polyglot monorepos (Node + Go, Node + Rust, etc.)
- Needing toolchain management alongside build orchestration
- Wanting more structure than Turborepo with project configs
- Code generation (scaffolding new packages from templates)
- Enforcing project boundaries and ownership

## Installation

```bash
# macOS / Linux
curl -fsSL https://moonrepo.dev/install/moon.sh | bash

# Or via npm (project-local)
npm install --save-dev @moonrepo/cli

# Initialize in a monorepo
moon init

# Verify
moon --version
```

## Key Patterns

### Workspace config (.moon/workspace.yml)

```yaml
# .moon/workspace.yml
vcs:
  manager: git
  defaultBranch: main

projects:
  - apps/*
  - packages/*

node:
  version: "22.3.0"
  packageManager: pnpm
  addEnginesConstraint: true
  syncVersionManagerConfig: nvmrc

typescript:
  createMissingConfig: true
  syncProjectReferences: true

codeowners:
  syncOnRun: true
```

### Project config (moon.yml)

```yaml
# packages/ui/moon.yml
language: typescript
type: library

tasks:
  build:
    command: tsc --build
    inputs:
      - src/**/*
      - tsconfig.json
    outputs:
      - dist

  test:
    command: vitest run
    inputs:
      - src/**/*
      - tests/**/*
    deps:
      - build

  lint:
    command: eslint src --ext .ts,.tsx
    inputs:
      - src/**/*

fileGroups:
  sources:
    - src/**/*
  tests:
    - tests/**/*
```

### Running tasks

```bash
# Run a task in all projects
moon run :build
moon run :test

# Run task in specific project
moon run ui:build
moon run web:dev

# Run with dependencies
moon run api:build --dependents

# Check affected projects (from git changes)
moon query touched-files
moon run :test --affected

# Interactive project graph
moon project-graph
```

### Toolchain management

```yaml
# .moon/toolchain.yml
node:
  version: "22.3.0"
  packageManager: pnpm

rust:
  version: "1.78.0"
  edition: "2021"
  components:
    - clippy
    - rustfmt
```

### Code generation (templates)

```bash
# Create a template
moon generate package --template

# Use a template to scaffold a new package
moon generate package my-new-lib

# Template file: templates/package/moon.yml.tera
```

```
# templates/package/moon.yml.tera
language: typescript
type: library

tasks:
  build:
    command: tsc --build
  test:
    command: vitest run
```

### CI integration

```yaml
# .github/workflows/ci.yml
name: CI
on: [push, pull_request]
jobs:
  ci:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: moonrepo/setup-moon-action@v1
      - run: moon ci
        # moon ci automatically detects affected projects
        # and runs their tasks based on the project graph
```

## Common Pitfalls

1. **moon ci vs moon run**: `moon ci` uses git history to detect changes and only runs affected tasks. `moon run` always runs.
2. **Task inputs must be exhaustive**: Missing an input file means moon won't invalidate the cache when that file changes.
3. **Toolchain pinning**: moon downloads exact versions — ensure your team's CI and local machines agree on versions in `.moon/toolchain.yml`.
4. **Project detection**: Projects must match the glob patterns in `workspace.yml`. A missing `moon.yml` means the project is invisible to moon.
5. **Codeowners sync**: Enable `syncOnRun: true` carefully in large repos — it rewrites `CODEOWNERS` on every run.

## Related Skills

- turborepo-monorepo — JS-focused alternative build system
- monorepo-architect — overall strategy for monorepo design
- mise-runtime-manager — lighter toolchain management

## GitNexus Index

```
domain: developer-tooling
maturity: stable
complexity: medium-high
language: polyglot (node, rust, go, python)
config-file: .moon/workspace.yml, moon.yml
written-in: rust
```
