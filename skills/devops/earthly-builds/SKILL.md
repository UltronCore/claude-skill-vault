---
name: earthly-builds
version: 1.0.0
description: Write reproducible, containerized builds with Earthly — Makefile meets Dockerfile syntax
tools: [Bash, Read, Write, Edit]
category: developer-tooling
tags: [earthly, builds, reproducible, containers, cicd, caching]
author: claude-skill-vault
created: 2026-05-24
---

# Earthly — Reproducible Builds

## Overview

Earthly combines the simplicity of Makefiles with the reproducibility of Docker. Builds run in containers, producing identical results locally and in CI. Earthly's Earthfile syntax is familiar, caching is automatic, and parallel execution is built in.

## When to Use

- Replacing complex Makefiles or shell scripts with containerized builds
- Getting identical results between local and CI builds
- Building monorepos where different services have different toolchains
- Parallel builds with automatic dependency detection
- Teams where not everyone has the same local tools installed

## Installation

```bash
# macOS
brew install earthly/earthly/earthly

# Linux
sudo /bin/sh -c 'wget https://github.com/earthly/earthly/releases/latest/download/earthly-linux-amd64 -O /usr/local/bin/earthly && chmod +x /usr/local/bin/earthly'

# Bootstrap the Earthly satellite (one-time)
earthly bootstrap

# Verify
earthly --version
```

## Key Patterns

### Basic Earthfile

```dockerfile
# Earthfile
VERSION 0.8

build:
    FROM node:22-alpine
    WORKDIR /app
    COPY package*.json .
    RUN npm ci
    COPY . .
    RUN npm run build
    SAVE ARTIFACT dist /dist AS LOCAL ./dist

test:
    FROM +build
    RUN npm test

docker:
    FROM node:22-alpine
    WORKDIR /app
    COPY +build/dist ./dist
    COPY package*.json .
    RUN npm ci --production
    EXPOSE 3000
    ENTRYPOINT ["node", "dist/index.js"]
    SAVE IMAGE myapp:latest
```

### Running targets

```bash
# Run a specific target
earthly +build
earthly +test
earthly +docker

# Run multiple targets
earthly +test +docker

# Build with secrets
earthly +build --secret DB_PASSWORD=mypassword

# Push built image
earthly --push +docker
```

### Caching with CACHE

```dockerfile
VERSION 0.8

build:
    FROM python:3.12-slim
    WORKDIR /app
    COPY requirements.txt .
    # Cache pip packages between runs
    RUN --mount=type=cache,target=/root/.cache/pip \
        pip install -r requirements.txt
    COPY . .
    RUN python -m pytest tests/
```

### Monorepo with multiple services

```dockerfile
# Earthfile (root)
VERSION 0.8

all:
    BUILD ./services/api+docker
    BUILD ./services/worker+docker
    BUILD ./frontend+docker

# services/api/Earthfile
VERSION 0.8

build:
    FROM golang:1.22-alpine
    WORKDIR /app
    COPY go.mod go.sum .
    RUN go mod download
    COPY . .
    RUN go build -o api .
    SAVE ARTIFACT api /api

docker:
    FROM alpine:3.19
    COPY +build/api /usr/local/bin/api
    EXPOSE 8080
    ENTRYPOINT ["/usr/local/bin/api"]
    SAVE IMAGE api-service:latest
```

### CI integration (GitHub Actions)

```yaml
name: CI
on: [push]
jobs:
  build:
    runs-on: ubuntu-latest
    env:
      EARTHLY_TOKEN: ${{ secrets.EARTHLY_TOKEN }}
    steps:
      - uses: actions/checkout@v4
      - uses: earthly/actions-setup@v1
        with:
          version: latest
      - run: earthly --ci +test
      - run: earthly --ci --push +docker
```

### Passing arguments

```dockerfile
VERSION 0.8

ARG --global TAG=latest

docker:
    FROM alpine:3.19
    ARG VERSION=$TAG
    LABEL version=$VERSION
    SAVE IMAGE myapp:$TAG
```

```bash
earthly +docker --TAG=1.2.3
```

## Common Pitfalls

1. **Docker daemon required**: Earthly needs Docker running locally. Use Earthly Satellites for CI without Docker.
2. **SAVE ARTIFACT vs SAVE IMAGE**: Use `SAVE ARTIFACT` for files and `SAVE IMAGE` for Docker images.
3. **Cache mounts not persistent across runners**: Use Earthly Cloud cache or mount a cache volume in CI.
4. **`AS LOCAL` paths**: Paths in `AS LOCAL` are relative to the Earthfile's directory, not the current shell directory.
5. **VERSION directive required**: Always include `VERSION 0.8` at the top of each Earthfile.

## Related Skills

- dagger-cicd — programmatic CI/CD with Go/Python/TS SDKs
- docker-expert — Docker fundamentals
- github-actions-ci-workflow — traditional YAML pipelines

## GitNexus Index

```
domain: developer-tooling
maturity: stable
complexity: low-medium
config-file: Earthfile
caching: automatic layer + dependency caching
language: Earthfile DSL (Dockerfile-like)
```
