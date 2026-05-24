---
name: lefthook-git-hooks
version: 1.0.0
description: Manage fast, polyglot git hooks with Lefthook — parallel execution, filtering, and cross-team consistency
tools: [Bash, Read, Write, Edit]
category: developer-tooling
tags: [lefthook, git-hooks, pre-commit, commit-msg, husky, polyglot]
author: claude-skill-vault
created: 2026-05-24
---

# Lefthook — Fast Polyglot Git Hooks Manager

## Overview

Lefthook is a fast git hooks manager written in Go. It runs hooks in parallel, supports filtering by file type, works with any language, and is significantly faster than alternatives like Husky. A single `lefthook.yml` replaces scattered `.git/hooks/` scripts.

## When to Use

- Enforcing linting, formatting, and tests before commits
- Running type checks or build verification before push
- Ensuring commit message conventions (conventional commits)
- Polyglot repos where hooks span multiple languages
- Teams that need reliable, fast pre-commit checks

## Installation

```bash
# macOS
brew install lefthook

# npm (project-local, works in any language repo)
npm install --save-dev @evilmartians/lefthook

# Go
go install github.com/evilmartians/lefthook@latest

# Install git hooks (run once after adding lefthook.yml)
lefthook install

# Verify
lefthook --version
```

## Key Patterns

### Basic lefthook.yml

```yaml
# lefthook.yml
pre-commit:
  parallel: true
  commands:
    lint:
      glob: "*.{ts,tsx,js,jsx}"
      run: npx eslint {staged_files}
    format:
      glob: "*.{ts,tsx,js,jsx,css}"
      run: npx prettier --check {staged_files}
    type-check:
      run: npx tsc --noEmit

commit-msg:
  commands:
    conventional:
      run: npx commitlint --edit {1}

pre-push:
  commands:
    tests:
      run: npm test
```

### Running hooks manually

```bash
# Run a specific hook
lefthook run pre-commit

# Run with verbose output
lefthook run pre-commit --verbose

# Skip hooks for a commit (emergency)
LEFTHOOK=0 git commit -m "emergency fix"

# Or per-hook skip
git commit -m "wip" --no-verify
```

### Parallel execution with filtering

```yaml
pre-commit:
  parallel: true
  commands:
    go-lint:
      glob: "**/*.go"
      run: golangci-lint run {staged_files}
    go-test:
      glob: "**/*.go"
      run: go test ./...
    py-lint:
      glob: "**/*.py"
      run: ruff check {staged_files}
    py-format:
      glob: "**/*.py"
      run: black --check {staged_files}
    js-lint:
      glob: "**/*.{ts,js}"
      run: npx eslint {staged_files}
```

### Scripts (shell scripts as hooks)

```yaml
# lefthook.yml
pre-commit:
  scripts:
    "check-secrets.sh":
      runner: bash
```

```bash
# .lefthook/pre-commit/check-secrets.sh
#!/bin/bash
if git diff --cached | grep -E "(password|secret|api_key)\s*=" > /dev/null 2>&1; then
  echo "Potential secret detected in staged changes!"
  exit 1
fi
```

### Skipping on CI

```yaml
# lefthook.yml
# Automatically skips on CI (LEFTHOOK env var detection)
pre-commit:
  skip:
    - merge
    - rebase
  commands:
    lint:
      run: npx eslint {staged_files}
```

### Per-project local overrides

```yaml
# lefthook-local.yml (gitignored, developer overrides)
pre-commit:
  commands:
    lint:
      skip: true  # Disable lint locally for this developer
```

## Common Pitfalls

1. **Forgetting `lefthook install`**: Adding `lefthook.yml` doesn't activate hooks — run `lefthook install` after changes.
2. **`{staged_files}` vs `{all_files}`**: Use `{staged_files}` for pre-commit to only check changed files. `{all_files}` runs on everything.
3. **Slow sequential hooks**: Add `parallel: true` to run commands concurrently.
4. **Hook not running**: Check that `lefthook install` ran and that `.git/hooks/pre-commit` exists and is executable.
5. **Skipping hooks in CI**: Set `LEFTHOOK=0` in CI env vars if you don't want hooks to run there.

## Related Skills

- commitizen-commits — standardized commit message tooling
- eslint-prettier-husky-config — ESLint/Prettier config (Husky alternative)
- git-guardrails-claude-code — git safety for Claude Code

## GitNexus Index

```
domain: developer-tooling
maturity: stable
complexity: low
language: polyglot
config-file: lefthook.yml, lefthook-local.yml
written-in: go
replaces: husky, pre-commit
```
