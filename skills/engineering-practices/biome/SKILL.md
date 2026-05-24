---
name: biome
version: 1.0.0
description: Fast Rust-based linter and formatter — replaces ESLint + Prettier
tools: [Read, Edit, Write, Bash]
tags: [frontend, web, linting, formatting, biome, rust, dx, eslint, prettier]
author: claude-skill-vault
created: 2026-05-24
---

# Biome — Fast Rust-Based Linter & Formatter

## Overview
Biome is a high-performance toolchain written in Rust that handles JavaScript/TypeScript formatting, linting, and import organizing in a single binary. It's largely compatible with Prettier's formatting output and replaces ESLint for many use cases. It runs 35x faster than Prettier and requires zero configuration to get started.

## When to Use
- Replacing ESLint + Prettier with a single, faster tool
- Monorepos where linting/formatting speed is a bottleneck
- New projects wanting zero-config tooling from day one
- CI pipelines where lint/format checks are a bottleneck
- Projects that want consistent formatting without Prettier's slow JS runtime

## Installation / Setup

```bash
npm install --save-dev --save-exact @biomejs/biome

# Initialize config
npx @biomejs/biome init

# Format all files
npx @biomejs/biome format --write .

# Lint all files
npx @biomejs/biome lint .

# Format + lint + organize imports in one pass
npx @biomejs/biome check --write .
```

### biome.json (Configuration)
```json
{
  "$schema": "https://biomejs.dev/schemas/1.9.0/schema.json",
  "vcs": {
    "enabled": true,
    "clientKind": "git",
    "useIgnoreFile": true
  },
  "formatter": {
    "enabled": true,
    "indentStyle": "space",
    "indentWidth": 2,
    "lineWidth": 100,
    "lineEnding": "lf"
  },
  "javascript": {
    "formatter": {
      "quoteStyle": "single",
      "trailingCommas": "all",
      "semicolons": "always"
    }
  },
  "linter": {
    "enabled": true,
    "rules": {
      "recommended": true,
      "complexity": {
        "noExcessiveCognitiveComplexity": "warn"
      },
      "correctness": {
        "noUnusedVariables": "error"
      },
      "suspicious": {
        "noConsole": "warn"
      }
    }
  },
  "organizeImports": {
    "enabled": true
  },
  "files": {
    "ignore": ["node_modules", "dist", ".next", "coverage"]
  }
}
```

## Key Patterns

### package.json Scripts
```json
{
  "scripts": {
    "lint": "biome lint .",
    "format": "biome format --write .",
    "check": "biome check --write .",
    "ci:check": "biome ci ."
  }
}
```

### Per-File / Per-Directory Overrides
```json
{
  "overrides": [
    {
      "include": ["**/*.test.ts", "**/*.spec.ts"],
      "linter": {
        "rules": {
          "suspicious": {
            "noConsole": "off"
          }
        }
      }
    },
    {
      "include": ["**/generated/**"],
      "linter": { "enabled": false },
      "formatter": { "enabled": false }
    }
  ]
}
```

### Inline Rule Suppression
```ts
// biome-ignore lint/suspicious/noConsole: intentional debug logging
console.log('Debug:', data);

// biome-ignore lint/correctness/noUnusedVariables: used by external library
export const unused = 'value';

// biome-ignore format: hand-formatted for clarity
const matrix = [
  1, 0, 0,
  0, 1, 0,
  0, 0, 1,
];
```

### CI Integration
```yaml
# .github/workflows/ci.yml
- name: Biome check
  uses: biomejs/setup-biome@v2
  with:
    version: latest
- run: biome ci .
```

### VSCode Integration
```json
// .vscode/extensions.json
{
  "recommendations": ["biomejs.biome"]
}

// .vscode/settings.json
{
  "editor.defaultFormatter": "biomejs.biome",
  "editor.formatOnSave": true,
  "[javascript]": { "editor.defaultFormatter": "biomejs.biome" },
  "[typescript]": { "editor.defaultFormatter": "biomejs.biome" },
  "[json]": { "editor.defaultFormatter": "biomejs.biome" }
}
```

### Migrating from ESLint + Prettier
```bash
# Biome provides a migration command
npx @biomejs/biome migrate eslint --write
npx @biomejs/biome migrate prettier --write

# Remove old tools (after verifying Biome covers all rules)
npm uninstall eslint prettier @typescript-eslint/parser @typescript-eslint/eslint-plugin
rm .eslintrc.* .prettierrc.*
```

## Common Pitfalls
- **Biome doesn't cover all ESLint plugins**: `eslint-plugin-react-hooks`, `eslint-plugin-jsx-a11y`, and others have no Biome equivalent yet — keep ESLint for those specific rules only
- **`biome ci` vs `biome check`**: `ci` is read-only (no `--write`), exits non-zero on any issue — use in CI; `check --write` for local dev
- **Organizing imports changes semantics**: if import order matters for side effects, disable `organizeImports` or add `// biome-ignore` comments
- **JSX formatting differs from Prettier in edge cases**: run `biome format` after migration and review diffs before committing
- **No plugin system**: Biome doesn't support custom lint rules yet — complex custom rules still require ESLint

## Related Skills
- `eslint-prettier-husky-config` — when ESLint plugins are still needed alongside Biome
- `vite-plugin-dev` — Biome integrates with Vite build pipelines
- `turbopack` — pairs with Turbopack in Next.js projects
- `github-actions-ci-workflow` — CI setup

## GitNexus Index
```
domain: frontend/build-tools
tier: toolchain
runtime: native-binary
language: ts,js,json
replaces: eslint,prettier
```
