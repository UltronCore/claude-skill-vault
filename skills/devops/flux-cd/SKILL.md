---
name: flux-cd
description: Flux CD — GitOps operator for Kubernetes (CNCF graduated project). Use this skill whenever the user wants GitOps with Flux, needs to set up automated Kubernetes deployments from Git, configure Flux sources/kustomizations/helmreleases, use image automation, bootstrap Flux with GitHub/GitLab, or asks about the Flux CLI (flux). Trigger for "flux bootstrap", "HelmRelease", "Kustomization CRD", "image reflector", or "GitRepository source".
---

# Flux CD — GitOps Operator for Kubernetes

## Overview

Flux is a CNCF-graduated GitOps operator that continuously reconciles the state of your Kubernetes cluster with what's defined in Git. It uses a set of controllers (source-controller, kustomize-controller, helm-controller, notification-controller, image-reflector-controller) that each handle a specific concern. Unlike ArgoCD's UI-centric model, Flux is intentionally lightweight and CLI/API-first.

## When to Use

- Setting up GitOps for Kubernetes without a heavy UI
- Automated Helm chart upgrades via image automation
- Multi-tenancy GitOps with separate repos per team
- Progressive delivery with Flagger integration
- Bootstrapping entire cluster configuration from Git on first install

## Installation

```bash
# Install Flux CLI (macOS)
brew install fluxcd/tap/flux

# Check prerequisites
flux check --pre

# Bootstrap with GitHub (creates flux-system namespace + repo folder)
flux bootstrap github \
  --owner=my-org \
  --repository=fleet-infra \
  --branch=main \
  --path=./clusters/prod \
  --personal   # omit for org token

# Bootstrap with GitLab
flux bootstrap gitlab \
  --owner=my-group \
  --repository=fleet-infra \
  --branch=main \
  --path=./clusters/prod
```

## Key Patterns

### GitRepository Source

```yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: my-app
  namespace: flux-system
spec:
  interval: 1m
  url: https://github.com/my-org/my-app
  ref:
    branch: main
  secretRef:
    name: github-token  # optional for public repos
```

### Kustomization — Deploy from Git Path

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: my-app
  namespace: flux-system
spec:
  interval: 10m
  path: ./k8s/overlays/prod
  prune: true         # delete removed resources
  sourceRef:
    kind: GitRepository
    name: my-app
  targetNamespace: my-app
  healthChecks:
    - apiVersion: apps/v1
      kind: Deployment
      name: my-app
      namespace: my-app
  postBuild:
    substituteFrom:
      - kind: ConfigMap
        name: cluster-vars
      - kind: Secret
        name: cluster-secrets
```

### HelmRepository + HelmRelease

```yaml
# Register a Helm chart repository
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: HelmRepository
metadata:
  name: prometheus-community
  namespace: flux-system
spec:
  interval: 1h
  url: https://prometheus-community.github.io/helm-charts
---
# Deploy a chart with specific values
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: kube-prometheus-stack
  namespace: monitoring
spec:
  interval: 1h
  chart:
    spec:
      chart: kube-prometheus-stack
      version: ">=58.0.0 <59.0.0"
      sourceRef:
        kind: HelmRepository
        name: prometheus-community
        namespace: flux-system
  values:
    grafana:
      enabled: true
      adminPassword: "${GRAFANA_ADMIN_PASSWORD}"
  valuesFrom:
    - kind: Secret
      name: prometheus-values-override
      optional: true
  install:
    crds: CreateReplace
    remediation:
      retries: 3
  upgrade:
    crds: CreateReplace
    remediation:
      retries: 3
      remediateLastFailure: true
```

### Image Automation — Auto-update Image Tags in Git

```yaml
# Watch an image repository for new tags
apiVersion: image.toolkit.fluxcd.io/v1beta2
kind: ImageRepository
metadata:
  name: my-app
  namespace: flux-system
spec:
  interval: 5m
  image: ghcr.io/my-org/my-app
  secretRef:
    name: ghcr-credentials
---
# Define a tag selection policy
apiVersion: image.toolkit.fluxcd.io/v1beta2
kind: ImagePolicy
metadata:
  name: my-app
  namespace: flux-system
spec:
  imageRepositoryRef:
    name: my-app
  policy:
    semver:
      range: ">=1.0.0"
---
# Automatically commit the new tag back to Git
apiVersion: image.toolkit.fluxcd.io/v1beta1
kind: ImageUpdateAutomation
metadata:
  name: flux-system
  namespace: flux-system
spec:
  interval: 30m
  sourceRef:
    kind: GitRepository
    name: flux-system
  git:
    push:
      branch: main
    commit:
      author:
        email: fluxcdbot@users.noreply.github.com
        name: fluxcdbot
  update:
    path: ./clusters
    strategy: Setters
```

```yaml
# In your Deployment, mark the image for automation
containers:
  - name: my-app
    image: ghcr.io/my-org/my-app:v1.2.3 # {"$imagepolicy": "flux-system:my-app"}
```

### Multi-Tenancy (Per-Team Repos)

```yaml
# Platform team's repo manages team namespaces + ServiceAccounts
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: team-alpha
  namespace: flux-system
spec:
  interval: 5m
  path: ./tenants/team-alpha
  prune: true
  sourceRef:
    kind: GitRepository
    name: fleet-infra
  serviceAccountName: team-alpha-reconciler  # limit blast radius
```

### Notification — Slack/Teams Alerts

```yaml
apiVersion: notification.toolkit.fluxcd.io/v1beta3
kind: Provider
metadata:
  name: slack
  namespace: flux-system
spec:
  type: slack
  channel: "#deployments"
  secretRef:
    name: slack-webhook
---
apiVersion: notification.toolkit.fluxcd.io/v1beta3
kind: Alert
metadata:
  name: on-call
  namespace: flux-system
spec:
  providerRef:
    name: slack
  eventSeverity: error
  eventSources:
    - kind: HelmRelease
      name: "*"
```

## Common CLI Commands

```bash
flux get all                          # Status of all Flux resources
flux get kustomizations               # Status of kustomizations
flux get helmreleases -A              # All HelmReleases across namespaces
flux reconcile source git flux-system # Force pull from Git
flux reconcile kustomization my-app   # Force reconcile
flux reconcile helmrelease my-app -n my-ns
flux suspend kustomization my-app     # Pause reconciliation
flux resume kustomization my-app      # Resume
flux logs --follow --level=error      # Stream Flux logs
flux diff kustomization my-app        # Show what would change
flux export source git my-app         # Export resource YAML
```

## Pitfalls

- **`prune: true` danger**: resources deleted from Git are deleted from the cluster immediately — use `suspend` before deleting from Git if you want to inspect first
- **Kustomization vs `kustomize` tool**: Flux's `Kustomization` CRD is not the same as running `kustomize build`; it's a controller that _uses_ kustomize
- **Image automation requires write access to Git**: configure a dedicated bot token/deploy key with write permissions; read-only tokens silently fail
- **Cross-namespace sources**: by default, a Kustomization can only reference sources in the same namespace — use `flux-system` namespace as a shared hub
- **Health checks block progress**: if a healthCheck resource never becomes `Ready`, the Kustomization hangs — always add timeouts via `timeout` field

## Related Skills

- `argocd` — alternative GitOps tool with a richer UI
- `kubernetes-architect` — cluster design
- `k8s-manifest-generator` — writing K8s manifests
- `karpenter` — node autoprovisioning
- `crossplane` — infrastructure provisioning

## GitNexus Index

Index path: /Users/localuser/.claude/skills/flux-cd/.gitnexus
Created: 2026-05-24
