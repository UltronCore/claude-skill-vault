---
name: github-actions-advanced
description: >
  Advanced GitHub Actions: matrix builds, reusable workflows, secrets, caching, and deployment pipelines. Triggers on: GitHub Actions, .github/workflows, workflow_call, matrix, actions/cache, needs:, environment: production, OIDC.
---

# GitHub Actions Advanced

## When to Use

Trigger when building CI/CD pipelines: matrix testing across Node versions, reusable workflows shared across repos, OIDC-based cloud auth (no long-lived secrets), artifact passing between jobs, environment protection rules, or Vercel deployment integration.

---

## Core Rules

- Use `workflow_call` for reusable workflows — avoids copy-paste across repos
- Use OIDC for cloud auth (AWS, GCP, Azure) — never store long-lived access keys as secrets
- Cache dependencies with `actions/cache` using `restore-keys` fallback chain
- Pass data between jobs via `outputs` (small values) or `actions/upload-artifact` (files)
- Use `environment: production` on deploy jobs to enforce protection rules
- Never hardcode secrets — always `${{ secrets.SECRET_NAME }}`
- Prefer `github.sha` over `github.ref` for cache keys to avoid stale hits

---

## Workflow File Structure

```yaml
# .github/workflows/ci.yml
name: CI

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]
  workflow_dispatch:        # Manual trigger with optional inputs
    inputs:
      environment:
        description: "Target environment"
        required: true
        type: choice
        options: [staging, production]
        default: staging

permissions:
  contents: read
  id-token: write          # Required for OIDC

env:
  NODE_VERSION: "20"
  REGISTRY: ghcr.io

jobs:
  # ... jobs here
```

---

## Matrix Strategy

### Multi-version testing

```yaml
jobs:
  test:
    name: Test (Node ${{ matrix.node }} / ${{ matrix.os }})
    runs-on: ${{ matrix.os }}
    strategy:
      fail-fast: false      # Continue other matrix jobs if one fails
      matrix:
        node: ["18", "20", "22"]
        os: [ubuntu-latest, macos-latest]
        exclude:
          - os: macos-latest
            node: "18"      # Skip this combination
        include:
          - os: ubuntu-latest
            node: "20"
            experimental: false
            coverage: true  # Extra flag for specific combo

    steps:
      - uses: actions/checkout@v4

      - name: Setup Node ${{ matrix.node }}
        uses: actions/setup-node@v4
        with:
          node-version: ${{ matrix.node }}
          cache: "npm"

      - run: npm ci
      - run: npm test

      - name: Upload coverage
        if: matrix.coverage
        uses: codecov/codecov-action@v4
```

### Dynamic matrix from script

```yaml
jobs:
  generate-matrix:
    runs-on: ubuntu-latest
    outputs:
      matrix: ${{ steps.set-matrix.outputs.matrix }}
    steps:
      - uses: actions/checkout@v4
      - id: set-matrix
        run: |
          # Build matrix from directory listing
          SERVICES=$(ls services/ | jq -R . | jq -s -c .)
          echo "matrix={\"service\":$SERVICES}" >> $GITHUB_OUTPUT

  deploy:
    needs: generate-matrix
    strategy:
      matrix: ${{ fromJson(needs.generate-matrix.outputs.matrix) }}
    runs-on: ubuntu-latest
    steps:
      - run: echo "Deploying ${{ matrix.service }}"
```

---

## Reusable Workflows (workflow_call)

### Define reusable workflow

```yaml
# .github/workflows/deploy-vercel.yml
name: Deploy to Vercel

on:
  workflow_call:
    inputs:
      environment:
        required: true
        type: string
        description: "Target environment (preview | production)"
      node-version:
        required: false
        type: string
        default: "20"
    secrets:
      VERCEL_TOKEN:
        required: true
      VERCEL_ORG_ID:
        required: true
      VERCEL_PROJECT_ID:
        required: true
    outputs:
      deployment-url:
        description: "The deployed URL"
        value: ${{ jobs.deploy.outputs.url }}

jobs:
  deploy:
    name: Deploy (${{ inputs.environment }})
    runs-on: ubuntu-latest
    environment: ${{ inputs.environment }}
    outputs:
      url: ${{ steps.deploy.outputs.url }}

    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: ${{ inputs.node-version }}
          cache: "npm"

      - run: npm ci

      - name: Build
        run: npm run build
        env:
          NODE_ENV: production

      - name: Deploy to Vercel
        id: deploy
        run: |
          if [[ "${{ inputs.environment }}" == "production" ]]; then
            URL=$(vercel --prod --token=${{ secrets.VERCEL_TOKEN }} \
              --yes \
              --scope=${{ secrets.VERCEL_ORG_ID }})
          else
            URL=$(vercel --token=${{ secrets.VERCEL_TOKEN }} \
              --yes \
              --scope=${{ secrets.VERCEL_ORG_ID }})
          fi
          echo "url=$URL" >> $GITHUB_OUTPUT
        env:
          VERCEL_ORG_ID: ${{ secrets.VERCEL_ORG_ID }}
          VERCEL_PROJECT_ID: ${{ secrets.VERCEL_PROJECT_ID }}
```

### Call reusable workflow

```yaml
# .github/workflows/cd.yml
name: CD

on:
  push:
    branches: [main]

jobs:
  test:
    uses: ./.github/workflows/test.yml   # local
    # uses: org/shared-workflows/.github/workflows/test.yml@main  # remote

  deploy-preview:
    needs: test
    uses: ./.github/workflows/deploy-vercel.yml
    with:
      environment: preview
    secrets:
      VERCEL_TOKEN: ${{ secrets.VERCEL_TOKEN }}
      VERCEL_ORG_ID: ${{ secrets.VERCEL_ORG_ID }}
      VERCEL_PROJECT_ID: ${{ secrets.VERCEL_PROJECT_ID }}

  deploy-production:
    needs: [test, deploy-preview]
    uses: ./.github/workflows/deploy-vercel.yml
    with:
      environment: production
    secrets: inherit   # Pass all secrets from caller
```

---

## Environment Protection Rules

```yaml
# In GitHub repo settings → Environments → production:
# - Required reviewers: [username]
# - Wait timer: 5 minutes
# - Deployment branches: main only

jobs:
  deploy:
    environment:
      name: production
      url: https://yourdomain.com  # Shows in GitHub UI
    runs-on: ubuntu-latest
    steps:
      - run: echo "Deploying to production"
```

### Environment-specific secrets

```yaml
# In GitHub: Settings → Environments → production → Environment secrets
# These are only available to jobs with `environment: production`

jobs:
  deploy:
    environment: production
    steps:
      - run: deploy.sh
        env:
          API_KEY: ${{ secrets.PROD_API_KEY }}  # Only accessible here
```

---

## OIDC — No Static Secrets for Cloud Auth

### Configure AWS (no long-lived keys)

```yaml
# 1. Create OIDC provider in AWS IAM for GitHub
# 2. Create IAM role with trust policy for your repo
# 3. Use in workflow:

jobs:
  deploy:
    runs-on: ubuntu-latest
    permissions:
      id-token: write   # Required for OIDC
      contents: read
    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS Credentials (OIDC)
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789012:role/GitHubActionsDeployRole
          aws-region: us-east-1
          # No access key or secret needed!

      - name: Deploy to S3
        run: aws s3 sync ./dist s3://my-bucket --delete
```

### AWS IAM Trust Policy for GitHub OIDC

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:YourOrg/your-repo:*"
        }
      }
    }
  ]
}
```

### Configure GCP with OIDC

```yaml
- name: Authenticate to Google Cloud
  uses: google-github-actions/auth@v2
  with:
    workload_identity_provider: "projects/123/locations/global/workloadIdentityPools/github/providers/github"
    service_account: "deploy@your-project.iam.gserviceaccount.com"
```

---

## Dependency Caching

### npm with restore-keys fallback

```yaml
- name: Cache node_modules
  uses: actions/cache@v4
  with:
    path: ~/.npm
    key: ${{ runner.os }}-node-${{ hashFiles('**/package-lock.json') }}
    restore-keys: |
      ${{ runner.os }}-node-

# Or use built-in setup-node caching (preferred):
- uses: actions/setup-node@v4
  with:
    node-version: "20"
    cache: "npm"          # Handles npm cache automatically
```

### Multiple cache paths

```yaml
- uses: actions/cache@v4
  with:
    path: |
      ~/.npm
      ${{ github.workspace }}/.next/cache
    key: ${{ runner.os }}-nextjs-${{ hashFiles('**/package-lock.json') }}-${{ hashFiles('**/*.ts', '**/*.tsx') }}
    restore-keys: |
      ${{ runner.os }}-nextjs-${{ hashFiles('**/package-lock.json') }}-
      ${{ runner.os }}-nextjs-
```

### Cache invalidation strategy

```yaml
# Cache key components:
# 1. OS — cache is OS-specific
# 2. Lock file hash — invalidates when deps change
# 3. Source hash (optional) — for build caches
key: ${{ runner.os }}-build-${{ hashFiles('**/package-lock.json') }}-${{ github.sha }}
restore-keys: |
  ${{ runner.os }}-build-${{ hashFiles('**/package-lock.json') }}-
  ${{ runner.os }}-build-
```

---

## Artifact Passing Between Jobs

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm ci && npm run build

      - name: Upload build artifact
        uses: actions/upload-artifact@v4
        with:
          name: build-output
          path: .next/
          retention-days: 1   # Short retention for CI artifacts

  test-e2e:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Download build
        uses: actions/download-artifact@v4
        with:
          name: build-output
          path: .next/

      - run: npm run test:e2e

  deploy:
    needs: [build, test-e2e]
    runs-on: ubuntu-latest
    steps:
      - uses: actions/download-artifact@v4
        with:
          name: build-output
          path: .next/

      - run: deploy.sh
```

---

## Conditional Steps and Jobs

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      # Skip on draft PRs
      - name: Full build
        if: ${{ !github.event.pull_request.draft }}
        run: npm run build

      # Only on main branch
      - name: Deploy
        if: github.ref == 'refs/heads/main' && github.event_name == 'push'
        run: npm run deploy

      # Only if previous step succeeded
      - name: Notify success
        if: success()
        run: echo "All good!"

      # Only if any previous step failed
      - name: Notify failure
        if: failure()
        run: notify.sh failed

      # Always run (cleanup etc.)
      - name: Cleanup
        if: always()
        run: rm -rf /tmp/build

      # Check outputs from previous step
      - name: Build changed files
        id: changed
        uses: tj-actions/changed-files@v44
        with:
          files: "src/**"
      - name: Run tests
        if: steps.changed.outputs.any_changed == 'true'
        run: npm test
```

### Job-level conditions

```yaml
jobs:
  deploy-staging:
    if: github.ref == 'refs/heads/develop'
    ...

  deploy-prod:
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'
    needs: [test, build]
    ...

  # Run only for specific file changes
  deploy-docs:
    if: contains(github.event.commits[0].modified, 'docs/')
    ...
```

---

## workflow_dispatch with Inputs

```yaml
on:
  workflow_dispatch:
    inputs:
      version:
        description: "Release version (e.g., 1.2.3)"
        required: true
        type: string
      skip-tests:
        description: "Skip test suite"
        required: false
        type: boolean
        default: false
      target:
        description: "Deploy target"
        required: true
        type: choice
        options:
          - staging
          - production

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - run: |
          echo "Releasing v${{ inputs.version }} to ${{ inputs.target }}"
          
      - name: Run tests
        if: ${{ !inputs.skip-tests }}
        run: npm test

      - name: Create release
        run: |
          git tag v${{ inputs.version }}
          git push origin v${{ inputs.version }}
```

---

## Complete CI/CD Pipeline (Next.js + Vercel)

```yaml
# .github/workflows/pipeline.yml
name: Pipeline

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true    # Cancel outdated runs on new pushes

jobs:
  lint-typecheck:
    name: Lint & Typecheck
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: "20", cache: "npm" }
      - run: npm ci
      - run: npm run lint
      - run: npm run typecheck

  test:
    name: Unit Tests
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: "20", cache: "npm" }
      - run: npm ci
      - run: npm test -- --coverage
      - uses: codecov/codecov-action@v4

  deploy-preview:
    name: Deploy Preview
    if: github.event_name == 'pull_request'
    needs: [lint-typecheck, test]
    runs-on: ubuntu-latest
    environment:
      name: preview
      url: ${{ steps.deploy.outputs.url }}
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: "20", cache: "npm" }
      - run: npm ci && npm run build
      - name: Deploy Preview
        id: deploy
        run: |
          URL=$(npx vercel --token=${{ secrets.VERCEL_TOKEN }} --yes)
          echo "url=$URL" >> $GITHUB_OUTPUT
        env:
          VERCEL_ORG_ID: ${{ secrets.VERCEL_ORG_ID }}
          VERCEL_PROJECT_ID: ${{ secrets.VERCEL_PROJECT_ID }}
      - name: Comment PR
        uses: actions/github-script@v7
        with:
          script: |
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: `Preview deployed: ${{ steps.deploy.outputs.url }}`
            });

  deploy-production:
    name: Deploy Production
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'
    needs: [lint-typecheck, test]
    runs-on: ubuntu-latest
    environment:
      name: production
      url: https://yourdomain.com
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: "20", cache: "npm" }
      - run: npm ci && npm run build
      - name: Deploy Production
        run: npx vercel --prod --token=${{ secrets.VERCEL_TOKEN }} --yes
        env:
          VERCEL_ORG_ID: ${{ secrets.VERCEL_ORG_ID }}
          VERCEL_PROJECT_ID: ${{ secrets.VERCEL_PROJECT_ID }}
```

---

## Useful Action References

| Action | Purpose |
|--------|---------|
| `actions/checkout@v4` | Check out repo |
| `actions/setup-node@v4` | Setup Node.js + npm cache |
| `actions/cache@v4` | Manual caching |
| `actions/upload-artifact@v4` | Save files between jobs |
| `actions/download-artifact@v4` | Load saved files |
| `actions/github-script@v7` | Run GitHub API JS |
| `aws-actions/configure-aws-credentials@v4` | OIDC AWS auth |
| `google-github-actions/auth@v2` | OIDC GCP auth |
| `tj-actions/changed-files@v44` | Detect changed files |
| `codecov/codecov-action@v4` | Upload coverage |

## GitNexus Index
This skill is indexed by GitNexus for knowledge graph traversal.
Index path: /Users/localuser/claude-skill-vault/skills/cloud-devops/github-actions-advanced/.gitnexus
Last indexed: 2026-05-23
