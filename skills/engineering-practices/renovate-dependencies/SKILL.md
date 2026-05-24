---
name: renovate-dependencies
version: 1.0.0
description: Automate dependency updates across all ecosystems with Renovate Bot — PRs, scheduling, grouping, and automerge
tools: [Bash, Read, Write, Edit]
category: developer-tooling
tags: [renovate, dependencies, automation, updates, security, npm, pip, go, docker]
author: claude-skill-vault
created: 2026-05-24
---

# Renovate — Automated Dependency Updates

## Overview

Renovate automates dependency updates for 90+ package ecosystems (npm, pip, Go modules, Docker, Helm, Terraform, GitHub Actions, and more). It opens PRs with changelogs, groups related updates, respects schedules, and can automerge safe updates. It runs as a GitHub App, GitLab CI job, or self-hosted.

## When to Use

- Keeping dependencies current without manual effort
- Automating security patch PRs
- Grouping dependency updates to reduce PR noise
- Managing Docker base image updates alongside code
- Enforcing dependency update policies across multiple repos

## Installation

### GitHub App (recommended)

1. Install the Renovate GitHub App: https://github.com/apps/renovate
2. Grant access to your repository
3. Renovate will open an onboarding PR with a default config

### Self-hosted

```bash
# Run locally (one-shot)
npx renovate --token=<GITHUB_TOKEN> owner/repo

# Docker
docker run renovate/renovate:latest \
  --token=<GITHUB_TOKEN> \
  owner/repo
```

## Key Patterns

### Basic renovate.json

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["config:recommended"],
  "schedule": ["before 6am on monday"],
  "timezone": "America/Chicago",
  "prHourlyLimit": 5,
  "prConcurrentLimit": 10
}
```

### Grouping related dependencies

```json
{
  "extends": ["config:recommended"],
  "packageRules": [
    {
      "groupName": "React ecosystem",
      "matchPackageNames": ["react", "react-dom", "@types/react", "@types/react-dom"]
    },
    {
      "groupName": "ESLint packages",
      "matchPackagePrefixes": ["eslint", "@typescript-eslint/"]
    },
    {
      "groupName": "Testing libraries",
      "matchPackageNames": ["vitest", "@vitest/", "testing-library", "@testing-library/"]
    },
    {
      "groupName": "AWS SDK",
      "matchPackagePrefixes": ["@aws-sdk/"]
    }
  ]
}
```

### Automerge safe updates

```json
{
  "extends": ["config:recommended"],
  "packageRules": [
    {
      "matchUpdateTypes": ["minor", "patch"],
      "matchCurrentVersion": "!/^0/",
      "automerge": true,
      "automergeType": "pr",
      "platformAutomerge": true
    },
    {
      "matchUpdateTypes": ["major"],
      "automerge": false,
      "labels": ["dependencies", "breaking-change"]
    },
    {
      "matchDepTypes": ["devDependencies"],
      "automerge": true
    }
  ]
}
```

### Multi-ecosystem config

```json
{
  "extends": ["config:recommended"],
  "enabledManagers": ["npm", "pip_requirements", "dockerfile", "github-actions", "gomod"],
  "pip_requirements": {
    "fileMatch": ["requirements.*\\.txt$", "pyproject.toml"]
  },
  "docker": {
    "pinDigests": true
  },
  "github-actions": {
    "pinDigests": true
  },
  "packageRules": [
    {
      "matchManagers": ["github-actions"],
      "groupName": "GitHub Actions",
      "automerge": true
    },
    {
      "matchManagers": ["dockerfile"],
      "groupName": "Docker base images",
      "schedule": ["on the first day of the month"]
    }
  ]
}
```

### Vulnerability alerts

```json
{
  "extends": ["config:recommended"],
  "vulnerabilityAlerts": {
    "enabled": true,
    "schedule": ["at any time"],
    "automerge": true,
    "labels": ["security"]
  }
}
```

### Monorepo with shared config

```json
{
  "extends": ["local>myorg/.github:renovate-config"],
  "packageRules": [
    {
      "matchPaths": ["apps/api/**"],
      "groupName": "API dependencies"
    }
  ]
}
```

## Common Pitfalls

1. **Too many PRs**: Start with `prHourlyLimit` and `prConcurrentLimit` to avoid overwhelming the team.
2. **Major version updates**: Always require manual review — configure `automerge: false` for majors.
3. **Pinned Docker digests**: Renovate can update digest pins automatically — enable `pinDigests: true`.
4. **Config validation**: Use the Renovate playground (https://app.renovatebot.com/dashboard) to test config changes.
5. **Rate limits**: The GitHub App tier has rate limits; self-host for large organizations or many repos.

## Related Skills

- changesets-versioning — monorepo version management
- dependency-auditor — security auditing of current dependencies
- github-actions-ci-workflow — CI integration for auto-merged PRs

## GitNexus Index

```
domain: developer-tooling
maturity: stable
complexity: medium
ecosystems: npm, pip, go, docker, helm, terraform, github-actions, 90+
config-file: renovate.json, .renovaterc, .github/renovate.json
```
