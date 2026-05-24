---
name: commitizen-commits
version: 1.0.0
description: Enforce standardized commit messages using Commitizen and Conventional Commits specification
tools: [Bash, Read, Write, Edit]
category: developer-tooling
tags: [commitizen, conventional-commits, git, changelogs, versioning, semver]
author: claude-skill-vault
created: 2026-05-24
---

# Commitizen — Standardized Commit Messages

## Overview

Commitizen enforces the Conventional Commits specification for git commit messages. It provides an interactive CLI prompt for crafting compliant messages, integrates with CI to validate commit messages, and enables automatic changelog generation and semantic versioning from commit history.

## When to Use

- Enforcing commit message standards across a team
- Enabling automated changelogs (see changesets-versioning)
- Automating semantic version bumps based on commit types
- Making `git log` readable and machine-parseable
- Setting up release automation pipelines

## Installation

```bash
# Global installation (for the interactive CLI)
npm install -g commitizen cz-conventional-changelog

# Configure globally
echo '{ "path": "cz-conventional-changelog" }' > ~/.czrc

# Project-level installation
npm install --save-dev commitizen cz-conventional-changelog

# Initialize project config
npx commitizen init cz-conventional-changelog --save-dev --save-exact
```

## Key Patterns

### Conventional Commits format

```
<type>(<scope>): <subject>

<body>

<footer>
```

Types:
- `feat` — new feature (triggers MINOR bump)
- `fix` — bug fix (triggers PATCH bump)
- `docs` — documentation only
- `style` — formatting, no code change
- `refactor` — refactoring
- `test` — adding tests
- `chore` — maintenance tasks
- `perf` — performance improvements
- `ci` — CI configuration changes
- `build` — build system changes
- `BREAKING CHANGE` — in footer (triggers MAJOR bump)

### Using the interactive prompt

```bash
# Use `git cz` instead of `git commit`
git add .
git cz

# Or via npx
npx cz

# Interactive prompt:
# ? Select the type of change: feat
# ? What is the scope? auth
# ? Short description: add OAuth2 login flow
# ? Longer description? (optional)
# ? Breaking changes? No
# ? Issues closed? #42
```

### package.json configuration

```json
{
  "scripts": {
    "commit": "cz"
  },
  "config": {
    "commitizen": {
      "path": "./node_modules/cz-conventional-changelog"
    }
  },
  "devDependencies": {
    "commitizen": "^4.3.0",
    "cz-conventional-changelog": "^3.3.0",
    "@commitlint/cli": "^19.0.0",
    "@commitlint/config-conventional": "^19.0.0"
  }
}
```

### Validating with commitlint

```js
// commitlint.config.js
module.exports = {
  extends: ["@commitlint/config-conventional"],
  rules: {
    "type-enum": [
      2,
      "always",
      ["feat", "fix", "docs", "style", "refactor", "test", "chore", "perf", "ci", "build", "revert"],
    ],
    "scope-case": [2, "always", "kebab-case"],
    "subject-max-length": [2, "always", 72],
  },
};
```

### Integration with Lefthook (commit-msg hook)

```yaml
# lefthook.yml
commit-msg:
  commands:
    commitlint:
      run: npx commitlint --edit {1}
```

### Integration with GitHub Actions

```yaml
# .github/workflows/commitlint.yml
name: Commitlint
on: [push, pull_request]
jobs:
  commitlint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: wagoid/commitlint-github-action@v5
```

### Example compliant commits

```bash
# Feature with scope
git commit -m "feat(auth): add password strength indicator"

# Bug fix referencing issue
git commit -m "fix(api): handle null response from payment gateway

Fixes #234

The payment gateway occasionally returns null instead of an error
object when the card is declined."

# Breaking change
git commit -m "feat(api)!: remove deprecated v1 endpoints

BREAKING CHANGE: The /api/v1/* endpoints have been removed.
Migrate to /api/v2/* before upgrading."

# Chore
git commit -m "chore(deps): update dependencies to latest versions"
```

## Common Pitfalls

1. **Scope consistency**: Define allowed scopes in `commitlint.config.js` to prevent drift.
2. **Breaking changes**: Must appear either as `!` after type/scope OR in the footer as `BREAKING CHANGE:`.
3. **Subject tense**: Use imperative mood ("add feature" not "added feature").
4. **Long subjects**: Keep the subject under 72 characters; use the body for detail.
5. **Merge commits**: Commitlint may reject auto-generated merge commit messages — configure `ignores` for merge commits.

## Related Skills

- lefthook-git-hooks — enforce commitlint via git hooks
- changesets-versioning — monorepo versioning using conventional commits
- changelog-generator — auto-generate changelogs from commit history

## GitNexus Index

```
domain: developer-tooling
maturity: stable
complexity: low
spec: conventional-commits
config-files: .czrc, commitlint.config.js, package.json
integrates-with: lefthook, github-actions, semantic-release
```
