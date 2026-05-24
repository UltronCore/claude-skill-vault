---
name: atlantis
description: Atlantis — automated Terraform/OpenTofu pull request workflow with plan and apply via PR comments. Use this skill whenever the user needs to automate Terraform plan/apply on PRs, enforce code review before infrastructure changes, set up GitOps for infrastructure, configure Atlantis server with repo-level workflow overrides, or prevent unapproved Terraform applies. Trigger for "atlantis terraform", "atlantis plan", "atlantis apply", "terraform pr automation", "infrastructure gitops atlantis", or "terraform code review workflow".
---

# Atlantis — Terraform Pull Request Automation

## Overview

Atlantis is a self-hosted application that listens for GitHub/GitLab/Bitbucket webhook events and runs `terraform plan` and `terraform apply` automatically when pull requests touch Terraform or OpenTofu code. Engineers comment `atlantis plan` on a PR to see the plan output, and `atlantis apply` to apply after approval. Atlantis enforces that every infrastructure change is reviewed, planned, and applied via version control — eliminating one-off manual applies from engineers' laptops. It runs as a single stateless binary or Kubernetes Deployment.

## When to Use

- Enforcing peer review for all infrastructure changes (Terraform/OpenTofu)
- Getting plan output visible in PRs without granting engineers direct Terraform access
- Preventing unreviewed `terraform apply` from engineer laptops
- Setting up GitOps for infrastructure (apply on merge to main)
- Workspace-per-PR workflows with parallel plan/apply across multiple environments
- CI/CD integration for infrastructure with mandatory approvals

## Installation

```bash
# Install Atlantis CLI / server binary
brew install atlantis  # macOS
# Or download from https://github.com/runatlantis/atlantis/releases

# Start Atlantis server (minimal, for testing)
atlantis server \
  --atlantis-url="https://atlantis.mycompany.com" \
  --gh-user="atlantis-bot" \
  --gh-token="$GITHUB_TOKEN" \
  --gh-webhook-secret="$WEBHOOK_SECRET" \
  --repo-allowlist="github.com/myorg/*"
```

## Key Patterns

### Kubernetes Deployment

```yaml
# atlantis-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: atlantis
  namespace: atlantis
spec:
  replicas: 1  # Atlantis uses file-system lock; 1 replica only
  selector:
    matchLabels:
      app: atlantis
  template:
    metadata:
      labels:
        app: atlantis
    spec:
      serviceAccountName: atlantis
      containers:
        - name: atlantis
          image: ghcr.io/runatlantis/atlantis:v0.29.0
          args:
            - server
          env:
            - name: ATLANTIS_ATLANTIS_URL
              value: "https://atlantis.mycompany.com"
            - name: ATLANTIS_REPO_ALLOWLIST
              value: "github.com/myorg/*"
            - name: ATLANTIS_GH_USER
              valueFrom:
                secretKeyRef:
                  name: atlantis-secrets
                  key: gh-user
            - name: ATLANTIS_GH_TOKEN
              valueFrom:
                secretKeyRef:
                  name: atlantis-secrets
                  key: gh-token
            - name: ATLANTIS_GH_WEBHOOK_SECRET
              valueFrom:
                secretKeyRef:
                  name: atlantis-secrets
                  key: webhook-secret
            # AWS credentials for running Terraform
            - name: AWS_ACCESS_KEY_ID
              valueFrom:
                secretKeyRef:
                  name: atlantis-secrets
                  key: aws-access-key-id
            - name: AWS_SECRET_ACCESS_KEY
              valueFrom:
                secretKeyRef:
                  name: atlantis-secrets
                  key: aws-secret-access-key
          ports:
            - containerPort: 4141
          volumeMounts:
            - name: atlantis-data
              mountPath: /atlantis
            - name: repo-config
              mountPath: /etc/atlantis
      volumes:
        - name: atlantis-data
          persistentVolumeClaim:
            claimName: atlantis-data
        - name: repo-config
          configMap:
            name: atlantis-repo-config
---
apiVersion: v1
kind: Service
metadata:
  name: atlantis
  namespace: atlantis
spec:
  ports:
    - port: 80
      targetPort: 4141
  selector:
    app: atlantis
```

### Server-Side Config — repos.yaml

```yaml
# /etc/atlantis/repos.yaml — global Atlantis configuration
repos:
  - id: "github.com/myorg/.*"
    # Require PR approval before apply
    apply_requirements:
      - approved
      - mergeable  # PR must have no unresolved review requests
    
    # Allow users to override workflow in atlantis.yaml in the repo
    allowed_overrides:
      - apply_requirements
      - workflow
      - delete_source_branch_on_merge
    
    allow_custom_workflows: true

workflows:
  # Default workflow — override per-project in atlantis.yaml
  default:
    plan:
      steps:
        - init
        - plan
    apply:
      steps:
        - apply

  # Production workflow with additional safeguards
  production:
    plan:
      steps:
        - init
        - run: echo "Planning production infrastructure..."
        - plan:
            extra_args: ["-detailed-exitcode"]
    apply:
      steps:
        - run: echo "Applying production infrastructure - be careful!"
        - apply
```

### Repo-Level Config — atlantis.yaml

```yaml
# atlantis.yaml — placed in the root of the Terraform repo
version: 3
automerge: false  # don't auto-merge after successful apply
delete_source_branch_on_merge: false

projects:
  # Separate project per environment
  - name: "networking-dev"
    dir: infrastructure/networking
    workspace: dev
    terraform_version: v1.9.0
    workflow: default
    apply_requirements:
      - approved

  - name: "networking-prod"
    dir: infrastructure/networking
    workspace: prod
    workflow: production
    apply_requirements:
      - approved
      - mergeable
    # Only apply when PR targets main branch
    branch: main

  - name: "app-cluster-dev"
    dir: infrastructure/eks
    workspace: dev
    autoplan:
      when_modified:
        - "*.tf"
        - "../modules/**/*.tf"  # re-plan if shared modules change
      enabled: true

  - name: "app-cluster-prod"
    dir: infrastructure/eks
    workspace: prod
    autoplan:
      enabled: false  # require explicit `atlantis plan` for production
```

### GitHub Webhook Setup

```bash
# GitHub webhook settings (add to repository or organization):
# Payload URL: https://atlantis.mycompany.com/events
# Content type: application/json
# Secret: <your ATLANTIS_GH_WEBHOOK_SECRET>
# Events to send:
#   - Pull requests
#   - Issue comments
#   - Push (for autoplan on push)
```

### PR Workflow — Commands

```
# In a GitHub PR comment:

atlantis help          # show available commands
atlantis plan          # run terraform plan on all modified projects
atlantis plan -p networking-prod   # plan a specific project
atlantis apply         # apply all projects that have been planned and approved
atlantis apply -p networking-prod  # apply a specific project
atlantis unlock        # unlock the workspace (if a plan lock is stuck)

# Approval flow:
# 1. Engineer opens PR with Terraform changes
# 2. Atlantis auto-comments the plan output (if autoplan enabled)
# 3. Reviewer approves PR on GitHub
# 4. Engineer comments "atlantis apply"
# 5. Atlantis applies and comments with the output
```

### IRSA — AWS Credentials Without Static Keys (EKS)

```yaml
# Use IRSA instead of static AWS keys
# 1. Annotate the Atlantis service account with the IAM role ARN:
apiVersion: v1
kind: ServiceAccount
metadata:
  name: atlantis
  namespace: atlantis
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789:role/AtlantisRole

# 2. Remove AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY env vars from Deployment
# 3. The pod will automatically get credentials via OIDC token projection
```

### Custom Workflow — Terraform with Vault Secrets

```yaml
workflows:
  vault-backed:
    plan:
      steps:
        - run: vault login -method=aws role=atlantis
        - run: eval $(vault kv get -format=json secret/tf/aws | jq -r '.data.data | to_entries[] | "export \(.key)=\(.value)"')
        - init
        - plan
    apply:
      steps:
        - run: vault login -method=aws role=atlantis
        - run: eval $(vault kv get -format=json secret/tf/aws | jq -r '.data.data | to_entries[] | "export \(.key)=\(.value)"')
        - apply
```

## Common Commands

```bash
atlantis server --help              # All server flags and env vars
atlantis testdrive                  # Guided setup with ngrok for testing
atlantis version                    # Print version

# In a PR comment:
# atlantis plan                     # Plan all changed projects
# atlantis apply                    # Apply all approved projects
# atlantis unlock                   # Release workspace lock
# atlantis approve_policies         # Approve OPA policy checks (if enabled)
```

## Pitfalls

- **Atlantis holds workspace locks**: while a plan or apply is running, the workspace is locked — if a plan fails or an engineer abandons a PR, others cannot plan/apply the same workspace; use `atlantis unlock` to release
- **Only one replica**: Atlantis uses a local filesystem lock mechanism and cannot scale horizontally — run exactly one replica; for HA, use the webhook queue or a managed Atlantis (e.g., Spacelift)
- **`autoplan` triggers on any `.tf` change**: if modules are shared across many projects, a change to `modules/vpc/main.tf` may trigger plans for all projects that include `"../modules/**/*.tf"` — size your server accordingly
- **GitHub token permissions**: the bot token needs `repo` scope (or at minimum: `repo:status`, `public_repo` or `repo`, `read:org` for org-level webhooks) — scoping too tightly causes silent failures where Atlantis can't comment on PRs
- **Plan files are ephemeral**: Atlantis saves plan files to disk between `plan` and `apply`; if the pod restarts between the two commands, the plan file is lost and the engineer must re-plan

## Related Skills

- `opentofu` — Atlantis works equally well with OpenTofu via `terraform_version` or custom workflow
- `argocd` — complementary GitOps for application deployments (Atlantis for infra, ArgoCD for apps)
- `hashicorp-vault` — inject Vault secrets into Atlantis workflows
- `flux-cd` — alternative GitOps approach for Kubernetes infra
- `github-actions-ci-workflow` — complement Atlantis with CI for terraform validate and lint

## GitNexus Index

Index path: /Users/localuser/.claude/skills/atlantis/.gitnexus
Created: 2026-05-24
