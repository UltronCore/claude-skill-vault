---
name: platform-engineering
description: Build internal developer platforms (IDPs) with golden paths, self-service infrastructure, Backstage portals, and platform-as-a-product principles. Covers Backstage catalog, scaffolding templates, Crossplane, Argo CD GitOps, and measuring platform adoption with DORA metrics.
version: 1.0.0
tags: [platform-engineering, backstage, idp, crossplane, argocd, gitops, developer-experience, devops, kubernetes]
---

# Platform Engineering

## Overview

Platform engineering creates internal developer platforms (IDPs) that reduce cognitive load by providing golden paths — opinionated, self-service routes for common development tasks. Instead of every team re-solving infrastructure, CI/CD, and observability, a platform team builds reusable abstractions so product engineers deploy confidently without needing deep ops knowledge. The platform is treated as a product with internal customers, SLOs, and adoption metrics.

## When to Use

- Engineering org has 10+ teams repeating the same infrastructure setup across services
- Developers wait days for infrastructure provisioning or environment setup
- Onboarding new engineers takes weeks due to undocumented, inconsistent tooling
- Security and compliance requirements need enforcement without blocking teams
- You want to measure and improve developer experience with DORA metrics (deploy frequency, lead time, MTTR, change failure rate)
- Teams are building their own CI/CD pipelines with no consistency or shared maintenance

## Step-by-Step Workflow

### 1. Backstage Developer Portal Setup

```bash
# Create Backstage app
npx @backstage/create-app@latest
cd my-backstage-app

# Install dependencies
yarn install

# Start development server
yarn dev  # Opens at http://localhost:3000
```

```yaml
# app-config.yaml — core Backstage configuration
app:
  title: Acme Developer Portal
  baseUrl: http://localhost:3000

backend:
  baseUrl: http://localhost:7007
  cors:
    origin: http://localhost:3000

catalog:
  locations:
    # Register component catalogs from GitHub
    - type: url
      target: https://github.com/acme-corp/catalog/blob/main/all-components.yaml
    # Import all repos in a GitHub org automatically
    - type: github-org
      target: https://github.com/acme-corp

# GitHub auth
auth:
  providers:
    github:
      development:
        clientId: ${GITHUB_CLIENT_ID}
        clientSecret: ${GITHUB_CLIENT_SECRET}
```

```yaml
# catalog-info.yaml — register a service in the catalog (lives in each repo)
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: order-service
  description: Handles order processing and fulfillment
  annotations:
    github.com/project-slug: acme-corp/order-service
    backstage.io/techdocs-ref: dir:.
    pagerduty.com/service-id: P12345
    argocd/app-name: order-service-prod
  tags:
    - python
    - fastapi
    - backend
  links:
    - url: https://grafana.acme.com/d/order-service
      title: Grafana Dashboard
      icon: dashboard
spec:
  type: service
  lifecycle: production
  owner: group:platform/order-team
  system: order-management
  providesApis:
    - order-api
  dependsOn:
    - component:payment-service
    - resource:orders-db
```

### 2. Scaffolding Templates (Golden Paths)

```yaml
# templates/python-fastapi-service.yaml — self-service new service creation
apiVersion: scaffolder.backstage.io/v1beta3
kind: Template
metadata:
  name: python-fastapi-service
  title: Python FastAPI Microservice
  description: Creates a production-ready FastAPI service with CI/CD, observability, and Kubernetes manifests
  tags:
    - python
    - fastapi
    - recommended
spec:
  owner: platform-team
  type: service

  parameters:
    - title: Service Details
      required: [name, description, owner]
      properties:
        name:
          title: Service Name
          type: string
          pattern: ^[a-z][a-z0-9-]*$
          description: Lowercase, hyphen-separated (e.g. order-processor)
        description:
          title: Description
          type: string
        owner:
          title: Team Owner
          type: string
          ui:field: OwnerPicker
          ui:options:
            allowedKinds: [Group]

    - title: Infrastructure
      properties:
        replicas:
          title: Initial Replicas
          type: integer
          default: 2
          enum: [1, 2, 3, 5]
        memoryLimit:
          title: Memory Limit
          type: string
          default: 256Mi
          enum: [128Mi, 256Mi, 512Mi, 1Gi]

  steps:
    - id: fetch-template
      name: Fetch Template
      action: fetch:template
      input:
        url: ./skeleton
        values:
          name: ${{ parameters.name }}
          description: ${{ parameters.description }}
          owner: ${{ parameters.owner }}
          replicas: ${{ parameters.replicas }}
          memoryLimit: ${{ parameters.memoryLimit }}

    - id: publish
      name: Create GitHub Repo
      action: publish:github
      input:
        allowedHosts: [github.com]
        description: ${{ parameters.description }}
        repoUrl: github.com?repo=${{ parameters.name }}&owner=acme-corp
        defaultBranch: main
        repoVisibility: private

    - id: register
      name: Register in Catalog
      action: catalog:register
      input:
        repoContentsUrl: ${{ steps.publish.output.repoContentsUrl }}
        catalogInfoPath: /catalog-info.yaml

  output:
    links:
      - title: Repository
        url: ${{ steps.publish.output.remoteUrl }}
      - title: Open in Catalog
        url: ${{ steps.register.output.catalogInfoUrl }}
```

### 3. Crossplane — Infrastructure as Code for Self-Service

```yaml
# crossplane/postgres-claim.yaml — developer claims a database
apiVersion: database.acme.com/v1alpha1
kind: PostgresDatabase
metadata:
  name: order-service-db
  namespace: order-team
spec:
  parameters:
    storageGB: 20
    version: "15"
    tier: standard  # standard | premium
  writeConnectionSecretToRef:
    name: order-db-connection
---
# platform/compositions/postgres.yaml — platform team defines HOW it's provisioned
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: postgres-rds
spec:
  compositeTypeRef:
    apiVersion: database.acme.com/v1alpha1
    kind: PostgresDatabase
  resources:
    - name: rds-instance
      base:
        apiVersion: rds.aws.upbound.io/v1beta1
        kind: Instance
        spec:
          forProvider:
            region: us-east-1
            instanceClass: db.t3.micro
            engine: postgres
            skipFinalSnapshot: true
      patches:
        - fromFieldPath: spec.parameters.storageGB
          toFieldPath: spec.forProvider.allocatedStorage
        - fromFieldPath: spec.parameters.version
          toFieldPath: spec.forProvider.engineVersion
```

```bash
# Install Crossplane in cluster
helm repo add crossplane-stable https://charts.crossplane.io/stable
helm install crossplane crossplane-stable/crossplane \
  --namespace crossplane-system --create-namespace

# Install AWS provider
kubectl apply -f - <<EOF
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-aws-rds
spec:
  package: xpkg.upbound.io/upbound/provider-aws-rds:v1.1.0
EOF
```

### 4. Argo CD GitOps for Deployments

```yaml
# argocd/app-of-apps.yaml — manage all environments via GitOps
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: platform-apps
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/acme-corp/platform-gitops
    targetRevision: HEAD
    path: apps
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
---
# apps/order-service.yaml — individual service managed by Argo
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: order-service
  namespace: argocd
spec:
  project: production
  source:
    repoURL: https://github.com/acme-corp/order-service
    targetRevision: HEAD
    path: k8s/overlays/production
  destination:
    server: https://prod-cluster.acme.com
    namespace: order-team
  syncPolicy:
    automated:
      prune: false    # Don't auto-delete in prod
      selfHeal: true  # Auto-fix drift
    syncOptions:
      - CreateNamespace=true
      - PrunePropagationPolicy=foreground
```

```bash
# Install Argo CD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Get admin password
argocd admin initial-password -n argocd

# Login and add cluster
argocd login argocd.acme.com
argocd cluster add prod-context --name production

# App status
argocd app list
argocd app sync order-service
argocd app diff order-service  # Preview changes before sync
```

### 5. Platform Metrics with DORA

```python
# platform/metrics/dora_calculator.py
import httpx
from datetime import datetime, timedelta
from dataclasses import dataclass

@dataclass
class DORAMetrics:
    deployment_frequency: float   # deployments per day
    lead_time_hours: float        # commit to production
    change_failure_rate: float    # % of deployments causing incidents
    mttr_hours: float             # mean time to recovery

class DORACalculator:
    def __init__(self, github_token: str, pagerduty_token: str):
        self.gh = httpx.Client(
            base_url="https://api.github.com",
            headers={"Authorization": f"Bearer {github_token}"}
        )
        self.pd = httpx.Client(
            base_url="https://api.pagerduty.com",
            headers={"Authorization": f"Token token={pagerduty_token}"}
        )

    def deployment_frequency(self, repo: str, days: int = 30) -> float:
        """Deployments per day from GitHub releases/tags."""
        since = (datetime.now() - timedelta(days=days)).isoformat() + "Z"
        resp = self.gh.get(f"/repos/acme-corp/{repo}/releases",
                           params={"per_page": 100})
        releases = [r for r in resp.json()
                    if r["published_at"] > since]
        return len(releases) / days

    def lead_time(self, repo: str, days: int = 30) -> float:
        """Average hours from first commit to deploy."""
        resp = self.gh.get(f"/repos/acme-corp/{repo}/deployments",
                           params={"per_page": 100})
        lead_times = []
        for deploy in resp.json():
            env = deploy.get("environment", "")
            if "production" not in env:
                continue
            # Find PR merge commit timestamp
            sha = deploy["sha"]
            commit = self.gh.get(f"/repos/acme-corp/{repo}/commits/{sha}").json()
            commit_time = datetime.fromisoformat(
                commit["commit"]["author"]["date"].rstrip("Z"))
            deploy_time = datetime.fromisoformat(
                deploy["created_at"].rstrip("Z"))
            lead_times.append((deploy_time - commit_time).total_seconds() / 3600)
        return sum(lead_times) / len(lead_times) if lead_times else 0

    def change_failure_rate(self, service: str, days: int = 30) -> float:
        """% of deploys that triggered an incident."""
        since = (datetime.now() - timedelta(days=days)).isoformat()
        incidents = self.pd.get("/incidents", params={
            "service_ids[]": service,
            "since": since,
            "limit": 100
        }).json()["incidents"]
        deploy_count = int(self.deployment_frequency(service, days) * days)
        return len(incidents) / deploy_count if deploy_count else 0

    def report(self, services: list[str]) -> dict:
        results = {}
        for svc in services:
            freq = self.deployment_frequency(svc)
            lead = self.lead_time(svc)
            cfr = self.change_failure_rate(svc)
            # Classify per DORA research thresholds
            results[svc] = {
                "deployment_frequency": freq,
                "frequency_band": "Elite" if freq >= 1 else "High" if freq >= 1/7 else "Medium",
                "lead_time_hours": lead,
                "lead_time_band": "Elite" if lead < 1 else "High" if lead < 24 else "Medium",
                "change_failure_rate": cfr,
                "cfr_band": "Elite" if cfr < 0.05 else "High" if cfr < 0.10 else "Medium",
            }
        return results
```

## Key Commands Reference

```bash
# Backstage
npx @backstage/create-app@latest         # Bootstrap new portal
yarn backstage-cli package start          # Run plugin in dev mode
yarn tsc                                  # Type-check all packages
yarn build:all                            # Production build

# Crossplane
kubectl get managed                       # All cloud resources managed by Crossplane
kubectl get composite                     # All composite resource claims
kubectl describe postgresqldatabase order-db  # Debug a claim
kubectl get events --field-selector reason=CannotObserveExternalResource

# Argo CD
argocd app list                           # All apps and sync status
argocd app get order-service              # Detailed app status
argocd app sync order-service             # Manual sync
argocd app rollback order-service 3       # Roll back to revision 3
argocd proj list                          # List projects (RBAC boundaries)

# Port Forward for local access
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Backstage TechDocs generate locally
npx @techdocs/cli generate --source-dir . --output-dir ./site
npx @techdocs/cli serve  # Preview at localhost:3000
```

## Common Patterns

### Pattern 1: Environment-Per-Team with Namespace Isolation

```yaml
# platform/team-namespace.yaml — give each team their own sandbox
apiVersion: v1
kind: Namespace
metadata:
  name: order-team
  labels:
    team: order-team
    cost-center: "CC-1234"
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: order-team-developers
  namespace: order-team
subjects:
  - kind: Group
    name: acme-corp:order-team  # GitHub team via OIDC
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: edit
  apiGroup: rbac.authorization.k8s.io
---
# ResourceQuota keeps teams from over-provisioning
apiVersion: v1
kind: ResourceQuota
metadata:
  name: order-team-quota
  namespace: order-team
spec:
  hard:
    requests.cpu: "8"
    requests.memory: 16Gi
    limits.cpu: "16"
    limits.memory: 32Gi
    count/pods: "50"
```

### Pattern 2: Internal Platform API with Self-Service Provisioning

```python
# platform/api/main.py — REST API wrapping platform operations
from fastapi import FastAPI, BackgroundTasks
from pydantic import BaseModel
import subprocess, uuid

app = FastAPI(title="Platform API")

class ServiceRequest(BaseModel):
    name: str
    team: str
    language: str  # python | nodejs | go
    database: str | None = None  # postgres | redis | none

class ProvisionStatus(BaseModel):
    job_id: str
    status: str  # pending | running | complete | failed
    repo_url: str | None = None
    argocd_url: str | None = None

jobs: dict[str, ProvisionStatus] = {}

@app.post("/services", response_model=ProvisionStatus)
async def create_service(req: ServiceRequest, bg: BackgroundTasks):
    job_id = str(uuid.uuid4())
    jobs[job_id] = ProvisionStatus(job_id=job_id, status="pending")
    bg.add_task(provision_service, job_id, req)
    return jobs[job_id]

async def provision_service(job_id: str, req: ServiceRequest):
    jobs[job_id].status = "running"
    try:
        # Trigger Backstage scaffolder via API
        result = subprocess.run([
            "backstage-cli", "scaffold",
            "--template", f"{req.language}-service",
            "--values", f"name={req.name},owner={req.team}"
        ], capture_output=True, text=True, check=True)
        jobs[job_id].status = "complete"
        jobs[job_id].repo_url = f"https://github.com/acme-corp/{req.name}"
    except subprocess.CalledProcessError as e:
        jobs[job_id].status = "failed"

@app.get("/services/{job_id}", response_model=ProvisionStatus)
async def get_status(job_id: str):
    return jobs[job_id]
```

### Pattern 3: Platform Health Dashboard Query

```python
# Aggregate platform health: track golden path adoption
import httpx, json

def platform_adoption_report(backstage_url: str, token: str) -> dict:
    """What % of services use golden path templates vs custom setup."""
    client = httpx.Client(
        base_url=backstage_url,
        headers={"Authorization": f"Bearer {token}"}
    )
    components = client.get("/api/catalog/entities",
                            params={"filter": "kind=component,spec.type=service"}).json()
    total = len(components["items"])
    golden_path = sum(
        1 for c in components["items"]
        if c.get("metadata", {}).get("annotations", {}).get("scaffolded-by-platform") == "true"
    )
    with_techdocs = sum(
        1 for c in components["items"]
        if "backstage.io/techdocs-ref" in c.get("metadata", {}).get("annotations", {})
    )
    return {
        "total_services": total,
        "golden_path_adoption": f"{100*golden_path/total:.1f}%",
        "techdocs_adoption": f"{100*with_techdocs/total:.1f}%",
    }
```

## Pitfalls to Avoid

1. **Building a platform no one asked for**: The most common failure is a platform team building abstractions based on their own opinions without continuous feedback from developer customers. Run quarterly developer experience surveys (SPACE framework), treat pain points as a backlog, and measure adoption — not just feature delivery. A golden path no one uses is just extra maintenance.

2. **Making the golden path mandatory before it's golden**: If you force teams onto your platform before it handles their edge cases, they'll route around it and you'll lose trust. Start with a small pilot team, iterate until the path is genuinely better than DIY, then expand. The "pave the path people are already walking" approach beats imposing structure from above.

3. **No versioning or migration strategy for platform changes**: When you change a template, Crossplane composition, or Argo CD policy, every service built on it is affected. Treat breaking changes like library releases — version your APIs, provide migration guides, and give teams a deprecation window before removing old platform features.

## Related Skills

- `kubernetes-architect` — Cluster design, multi-tenancy, node pool strategy
- `ci-cd-pipeline-builder` — GitHub Actions and pipeline patterns the platform wraps
- `senior-devops` — Broader SRE and operations practices
- `service-mesh-istio` — Service mesh layer that platform teams often manage
- `api-gateway-design` — Gateway patterns for internal platform APIs

## GitNexus Index

```json
{
  "skill": "platform-engineering",
  "category": "devops",
  "triggers": ["platform engineering", "internal developer platform", "IDP", "backstage", "golden path", "developer portal", "crossplane", "argocd", "gitops", "DORA metrics", "self-service infrastructure"],
  "outputs": ["app-config.yaml", "catalog-info.yaml", "scaffolding template", "Crossplane composition", "Argo CD Application", "DORACalculator"],
  "complexity": "high",
  "tools": ["backstage", "crossplane", "argocd", "kubernetes", "github", "pagerduty", "python", "fastapi"]
}
```
