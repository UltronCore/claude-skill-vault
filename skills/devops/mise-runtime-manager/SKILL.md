---
name: mise-runtime-manager
version: 1.0.0
description: Manage polyglot runtime versions with mise (formerly rtx), a fast drop-in replacement for asdf
tools: [Bash, Read, Write, Edit]
category: developer-tooling
tags: [mise, rtx, runtime, versions, polyglot, node, python, ruby, go, java]
author: claude-skill-vault
created: 2026-05-24
---

# mise — Polyglot Runtime Version Manager

## Overview

mise (formerly rtx) is a fast, polyglot runtime version manager written in Rust. It's a drop-in replacement for asdf with better performance, a simpler config format, and built-in support for environment variables and task running. Use it to manage Node.js, Python, Ruby, Go, Java, and 200+ other runtimes per-project.

## When to Use

- Switching between multiple runtime versions across projects
- Replacing nvm, pyenv, rbenv, or asdf with a single tool
- Declaring runtime versions in `.mise.toml` for reproducibility
- Running project-specific tasks without a Makefile
- Setting environment variables scoped to a directory

## Installation

```bash
# macOS
brew install mise

# Linux / curl
curl https://mise.run | sh

# Activate in shell (add to ~/.zshrc or ~/.bashrc)
eval "$(mise activate zsh)"
# or
eval "$(mise activate bash)"

# Verify
mise --version
```

## Key Patterns

### Declaring runtimes per project

```toml
# .mise.toml (project root)
[tools]
node = "22.3.0"
python = "3.12.3"
go = "1.22.4"
ruby = "3.3.2"

[env]
DATABASE_URL = "postgres://localhost/myapp_dev"
NODE_ENV = "development"

[tasks.dev]
run = "npm run dev"

[tasks.test]
run = "pytest tests/"
```

### Installing and switching runtimes

```bash
# Install the version declared in .mise.toml
mise install

# Install a specific version globally
mise use --global node@22

# List installed versions
mise list

# Show current active versions
mise current

# Run a command with a specific version
mise exec node@18 -- node --version

# Search available versions
mise ls-remote python
```

### Using mise as asdf replacement

```bash
# mise reads .tool-versions files too
cat .tool-versions
# nodejs 22.3.0
# python 3.12.3

# Works without any migration — just run:
mise install
```

### Environment variable management

```toml
# .mise.toml
[env]
# Loaded automatically when entering the directory
AWS_PROFILE = "staging"
RAILS_ENV = "development"

# Dynamic values via shell
_.file = ".env"          # source a .env file
_.path = ["./bin"]       # prepend to PATH
```

### Task runner

```bash
# Define tasks in .mise.toml [tasks] section
# Run them with:
mise run dev
mise run test
mise run build -- --watch   # pass extra args

# List all tasks
mise tasks
```

### Shims vs PATH

```bash
# mise uses PATH modification (faster than shims)
# But shims are available for tools that need them:
mise settings set experimental true
mise generate shims
```

## Common Pitfalls

1. **Forgetting to activate**: `eval "$(mise activate zsh)"` must be in your shell config, not just run once.
2. **Global vs local**: Use `mise use --global` for system-wide defaults and `mise use` (no flag) for project-local overrides.
3. **Plugin not found**: Run `mise plugins install <name>` if a tool isn't recognized.
4. **Legacy `.nvmrc` / `.python-version`**: mise reads these by default — no migration needed.
5. **PATH ordering**: mise prepends to PATH; if another version manager is also active, conflicts may occur. Remove the old one from your shell config.

## Related Skills

- devbox-environments — Nix-based isolated dev environments (heavier isolation)
- earthly-builds — reproducible builds with container isolation
- nix-reproducible-builds — full Nix ecosystem for reproducibility

## GitNexus Index

```
domain: developer-tooling
maturity: stable
complexity: low
runtime-support: node, python, ruby, go, java, rust, elixir, erlang, 200+
config-file: .mise.toml, .tool-versions
replaces: asdf, nvm, pyenv, rbenv, sdkman
```
