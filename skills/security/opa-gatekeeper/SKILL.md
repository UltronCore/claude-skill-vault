---
name: opa-gatekeeper
description: OPA/Gatekeeper — Open Policy Agent and Gatekeeper for Kubernetes policy enforcement. Use this skill whenever the user wants to enforce admission policies in Kubernetes, write Rego policies, set up ConstraintTemplates, prevent privileged containers, enforce label standards, validate image registries, or use OPA for general policy-as-code. Trigger for "OPA", "Gatekeeper", "ConstraintTemplate", "Rego", "admission webhook", or "policy enforcement kubernetes".
---

# OPA/Gatekeeper — Policy Enforcement for Kubernetes

## Overview

Open Policy Agent (OPA) is a general-purpose policy engine using the Rego language. Gatekeeper is the Kubernetes-native OPA integration — it runs as an admission webhook and validates or mutates resources before they're created/updated. Together they let you enforce standards like "all images must come from our registry", "pods must have resource limits", or "namespaces must have required labels".

## When to Use

- Enforcing security policies at admission time (before pods run)
- Requiring resource limits/requests on all workloads
- Restricting container image registries
- Mandating label/annotation standards
- Preventing privileged containers or host path mounts
- Implementing compliance requirements (SOC2, CIS benchmarks)

## Installation

```bash
# Install Gatekeeper with Helm
helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts
helm install gatekeeper gatekeeper/gatekeeper \
  --namespace gatekeeper-system \
  --create-namespace \
  --version 3.16.0 \
  --set replicas=2 \
  --set auditInterval=60

# Verify
kubectl get pods -n gatekeeper-system
kubectl get crd | grep constraints.gatekeeper.sh
```

## Key Patterns

### ConstraintTemplate — Define a Policy Type

```yaml
# ConstraintTemplate creates a new CRD for your constraint type
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8srequiredlabels
spec:
  crd:
    spec:
      names:
        kind: K8sRequiredLabels
      validation:
        openAPIV3Schema:
          type: object
          properties:
            labels:
              type: array
              items:
                type: string
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8srequiredlabels

        violation[{"msg": msg, "details": {"missing_labels": missing}}] {
          provided := {label | input.review.object.metadata.labels[label]}
          required := {label | label := input.parameters.labels[_]}
          missing := required - provided
          count(missing) > 0
          msg := sprintf("Missing required labels: %v", [missing])
        }
```

### Constraint — Apply the Policy

```yaml
# Require "app" and "team" labels on all Pods in production namespaces
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequiredLabels
metadata:
  name: pods-must-have-labels
spec:
  match:
    kinds:
      - apiGroups: [""]
        kinds: ["Pod"]
    namespaceSelector:
      matchLabels:
        environment: production
  parameters:
    labels:
      - app
      - team
      - version
```

### Common Policy: Restrict Image Registries

```yaml
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8sallowedrepos
spec:
  crd:
    spec:
      names:
        kind: K8sAllowedRepos
      validation:
        openAPIV3Schema:
          type: object
          properties:
            repos:
              type: array
              items:
                type: string
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8sallowedrepos

        violation[{"msg": msg}] {
          container := input.review.object.spec.containers[_]
          satisfied := [good | repo := input.parameters.repos[_]; good := startswith(container.image, repo)]
          not any(satisfied)
          msg := sprintf("container <%v> has an invalid image repo <%v>; allowed repos are %v",
            [container.name, container.image, input.parameters.repos])
        }

        violation[{"msg": msg}] {
          container := input.review.object.spec.initContainers[_]
          satisfied := [good | repo := input.parameters.repos[_]; good := startswith(container.image, repo)]
          not any(satisfied)
          msg := sprintf("initContainer <%v> has an invalid image repo <%v>; allowed repos are %v",
            [container.name, container.image, input.parameters.repos])
        }
---
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sAllowedRepos
metadata:
  name: allowed-repos
spec:
  match:
    kinds:
      - apiGroups: [""]
        kinds: ["Pod"]
  parameters:
    repos:
      - "my-registry.io/"
      - "gcr.io/my-project/"
      - "docker.io/library/"  # allow official images
```

### Common Policy: Require Resource Limits

```yaml
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8scontainerlimits
spec:
  crd:
    spec:
      names:
        kind: K8sContainerLimits
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8scontainerlimits

        violation[{"msg": msg}] {
          container := input.review.object.spec.containers[_]
          not container.resources.limits.cpu
          msg := sprintf("Container <%v> has no CPU limit", [container.name])
        }

        violation[{"msg": msg}] {
          container := input.review.object.spec.containers[_]
          not container.resources.limits.memory
          msg := sprintf("Container <%v> has no memory limit", [container.name])
        }
---
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sContainerLimits
metadata:
  name: container-must-have-limits
spec:
  enforcementAction: warn  # start with warn, change to deny when ready
  match:
    kinds:
      - apiGroups: ["apps"]
        kinds: ["Deployment", "StatefulSet", "DaemonSet"]
```

### Exempting Namespaces / Resources

```yaml
# Add label to exempt a namespace
kubectl label namespace kube-system admission.gatekeeper.sh/ignore=no-policy

# Or use excludedNamespaces in the Constraint
spec:
  match:
    excludedNamespaces:
      - kube-system
      - kube-public
      - gatekeeper-system
      - cert-manager
```

### OPA Standalone (without Kubernetes)

```bash
# Install OPA CLI
brew install opa

# Write a policy
cat > policy.rego <<EOF
package example

default allow = false

allow {
  input.method == "GET"
  input.path == ["api", "public"]
}
EOF

# Test with input data
echo '{"method": "GET", "path": ["api", "public"]}' | opa eval -d policy.rego -I "data.example.allow"

# Unit test
cat > policy_test.rego <<EOF
package example_test

test_allow_public_get {
  data.example.allow with input as {"method": "GET", "path": ["api", "public"]}
}

test_deny_post {
  not data.example.allow with input as {"method": "POST", "path": ["api", "public"]}
}
EOF
opa test -v policy.rego policy_test.rego
```

## Common Commands

```bash
kubectl get constrainttemplate                       # List templates
kubectl get constraints                              # List all constraints
kubectl describe k8srequiredlabels/pods-must-have-labels  # Details + violations
kubectl get constraint -o json | jq '.items[].status.totalViolations'  # Count violations
kubectl logs -n gatekeeper-system -l control-plane=controller-manager  # Gatekeeper logs
```

## Pitfalls

- **`deny` vs `warn` enforcement**: start with `enforcementAction: warn` to audit without blocking; flip to `deny` once you understand the blast radius
- **Dry-run existing resources**: Gatekeeper audits existing resources on a schedule (`auditInterval`); policy violations on pre-existing resources don't block anything until re-creation
- **Rego debugging is hard**: use `opa eval` locally with real resource JSON (`kubectl get pod -o json`) to test rules before deploying
- **Large clusters**: admission webhook adds latency; ensure Gatekeeper replicas have resource limits and the webhook has a timeout
- **Excluded namespaces**: system namespaces need to be excluded or cluster operations (metrics-server, CNI pods) will be blocked

## Related Skills

- `falco` — runtime security (complements OPA at admission time)
- `kubernetes-architect` — cluster security architecture
- `security-hardening-checklist` — broader K8s hardening

## GitNexus Index

Index path: /Users/localuser/.claude/skills/opa-gatekeeper/.gitnexus
Created: 2026-05-24
