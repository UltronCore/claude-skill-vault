---
name: crossplane
description: Crossplane — Kubernetes-native infrastructure control plane. Use this skill whenever the user wants to manage cloud infrastructure using Kubernetes CRDs, build internal developer platforms (IDPs), compose cloud resources with XRDs/Compositions, use provider-aws/azure/gcp, or talk about "infrastructure as Kubernetes objects". Trigger for mentions of Crossplane, composite resources, XRDs, Compositions, managed resources, or "IDP on Kubernetes".
---

# Crossplane — Kubernetes-Native Infrastructure Control

## Overview

Crossplane extends Kubernetes so you can provision and manage cloud infrastructure (AWS, Azure, GCP, etc.) using the same `kubectl` workflows and GitOps tools you use for applications. Infrastructure is defined as Kubernetes Custom Resource Definitions (CRDs), managed by Crossplane providers. Platform teams build Compositions that abstract cloud resources into simple, opinionated APIs for developers.

## When to Use

- Building Internal Developer Platforms (IDPs) where developers self-service infrastructure
- Managing multi-cloud infrastructure declaratively with GitOps
- Abstracting cloud complexity behind custom Kubernetes APIs
- Replacing Terraform/Helm for infrastructure when you're already Kubernetes-native
- Composing multiple cloud resources into reusable "XR" (Composite Resource) blueprints

## Installation

```bash
# Install Crossplane into a Kubernetes cluster
helm repo add crossplane-stable https://charts.crossplane.io/stable
helm install crossplane \
  crossplane-stable/crossplane \
  --namespace crossplane-system \
  --create-namespace \
  --version 1.15.0

# Verify
kubectl get pods -n crossplane-system

# Install the AWS provider
cat <<EOF | kubectl apply -f -
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-aws-s3
spec:
  package: xpkg.upbound.io/upbound/provider-aws-s3:v1.5.0
EOF
```

## Key Patterns

### Provider Authentication (AWS)

```yaml
# Create a Kubernetes secret with AWS credentials
kubectl create secret generic aws-creds \
  -n crossplane-system \
  --from-file=credentials=./aws-credentials.txt

# ProviderConfig tells Crossplane how to authenticate
apiVersion: aws.upbound.io/v1beta1
kind: ProviderConfig
metadata:
  name: default
spec:
  credentials:
    source: Secret
    secretRef:
      namespace: crossplane-system
      name: aws-creds
      key: credentials
```

### Managed Resource (direct cloud resource)

```yaml
# Create an S3 bucket directly
apiVersion: s3.aws.upbound.io/v1beta1
kind: Bucket
metadata:
  name: my-crossplane-bucket
  annotations:
    crossplane.io/external-name: my-unique-bucket-name-2024
spec:
  forProvider:
    region: us-east-1
    tags:
      ManagedBy: crossplane
  providerConfigRef:
    name: default
```

### Composite Resource Definition (XRD) — Platform API

```yaml
# Define a custom API for developers (e.g., XDatabase)
apiVersion: apiextensions.crossplane.io/v1
kind: CompositeResourceDefinition
metadata:
  name: xdatabases.platform.example.com
spec:
  group: platform.example.com
  names:
    kind: XDatabase
    plural: xdatabases
  claimNames:
    kind: Database
    plural: databases
  versions:
    - name: v1alpha1
      served: true
      referenceable: true
      schema:
        openAPIV3Schema:
          type: object
          properties:
            spec:
              type: object
              properties:
                parameters:
                  type: object
                  required: [storageGB, engine]
                  properties:
                    storageGB:
                      type: integer
                      minimum: 20
                    engine:
                      type: string
                      enum: [postgres, mysql]
                    region:
                      type: string
                      default: us-east-1
```

### Composition — Wires XRD to Real Resources

```yaml
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: database-aws-postgres
  labels:
    provider: aws
    engine: postgres
spec:
  compositeTypeRef:
    apiVersion: platform.example.com/v1alpha1
    kind: XDatabase
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
            engineVersion: "15.3"
            skipFinalSnapshot: true
            autoMinorVersionUpgrade: true
            publiclyAccessible: false
            dbSubnetGroupNameSelector:
              matchControllerRef: true
      patches:
        - type: FromCompositeFieldPath
          fromFieldPath: spec.parameters.storageGB
          toFieldPath: spec.forProvider.allocatedStorage
        - type: FromCompositeFieldPath
          fromFieldPath: spec.parameters.region
          toFieldPath: spec.forProvider.region
```

### Claim — Developer Uses the Platform API

```yaml
# Developer creates a database using the simplified API
apiVersion: platform.example.com/v1alpha1
kind: Database
metadata:
  name: my-app-db
  namespace: team-a
spec:
  parameters:
    storageGB: 50
    engine: postgres
    region: us-east-1
  compositionSelector:
    matchLabels:
      provider: aws
      engine: postgres
  writeConnectionSecretToRef:
    name: db-connection
```

### Package / Configuration

```yaml
# Bundle providers + compositions into a reusable package
apiVersion: pkg.crossplane.io/v1
kind: Configuration
metadata:
  name: platform-ref-aws
spec:
  package: xpkg.upbound.io/upbound/platform-ref-aws:v0.9.0
```

## Common Commands

```bash
# List all managed resources and their status
kubectl get managed

# Check composite resources
kubectl get composite

# Watch provisioning
kubectl get crossplane -w

# Debug a stuck resource
kubectl describe bucket.s3.aws.upbound.io/my-bucket
kubectl get events --field-selector reason=CannotObserveExternalResource

# Delete claim (cascades to composite + managed resources)
kubectl delete database.platform.example.com/my-app-db -n team-a
```

## Pitfalls

- **Deletion policy**: default is `Delete` — deleting a Managed Resource deletes the cloud resource. Use `deletionPolicy: Orphan` to preserve cloud resources when removing from Kubernetes
- **External name annotation**: `crossplane.io/external-name` controls the actual name in the cloud provider — omit it to auto-generate
- **Provider version pinning**: always pin provider package versions; breaking changes exist between minor releases
- **Composition readiness**: composite resources stay `NotReady` until all composed resources are `Ready` — check individual managed resource events for root cause
- **RBAC for claims**: developers need RBAC to create Claims in their namespace; they don't need permissions to composite resources

## Related Skills

- `kubernetes-architect` — cluster design and patterns
- `k8s-manifest-generator` — writing Kubernetes manifests
- `argocd` — GitOps delivery for Crossplane configurations
- `pulumi` — alternative IaC approach

## GitNexus Index

Index path: /Users/localuser/.claude/skills/crossplane/.gitnexus
Created: 2026-05-24
