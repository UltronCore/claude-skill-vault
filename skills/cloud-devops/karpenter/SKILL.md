---
name: karpenter
description: Karpenter — Kubernetes node autoprovisioning and autoscaling. Use this skill whenever the user wants to automatically provision EC2 instances (or other cloud VMs) for Kubernetes workloads, replace Cluster Autoscaler, configure NodePools/NodeClasses, use spot instances with intelligent fallback, or optimize node provisioning costs. Trigger for "karpenter", "NodePool", "EC2NodeClass", "spot instance autoscaling", or "node provisioning kubernetes".
---

# Karpenter — Kubernetes Node Autoprovisioning

## Overview

Karpenter is a flexible, high-performance Kubernetes node autoprovisioner. Unlike Cluster Autoscaler (which scales existing node groups), Karpenter directly provisions EC2 instances (or Azure/GCP VMs) based on pending pod requirements — picking the right instance type, AZ, and capacity type (spot/on-demand) automatically. It consolidates underutilized nodes and can replace spot instances proactively before interruption.

## When to Use

- Replacing Cluster Autoscaler for faster, smarter node provisioning
- Using spot instances with automatic fallback to on-demand
- Heterogeneous workloads needing different instance types (GPU, memory-optimized, etc.)
- Cost optimization via bin-packing and node consolidation
- Multi-architecture clusters (arm64 + amd64)

## Installation (AWS EKS)

```bash
# Prerequisites: EKS cluster with IRSA enabled, Karpenter IAM roles
# Full setup guide: https://karpenter.sh/docs/getting-started/getting-started-with-karpenter/

export CLUSTER_NAME="my-cluster"
export AWS_DEFAULT_REGION="us-east-1"
export AWS_ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
export KARPENTER_VERSION="1.0.0"

# Add Helm repo
helm repo add karpenter https://charts.karpenter.sh/
helm install karpenter karpenter/karpenter \
  --namespace kube-system \
  --version "${KARPENTER_VERSION}" \
  --set "settings.clusterName=${CLUSTER_NAME}" \
  --set "settings.interruptionQueue=${CLUSTER_NAME}" \
  --set controller.resources.requests.cpu=1 \
  --set controller.resources.requests.memory=1Gi \
  --wait
```

## Key Patterns

### NodePool — Define What Nodes Karpenter Can Provision

```yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: general-purpose
spec:
  template:
    metadata:
      labels:
        node-type: general
    spec:
      # Which EC2NodeClass to use (cloud-specific config)
      nodeClassRef:
        group: karpenter.k8s.aws
        kind: EC2NodeClass
        name: default
      requirements:
        # Allow multiple instance families for flexibility
        - key: karpenter.k8s.aws/instance-family
          operator: In
          values: [m5, m6i, m6a, c5, c6i, r5, r6i]
        - key: karpenter.k8s.aws/instance-size
          operator: In
          values: [xlarge, 2xlarge, 4xlarge]
        - key: kubernetes.io/arch
          operator: In
          values: [amd64]
        # Use spot with on-demand fallback
        - key: karpenter.sh/capacity-type
          operator: In
          values: [spot, on-demand]
        # Spread across AZs
        - key: topology.kubernetes.io/zone
          operator: In
          values: [us-east-1a, us-east-1b, us-east-1c]
      # Expire nodes after 720h to refresh AMIs
      expireAfter: 720h
  # Consolidation: remove underutilized nodes
  disruption:
    consolidationPolicy: WhenEmptyOrUnderutilized
    consolidateAfter: 1m
    budgets:
      - nodes: "10%"   # don't disrupt more than 10% of nodes at once
  # Maximum nodes in this pool
  limits:
    cpu: 1000
    memory: 4000Gi
```

### EC2NodeClass — AWS-Specific Configuration

```yaml
apiVersion: karpenter.k8s.aws/v1
kind: EC2NodeClass
metadata:
  name: default
spec:
  # AMI family — Karpenter finds the latest matching AMI
  amiFamily: AL2023  # Amazon Linux 2023
  # Or use custom AMI selector:
  # amiSelectorTerms:
  #   - tags:
  #       karpenter.sh/discovery: my-cluster

  # IAM role for the nodes
  role: "KarpenterNodeRole-${CLUSTER_NAME}"

  # Subnets (discovered via tags)
  subnetSelectorTerms:
    - tags:
        karpenter.sh/discovery: "${CLUSTER_NAME}"

  # Security groups (discovered via tags)
  securityGroupSelectorTerms:
    - tags:
        karpenter.sh/discovery: "${CLUSTER_NAME}"

  # Ephemeral storage
  blockDeviceMappings:
    - deviceName: /dev/xvda
      ebs:
        volumeSize: 50Gi
        volumeType: gp3
        encrypted: true

  # User data for node initialization
  userData: |
    #!/bin/bash
    /etc/eks/bootstrap.sh ${CLUSTER_NAME}

  # Tags applied to provisioned instances
  tags:
    ManagedBy: karpenter
    Cluster: "${CLUSTER_NAME}"
```

### GPU Workloads

```yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: gpu
spec:
  template:
    spec:
      nodeClassRef:
        group: karpenter.k8s.aws
        kind: EC2NodeClass
        name: gpu-nodes
      requirements:
        - key: karpenter.k8s.aws/instance-family
          operator: In
          values: [p3, p4d, g4dn, g5]
        - key: karpenter.sh/capacity-type
          operator: In
          values: [on-demand]  # GPU spot is rare; use on-demand
      taints:
        - key: nvidia.com/gpu
          effect: NoSchedule
  limits:
    cpu: 500
    "nvidia.com/gpu": 64
```

### Pod Configuration for Karpenter Scheduling

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  template:
    spec:
      # Tolerate spot interruptions
      tolerations:
        - key: "karpenter.sh/capacity-type"
          operator: "Equal"
          value: "spot"
          effect: "NoSchedule"
      # Prefer spot nodes
      nodeSelector:
        karpenter.sh/capacity-type: spot
      # Spread across AZs (works with Karpenter's topology awareness)
      topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: topology.kubernetes.io/zone
          whenUnsatisfiable: DoNotSchedule
          labelSelector:
            matchLabels:
              app: my-app
      containers:
        - name: app
          resources:
            requests:
              cpu: "500m"
              memory: "512Mi"
            limits:
              cpu: "2"
              memory: "2Gi"
```

### Do-Not-Disrupt Annotation

```yaml
# Prevent Karpenter from terminating a node during maintenance
kubectl annotate node my-node karpenter.sh/do-not-disrupt=true

# Or on pods that should not be evicted
metadata:
  annotations:
    karpenter.sh/do-not-disrupt: "true"
```

## Common Commands

```bash
kubectl get nodepools                           # List NodePools
kubectl get nodeclaims                          # See provisioned node claims
kubectl get ec2nodeclass                        # List EC2NodeClasses
kubectl describe nodepool general-purpose       # Pool details + status
kubectl logs -n kube-system -l app.kubernetes.io/name=karpenter -f  # Controller logs

# Force consolidation (drain and remove underutilized nodes)
kubectl delete nodeclaim <name>

# Check Karpenter decisions
kubectl logs -n kube-system -l app.kubernetes.io/name=karpenter | grep "launched node"
```

## Pitfalls

- **No PodDisruptionBudgets = aggressive consolidation**: always configure PDBs on stateful workloads or Karpenter may evict multiple pods simultaneously during consolidation
- **Spot interruption handling**: use the NTH (Node Termination Handler) or Karpenter's built-in interruption queue to gracefully drain spot nodes before AWS reclaims them
- **Instance type diversity**: too-narrow requirements (only one instance type) reduce spot availability and increase provisioning failures; list 5-10 compatible families
- **expireAfter for AMI freshness**: without expiration, nodes can run forever on stale AMIs with unpatched CVEs
- **Drift detection**: enable `FEATURE_GATE_DRIFT=true` to detect and replace nodes whose configuration has diverged from the NodePool spec

## Related Skills

- `kubernetes-architect` — cluster design
- `argocd` — GitOps for Karpenter configs
- `cost-optimization-cloud` — broader cloud cost strategy
- `aws-solution-architect` — EKS and EC2 design

## GitNexus Index

Index path: /Users/localuser/.claude/skills/karpenter/.gitnexus
Created: 2026-05-24
