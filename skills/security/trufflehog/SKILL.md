---
name: trufflehog
description: Detect accidentally committed secrets in git history with TruffleHog — a tool that scans git repositories, filesystems, S3 buckets, and CI/CD systems for exposed credentials, API keys, tokens, and other secrets. Use this skill whenever the user suspects secrets were committed to git, wants to audit their repo history for leaked credentials, or needs to set up secrets scanning in CI/CD. Trigger for "trufflehog", "git secret scan", "leaked credentials git", "secrets in git history", or "scan for api keys".

SAFETY NOTE: This skill covers ONLY scanning your own repositories for accidentally committed secrets, to help you revoke and rotate them promptly. Never use secret scanning tools against repositories you don't own.
---

# TruffleHog: Secrets Detection in Git History

TruffleHog scans git repositories and other sources to find accidentally committed secrets — API keys, passwords, tokens, private keys — so you can revoke them quickly. It uses both regex patterns and Shannon entropy analysis to find high-confidence secrets.

> **Own your repos only**: Only scan repositories and systems you own or have explicit authorization to audit.

## Installation

```bash
# macOS
brew install trufflesecurity/trufflehog/trufflehog

# Linux / macOS (installer)
curl -sSfL https://raw.githubusercontent.com/trufflesecurity/trufflehog/main/scripts/install.sh | sh -s -- -b /usr/local/bin

# Docker
docker pull trufflesecurity/trufflehog:latest

# Go install
go install github.com/trufflesecurity/trufflehog/v3@latest
```

## Scanning Git Repositories

```bash
# Scan your own git repository (entire history)
trufflehog git file://./path/to/repo

# Scan a GitHub repository you own
trufflehog github --repo https://github.com/your-org/your-repo

# Scan with authentication (for private repos)
trufflehog github --repo https://github.com/your-org/private-repo \
  --token $GITHUB_TOKEN

# Scan only recent commits (last 30 days)
trufflehog git file://./myrepo --since-commit HEAD~100

# Scan specific branch
trufflehog git file://./myrepo --branch main

# Scan and show only verified secrets (reduces false positives)
trufflehog github --repo https://github.com/your-org/your-repo --only-verified

# Exclude specific paths
trufflehog git file://./myrepo --exclude-paths .trufflehog-exclude
```

## Scanning Entire GitHub Orgs

```bash
# Scan all repos in your organization
trufflehog github --org your-org --token $GITHUB_TOKEN

# Scan including wiki pages
trufflehog github --org your-org --token $GITHUB_TOKEN --include-wikis

# Scan all public repos (for open source auditing of your own code)
trufflehog github --org your-org --token $GITHUB_TOKEN --only-verified
```

## Scanning Filesystems and Other Sources

```bash
# Scan a local directory
trufflehog filesystem ./src/

# Scan an S3 bucket (your own)
trufflehog s3 --bucket my-company-artifacts

# Scan an S3 bucket with credentials
trufflehog s3 --bucket my-bucket \
  --key $AWS_ACCESS_KEY_ID \
  --secret $AWS_SECRET_ACCESS_KEY

# Scan CI/CD environment variables (for your own pipeline)
trufflehog circleci --token $CIRCLECI_TOKEN --project your-project
trufflehog github-actions --token $GITHUB_TOKEN --repo your-org/your-repo

# Scan a Docker image
trufflehog docker --image my-app:latest
```

## CI/CD Integration

### GitHub Actions (Pre-merge Scanning)

```yaml
# .github/workflows/trufflehog.yml
name: Secret Detection
on:
  push:
    branches: [main, develop]
  pull_request:

jobs:
  trufflehog:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0  # Full history needed for complete scan

      - name: TruffleHog OSS
        uses: trufflesecurity/trufflehog@main
        with:
          path: ./
          base: ${{ github.event.repository.default_branch }}
          head: HEAD
          extra_args: --only-verified --fail  # fail CI if verified secrets found
```

### GitLab CI

```yaml
# .gitlab-ci.yml
secret-detection:
  stage: security
  image: trufflesecurity/trufflehog:latest
  script:
    - trufflehog git file://. --since-commit $CI_COMMIT_BEFORE_SHA --only-verified --fail
  allow_failure: false  # block merge if secrets found
```

### Pre-commit Hook

```bash
# .git/hooks/pre-commit (or via pre-commit framework)
#!/bin/bash
echo "Scanning for secrets..."
trufflehog git file://. --since-commit HEAD --only-verified --fail
if [ $? -ne 0 ]; then
  echo "ERROR: Secrets detected! Please remove them before committing."
  exit 1
fi
```

```yaml
# .pre-commit-config.yaml
repos:
  - repo: local
    hooks:
      - id: trufflehog
        name: TruffleHog
        language: system
        entry: trufflehog git file://. --since-commit HEAD --only-verified --fail
        pass_filenames: false
        always_run: true
```

## Output Formats

```bash
# JSON output (for automation)
trufflehog git file://./myrepo -j

# JSON with structured output
trufflehog git file://./myrepo --json | jq '{
  detector: .DetectorName,
  secret_type: .DetectorType,
  verified: .Verified,
  file: .SourceMetadata.Data.Git.file,
  commit: .SourceMetadata.Data.Git.commit,
  author: .SourceMetadata.Data.Git.email
}'

# Filter to only verified secrets (high confidence)
trufflehog git file://./myrepo -j | jq 'select(.Verified == true)'
```

## Understanding Results

```
Found verified result 🐷🔑
Detector Type: AWS
Detector Name: AWS
Verified: true
Raw result: AKIAIOSFODNN7EXAMPLE
...
Source metadata:
  File: config/database.yml
  Line: 45
  Commit: abc123def456
  Author: developer@company.com
  Date: 2024-01-15
```

- **Verified**: TruffleHog made a test API call and confirmed the secret is active — **Revoke immediately**
- **Unverified**: Pattern matched but couldn't verify — investigate and revoke if real

## Incident Response: Secret Found in History

When TruffleHog finds a secret, follow these steps:

### Step 1: Revoke Immediately
```bash
# AWS
aws iam delete-access-key --access-key-id AKIAIOSFODNN7EXAMPLE

# GitHub token — go to: Settings > Developer settings > Personal access tokens

# Stripe key — go to: Stripe Dashboard > Developers > API Keys

# Generic: contact the service provider immediately
```

### Step 2: Assess Exposure
```bash
# Find all commits that introduced or touched the secret
git log --all --full-history -- config/database.yml

# Find the first commit that introduced it
git log --diff-filter=A --all -- path/to/file

# Check if the branch/tag was ever pushed publicly
git log --remotes --all --oneline | head -20
```

### Step 3: Remove from Git History
```bash
# Option A: BFG Repo Cleaner (recommended — faster)
java -jar bfg.jar --replace-text sensitive-patterns.txt myrepo.git

# Option B: git filter-repo
pip install git-filter-repo
git filter-repo --path-glob '*.env' --invert-paths  # remove .env files from all history

# Option C: git filter-branch (slow but built-in)
git filter-branch --force --index-filter \
  "git rm --cached --ignore-unmatch config/secrets.yml" \
  --prune-empty --tag-name-filter cat -- --all

# After rewriting history, force push (coordinate with team)
git push origin --force --all
git push origin --force --tags
```

### Step 4: Rotate All Related Secrets
Even if you remove from history, assume the secret was already captured.
- Rotate the compromised credential
- Audit access logs for unauthorized use
- Rotate any other credentials that may have been co-located

## Configuration File

```yaml
# .trufflehog.yml
detectors:
  - AWS
  - GitHub
  - Stripe
  - Slack
  - Generic  # high-entropy string detection

exclude_paths:
  - vendor/
  - node_modules/
  - .git/
  - "**/*.test.js"  # test files often have fake keys

# Allowlist known false positives
allowlist:
  commits:
    - abc123def456  # known safe historical commit
  paths:
    - tests/fixtures/fake_credentials.yaml
```

## GitNexus Index

This skill is indexed by GitNexus for knowledge graph traversal.
Index path: /Users/localuser/.claude/skills/trufflehog/.gitnexus
Last indexed: 2026-05-24
