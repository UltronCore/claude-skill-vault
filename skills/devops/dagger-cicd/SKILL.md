---
name: dagger-cicd
version: 1.0.0
description: Define CI/CD pipelines as code using Dagger's Go, Python, or TypeScript SDK — portable across local and cloud
tools: [Bash, Read, Write, Edit]
category: developer-tooling
tags: [dagger, cicd, pipelines, containers, go, python, typescript]
author: claude-skill-vault
created: 2026-05-24
---

# Dagger — CI/CD as Code

## Overview

Dagger lets you define CI/CD pipelines as code using Go, Python, or TypeScript. Pipelines run identically locally and in CI via containerized DAGs, eliminating "it works in CI but not locally." The Dagger Engine caches aggressively for fast reruns.

## When to Use

- Replacing shell scripts or YAML CI configs with typed, testable code
- Running the exact same pipeline locally that runs in CI
- Caching build steps across runs to speed up CI
- Building multi-language pipelines in a familiar SDK
- Sharing pipeline logic as reusable Dagger modules

## Installation

```bash
# Install Dagger CLI
curl -L https://dl.dagger.io/dagger/install.sh | sh

# Or via Homebrew
brew install dagger/tap/dagger

# Verify
dagger version

# Initialize a new Dagger module (TypeScript)
dagger init --sdk=typescript --name=my-pipeline
```

## Key Patterns

### TypeScript pipeline

```typescript
// dagger/src/index.ts
import { dag, Container, Directory, object, func } from "@dagger.io/dagger";

@object()
export class MyPipeline {
  @func()
  async build(source: Directory): Promise<Container> {
    return dag
      .container()
      .from("node:22-alpine")
      .withDirectory("/app", source)
      .withWorkdir("/app")
      .withExec(["npm", "ci"])
      .withExec(["npm", "run", "build"]);
  }

  @func()
  async test(source: Directory): Promise<string> {
    return dag
      .container()
      .from("node:22-alpine")
      .withDirectory("/app", source)
      .withWorkdir("/app")
      .withExec(["npm", "ci"])
      .withExec(["npm", "test"])
      .stdout();
  }

  @func()
  async lint(source: Directory): Promise<string> {
    return dag
      .container()
      .from("node:22-alpine")
      .withDirectory("/app", source)
      .withWorkdir("/app")
      .withExec(["npm", "ci"])
      .withExec(["npm", "run", "lint"])
      .stdout();
  }
}
```

### Running locally

```bash
# Run a function
dagger call build --source=.

# Run test and capture output
dagger call test --source=. 

# Chain functions
dagger call build --source=. publish --address=registry.example.com/myapp:latest
```

### Python pipeline

```python
# dagger/src/main.py
import dagger
from dagger import dag, function, object_type

@object_type
class Pipeline:
    @function
    async def test(self, source: dagger.Directory) -> str:
        return await (
            dag.container()
            .from_("python:3.12-slim")
            .with_directory("/app", source)
            .with_workdir("/app")
            .with_exec(["pip", "install", "-r", "requirements.txt"])
            .with_exec(["pytest", "tests/", "-v"])
            .stdout()
        )

    @function
    async def build_image(
        self, source: dagger.Directory, tag: str
    ) -> dagger.Container:
        return (
            dag.container()
            .build(source)
            .with_label("version", tag)
        )
```

### GitHub Actions integration

```yaml
# .github/workflows/ci.yml
name: CI
on: [push, pull_request]
jobs:
  dagger:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dagger/dagger-for-github@v6
        with:
          version: "latest"
          verb: call
          args: test --source=.
```

### Caching dependencies

```typescript
@func()
async buildWithCache(source: Directory): Promise<Container> {
  const nodeCache = dag.cacheVolume("node-modules");
  return dag
    .container()
    .from("node:22-alpine")
    .withDirectory("/app", source, { exclude: ["node_modules"] })
    .withWorkdir("/app")
    .withMountedCache("/app/node_modules", nodeCache)
    .withExec(["npm", "ci"])
    .withExec(["npm", "run", "build"]);
}
```

## Common Pitfalls

1. **Secrets in containers**: Use `dag.setSecret()` — never hardcode secrets in pipeline functions.
2. **Large source directories**: Exclude build artifacts with `exclude` option to speed up directory transfers.
3. **Cache invalidation**: Dagger caches based on inputs; changing source files correctly invalidates the cache.
4. **Module vs CLI**: `dagger call` runs module functions; `dagger run` executes arbitrary commands inside the engine.
5. **Engine version mismatch**: Pin the CLI version in CI to match your module's engine requirement.

## Related Skills

- earthly-builds — simpler Makefile-like syntax for reproducible builds
- github-actions-ci-workflow — traditional YAML CI workflows
- docker-expert — underlying container expertise

## GitNexus Index

```
domain: developer-tooling
maturity: stable
complexity: medium
sdks: go, python, typescript
config-file: dagger.json, dagger/src/
caching: aggressive DAG-level caching
```
