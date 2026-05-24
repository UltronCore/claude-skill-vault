---
name: changesets-versioning
version: 1.0.0
description: Manage versioning and changelogs in monorepos with Changesets — intent-based, per-package version bumps
tools: [Bash, Read, Write, Edit]
category: developer-tooling
tags: [changesets, versioning, changelogs, monorepo, semver, npm, publishing]
author: claude-skill-vault
created: 2026-05-24
---

# Changesets — Monorepo Versioning and Changelogs

## Overview

Changesets is a workflow tool for managing versioning and changelogs in multi-package repositories. Unlike commit-based approaches, it uses explicit "changeset" files that describe what changed and at what semantic version level. This makes versioning a deliberate, human-readable process.

## When to Use

- Monorepos with multiple publishable packages
- Needing per-package version tracking (not monorepo-wide)
- Automated npm publishing with GitHub Actions
- Generating professional changelogs for each package
- Teams that want clear, intentional release workflows

## Installation

```bash
# Install
npm install --save-dev @changesets/cli

# Initialize (creates .changeset/ directory)
npx changeset init

# Verify
npx changeset --version
```

## Key Patterns

### Adding a changeset (developer workflow)

```bash
# After making changes, add a changeset description
npx changeset

# Interactive prompt:
# ? Which packages would you like to include?
#   [x] @myorg/ui
#   [x] @myorg/utils
# ? Which packages should have a major bump?
# ? Which packages should have a minor bump?
#   [x] @myorg/ui
# ? Which packages should have a patch bump?
#   [x] @myorg/utils
# ? Please enter a summary: Add new Button variant and fix utils type exports
```

This creates a file like `.changeset/fuzzy-lions-eat.md`:

```markdown
---
"@myorg/ui": minor
"@myorg/utils": patch
---

Add new Button variant and fix utils type exports
```

### .changeset/config.json

```json
{
  "$schema": "https://unpkg.com/@changesets/config@3.0.0/schema.json",
  "changelog": "@changesets/cli/changelog",
  "commit": false,
  "fixed": [],
  "linked": [["@myorg/ui", "@myorg/design-tokens"]],
  "access": "public",
  "baseBranch": "main",
  "updateInternalDependencies": "patch",
  "ignore": ["@myorg/private-app"]
}
```

### Version and publish workflow

```bash
# Consume changesets and bump versions (updates package.json + CHANGELOG.md)
npx changeset version

# Review the diffs, then commit
git add .
git commit -m "chore: version packages"

# Publish all changed packages to npm
npx changeset publish

# Or publish with tag
npx changeset publish --tag next
```

### GitHub Actions automated release

```yaml
# .github/workflows/release.yml
name: Release
on:
  push:
    branches: [main]

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: pnpm/action-setup@v3
      - uses: actions/setup-node@v4
        with:
          node-version: 22
          cache: pnpm
          registry-url: https://registry.npmjs.org
      - run: pnpm install --frozen-lockfile
      - name: Create Release Pull Request or Publish
        uses: changesets/action@v1
        with:
          publish: pnpm changeset publish
          version: pnpm changeset version
          commit: "chore: version packages"
          title: "chore: version packages"
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          NPM_TOKEN: ${{ secrets.NPM_TOKEN }}
          NODE_AUTH_TOKEN: ${{ secrets.NPM_TOKEN }}
```

### Pre-release workflow

```bash
# Enter pre-release mode
npx changeset pre enter next

# Add changesets normally
npx changeset

# Version (creates x.y.z-next.N versions)
npx changeset version

# Publish to "next" tag
npx changeset publish --tag next

# Exit pre-release
npx changeset pre exit
```

### Snapshots for testing

```bash
# Publish a snapshot version without consuming changesets
npx changeset version --snapshot canary
npx changeset publish --tag canary --no-git-tags
```

## Common Pitfalls

1. **Forgetting to add a changeset**: PRs without changesets won't increment versions. Add a CI check using `npx changeset status --since=main`.
2. **`linked` packages**: Use `linked` in config only for packages that must always have the same version. Use `fixed` for packages that are always released together.
3. **Internal dependency bumps**: Set `updateInternalDependencies` to `"patch"` to auto-bump internal consumers when a dep changes.
4. **Pre-release exit**: Always run `npx changeset pre exit` when done with pre-releases, or all subsequent releases stay as pre-releases.
5. **Squash merges lose changeset files**: Use merge commits or rebase to preserve changeset files in the branch history.

## Related Skills

- commitizen-commits — conventional commit message standards
- renovate-dependencies — automated dependency update PRs
- turborepo-monorepo — build orchestration for the same monorepo
- changelog-generator — alternative changelog generation from commits

## GitNexus Index

```
domain: developer-tooling
maturity: stable
complexity: medium
language: javascript, typescript
config-file: .changeset/config.json
publishing: npm, github-packages
```
