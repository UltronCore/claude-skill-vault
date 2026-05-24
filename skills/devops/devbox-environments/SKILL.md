---
name: devbox-environments
version: 1.0.0
description: Create isolated, reproducible development environments using Devbox (Nix-backed) without Docker overhead
tools: [Bash, Read, Write, Edit]
category: developer-tooling
tags: [devbox, nix, dev-environments, isolated, reproducible, shell]
author: claude-skill-vault
created: 2026-05-24
---

# Devbox — Isolated Dev Environments (Nix-based)

## Overview

Devbox by Jetify creates portable, isolated development environments backed by Nix without requiring you to learn Nix syntax. Each project gets its own shell with exact package versions, env vars, and initialization scripts — reproducible across machines and CI.

## When to Use

- Ensuring every team member runs identical tool versions
- Avoiding "works on my machine" problems without Docker
- Sharing a reproducible shell for open-source projects
- Setting up complex toolchains (databases, compilers, CLIs) in seconds
- Running isolated environments in CI without containers

## Installation

```bash
# Install Devbox (installs Nix internally if needed)
curl -fsSL https://get.jetify.com/devbox | bash

# Verify
devbox version

# Initialize a project
cd my-project
devbox init
```

## Key Patterns

### Adding packages and starting a shell

```bash
# Search for a package
devbox search nodejs

# Add packages to your project
devbox add nodejs@22 python@3.12 postgresql@16 redis

# Start the isolated shell
devbox shell

# Run a command without entering the shell
devbox run -- npm install
```

### devbox.json configuration

```json
{
  "$schema": "https://raw.githubusercontent.com/jetify-com/devbox/0.12.0/.schema/devbox.schema.json",
  "packages": [
    "nodejs@22",
    "python@3.12",
    "postgresql@16",
    "redis@7",
    "gh@2",
    "jq@1.7"
  ],
  "env": {
    "DATABASE_URL": "postgres://localhost/myapp_dev",
    "REDIS_URL": "redis://localhost:6379",
    "NODE_ENV": "development"
  },
  "shell": {
    "init_hook": [
      "echo 'Devbox environment ready!'",
      "npm install --silent"
    ],
    "scripts": {
      "dev": "npm run dev",
      "test": "pytest tests/ -v",
      "db:start": "pg_ctl start -D $PGDATA",
      "db:stop": "pg_ctl stop -D $PGDATA"
    }
  }
}
```

### Running scripts

```bash
# Run a defined script
devbox run dev
devbox run test
devbox run db:start

# List all available scripts
devbox run --list
```

### Services management

```bash
# Start background services (postgres, redis, etc.)
devbox services start

# List running services
devbox services ls

# Stop services
devbox services stop postgresql
```

### Sharing with a team

```bash
# Commit devbox.json and devbox.lock to git
git add devbox.json devbox.lock
git commit -m "chore: add devbox environment"

# Teammates just run:
devbox shell
# Everything is installed automatically
```

### CI integration

```yaml
# .github/workflows/ci.yml
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: jetify-com/devbox-install-action@v0.11.0
        with:
          enable-cache: true
      - run: devbox run test
```

### Generating Dockerfiles and Nix flakes

```bash
# Generate a Dockerfile from your devbox.json
devbox generate dockerfile

# Generate a Nix flake
devbox generate flake

# Generate direnv integration (.envrc)
devbox generate direnv
```

## Common Pitfalls

1. **First install is slow**: Nix downloads packages from scratch. Subsequent starts use cache and are fast.
2. **PATH conflicts**: Exit your devbox shell before running native system commands if you see version conflicts.
3. **Services not persisting**: Run `devbox services start` each time; services don't auto-start with the shell.
4. **nixpkgs version**: Pin `devbox.lock` in version control to ensure reproducibility across upgrades.
5. **Apple Silicon**: Some packages may not yet have ARM64 builds in nixpkgs — check the search results for available platforms.

## Related Skills

- mise-runtime-manager — lighter-weight runtime version manager (no Nix)
- nix-reproducible-builds — full Nix ecosystem for advanced users
- docker-expert — container-based isolation for production parity

## GitNexus Index

```
domain: developer-tooling
maturity: stable
complexity: medium
backed-by: nix, nixpkgs
config-file: devbox.json, devbox.lock
replaces: docker-compose (for dev), nvm+pyenv combos
```
