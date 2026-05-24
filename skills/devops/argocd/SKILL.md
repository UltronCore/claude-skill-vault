---
name: argocd
description: ArgoCD — GitOps continuous delivery for Kubernetes. Use this skill whenever the user wants to set up GitOps workflows, sync Kubernetes manifests from Git, manage ArgoCD Applications/AppProjects, configure sync policies, health checks, rollouts, or multi-cluster deployments. Trigger for "argocd", "GitOps", "sync from git", ApplicationSet, App of Apps pattern, or "deploy to kubernetes from git".
---

# ArgoCD — GitOps Continuous Delivery for Kubernetes

## Overview

ArgoCD is a declarative GitOps continuous delivery tool for Kubernetes. It watches Git repositories and automatically synchronizes the desired state (YAML manifests, Helm charts, Kustomize, etc.) to running Kubernetes clusters. Everything is expressed as Kubernetes Custom Resources, making it auditable, versionable, and self-documenting.

## When to Use

- Setting up GitOps pipelines for Kubernetes workloads
- Multi-cluster deployments with centralized control
- Helm chart lifecycle management with GitOps controls
- Progressive delivery with Argo Rollouts integration
- Implementing App of Apps patterns for fleet management

## Installation

```bash
# Install ArgoCD into a cluster
kubectl create namespace argocd
kubectl apply -n argocd -f \
  https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for pods
kubectl wait --for=condition=available deployment/argocd-server \
  -n argocd --timeout=120s

# Get initial admin password
kubectl get secret argocd-initial-admin-secret \
  -n argocd -o jsonpath="{.data.password}" | base64 -d

# Port-forward the UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Install CLI (macOS)
brew install argocd
argocd login localhost:8080 --username admin --insecure
```

## Key Patterns

### Application Resource

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io  # cascade delete
spec:
  project: default
  source:
    repoURL: https://github.com/my-org/my-app.git
    targetRevision: main
    path: k8s/overlays/prod
  destination:
    server: https://kubernetes.default.svc
    namespace: my-app
  syncPolicy:
    automated:
      prune: true       # delete resources removed from git
      selfHeal: true    # revert manual changes in cluster
      allowEmpty: false
    syncOptions:
      - CreateNamespace=true
      - PrunePropagationPolicy=foreground
      - ApplyOutOfSyncOnly=true
    retry:
      limit: 3
      backoff:
        duration: 5s
        maxDuration: 3m
        factor: 2
```

### Helm Application

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: prometheus-stack
  namespace: argocd
spec:
  project: monitoring
  source:
    repoURL: https://prometheus-community.github.io/helm-charts
    chart: kube-prometheus-stack
    targetRevision: 58.x
    helm:
      releaseName: prometheus
      values: |
        grafana:
          adminPassword: $argocd-prometheus:grafana-password
        alertmanager:
          enabled: true
  destination:
    server: https://kubernetes.default.svc
    namespace: monitoring
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true  # for large CRDs
```

### AppProject — RBAC and Access Control

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: team-alpha
  namespace: argocd
spec:
  description: "Team Alpha applications"
  sourceRepos:
    - https://github.com/my-org/*
  destinations:
    - namespace: team-alpha-*
      server: https://kubernetes.default.svc
    - namespace: shared-*
      server: https://kubernetes.default.svc
  clusterResourceWhitelist:
    - group: ""
      kind: Namespace
  namespaceResourceBlacklist:
    - group: ""
      kind: ResourceQuota
  roles:
    - name: developer
      policies:
        - p, proj:team-alpha:developer, applications, get, team-alpha/*, allow
        - p, proj:team-alpha:developer, applications, sync, team-alpha/*, allow
      groups:
        - org:team-alpha
```

### App of Apps Pattern (Fleet Management)

```yaml
# Root application that manages child applications
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: root
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/my-org/gitops.git
    targetRevision: HEAD
    path: apps/  # directory of Application YAMLs
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### ApplicationSet — Multi-Cluster / Multi-Env

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: my-app-all-envs
  namespace: argocd
spec:
  generators:
    - list:
        elements:
          - cluster: dev
            url: https://dev-cluster.example.com
            revision: develop
          - cluster: staging
            url: https://staging-cluster.example.com
            revision: main
          - cluster: prod
            url: https://prod-cluster.example.com
            revision: main
  template:
    metadata:
      name: "my-app-{{cluster}}"
    spec:
      project: default
      source:
        repoURL: https://github.com/my-org/my-app.git
        targetRevision: "{{revision}}"
        path: "k8s/overlays/{{cluster}}"
      destination:
        server: "{{url}}"
        namespace: my-app
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
```

### Sync Waves and Resource Hooks

```yaml
# Control sync order with waves (lower = syncs first)
apiVersion: batch/v1
kind: Job
metadata:
  name: db-migration
  annotations:
    argocd.argoproj.io/hook: PreSync
    argocd.argoproj.io/hook-delete-policy: HookSucceeded
    argocd.argoproj.io/sync-wave: "-1"  # runs before other resources
spec:
  template:
    spec:
      containers:
        - name: migrate
          image: my-app:latest
          command: ["python", "manage.py", "migrate"]
      restartPolicy: Never
```

## Common CLI Commands

```bash
argocd app list                        # List all apps
argocd app get my-app                  # Detailed app status
argocd app sync my-app                 # Trigger manual sync
argocd app sync my-app --dry-run       # Preview sync (no changes)
argocd app diff my-app                 # Show diff vs current cluster state
argocd app rollback my-app 3           # Roll back to revision 3
argocd app set my-app --sync-policy automated
argocd app delete my-app --cascade     # Delete app + resources
argocd cluster add <context>           # Register a cluster
argocd repo add https://github.com/org/repo --ssh-private-key-path ~/.ssh/id_rsa
argocd account list                    # List users
```

## Pitfalls

- **Automated sync + prune with no testing**: `prune: true` will delete resources removed from Git — including accidentally deleted files. Use branch protection and review processes
- **CRD size limits**: large CRDs exceed annotation limits; use `ServerSideApply=true` in syncOptions
- **Secrets in Git**: never store raw secrets in the repo; use Sealed Secrets, External Secrets Operator, or Vault Agent Injector
- **Health check custom resources**: CRDs need custom health checks or ArgoCD marks them `Unknown`; add Lua health checks in `argocd-cm` ConfigMap
- **`ignoreDifferences`**: use when controllers mutate resources after apply (e.g., adding defaults) to prevent infinite sync loops

## Related Skills

- `flux-cd` — alternative GitOps operator
- `kubernetes-architect` — cluster architecture
- `k8s-manifest-generator` — writing K8s manifests
- `crossplane` — infrastructure provisioning via GitOps

## GitNexus Index

Index path: /Users/localuser/.claude/skills/argocd/.gitnexus
Created: 2026-05-24
