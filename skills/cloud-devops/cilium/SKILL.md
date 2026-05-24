---
name: cilium
description: Cilium — eBPF-based networking, security, and observability for Kubernetes. Use this skill whenever the user needs Kubernetes CNI with advanced network policies, mutual TLS between services, Hubble observability, service mesh without sidecars, BGP routing, or wants to replace kube-proxy with eBPF. Trigger for "cilium", "eBPF networking", "Hubble", "CiliumNetworkPolicy", "WireGuard encryption", or "sidecar-free service mesh".
---

# Cilium — eBPF-Based Networking and Security

## Overview

Cilium is a CNCF-graduated CNI (Container Network Interface) plugin for Kubernetes that uses eBPF — a Linux kernel technology — to provide high-performance networking, security, and observability without sidecars. It replaces iptables with eBPF programs for dramatically better performance and adds L7 (HTTP/gRPC/Kafka) network policies, mutual TLS between pods, and deep network visibility via Hubble.

## When to Use

- Replacing kube-proxy with eBPF for better performance
- Enforcing L7 network policies (HTTP path/method, gRPC service)
- Getting network observability without a service mesh (Hubble)
- Encrypting pod-to-pod traffic with WireGuard or IPSec
- Multi-cluster networking with Cluster Mesh
- Service mesh without sidecar proxies (Cilium Service Mesh)

## Installation

```bash
# Install Cilium CLI
curl -L --remote-name-all https://github.com/cilium/cilium-cli/releases/latest/download/cilium-linux-amd64.tar.gz
sudo tar xzvfC cilium-linux-amd64.tar.gz /usr/local/bin

# macOS
brew install cilium-cli

# Install Cilium into a Kubernetes cluster
cilium install --version 1.15.0

# Or with Helm (more control)
helm repo add cilium https://helm.cilium.io/
helm install cilium cilium/cilium \
  --version 1.15.0 \
  --namespace kube-system \
  --set kubeProxyReplacement=true \
  --set k8sServiceHost=<API_SERVER_HOST> \
  --set k8sServicePort=6443 \
  --set hubble.relay.enabled=true \
  --set hubble.ui.enabled=true

# Verify
cilium status --wait
cilium connectivity test
```

## Key Patterns

### Standard Kubernetes NetworkPolicy (L3/L4)

Cilium is fully compatible with standard Kubernetes NetworkPolicy:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-api-to-db
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: postgres
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: api-server
      ports:
        - protocol: TCP
          port: 5432
```

### CiliumNetworkPolicy — L7 HTTP Policy

```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: l7-api-policy
  namespace: production
spec:
  endpointSelector:
    matchLabels:
      app: api-server
  ingress:
    - fromEndpoints:
        - matchLabels:
            app: frontend
      toPorts:
        - ports:
            - port: "8080"
              protocol: TCP
          rules:
            http:
              # Only allow GET /api/v1/products — block all other paths/methods
              - method: "GET"
                path: "^/api/v1/products$"
              - method: "POST"
                path: "^/api/v1/orders$"
  egress:
    - toFQDNs:
        - matchPattern: "*.amazonaws.com"
      toPorts:
        - ports:
            - port: "443"
              protocol: TCP
```

### CiliumNetworkPolicy — FQDN (DNS-based) Egress

```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: allow-external-apis
spec:
  endpointSelector:
    matchLabels:
      app: backend
  egress:
    # Allow access to specific external domains
    - toFQDNs:
        - matchName: "api.stripe.com"
        - matchName: "api.sendgrid.com"
        - matchPattern: "*.s3.us-east-1.amazonaws.com"
    # Block everything else by default (deny-all egress implied when any egress rule exists)
```

### WireGuard Encryption (Pod-to-Pod)

```yaml
# Enable during install
helm upgrade cilium cilium/cilium \
  --namespace kube-system \
  --reuse-values \
  --set encryption.enabled=true \
  --set encryption.type=wireguard

# Verify encryption
cilium encrypt status
```

### Hubble — Network Observability

```bash
# Enable Hubble UI
cilium hubble enable --ui

# Port-forward the UI
cilium hubble ui &

# Use Hubble CLI
hubble observe --namespace production --last 100
hubble observe --namespace production --pod api-server --protocol http
hubble observe --verdict DROPPED --last 50
hubble observe --from-pod frontend/nginx --to-pod backend/api

# Check flows with filters
hubble observe \
  --namespace production \
  --type drop \
  --http-method GET \
  --output json | jq .
```

### Cluster Mesh (Multi-Cluster)

```bash
# Enable Cluster Mesh on both clusters
cilium clustermesh enable --service-type LoadBalancer

# Connect clusters
cilium clustermesh connect --destination-context <cluster2-context>

# Verify
cilium clustermesh status

# In a cluster, expose a service to other clusters via annotation
kubectl annotate service my-service \
  service.cilium.io/global="true" \
  service.cilium.io/shared="true"
```

### BGP Control Plane

```yaml
# For bare-metal clusters: advertise LoadBalancer IPs via BGP
apiVersion: cilium.io/v2alpha1
kind: CiliumBGPPeeringPolicy
metadata:
  name: bgp-peering
spec:
  nodeSelector:
    matchLabels:
      kubernetes.io/os: linux
  virtualRouters:
    - localASN: 65001
      exportPodCIDR: true
      peers:
        - peerAddress: "192.168.1.1"
          peerASN: 65000
          eBGPMultihopTTL: 10
          connectRetryTimeSeconds: 120
          holdTimeSeconds: 90
          keepAliveTimeSeconds: 30
```

## Common Commands

```bash
cilium status                          # Health check
cilium connectivity test               # Full connectivity test suite
cilium monitor                         # Live eBPF event monitor
cilium monitor --type drop             # Only show dropped packets
cilium endpoint list                   # List Cilium endpoints
cilium policy get                      # Show loaded policies
cilium bpf ct list global              # Connection tracking table
cilium node list                       # Cluster nodes
cilium debuginfo                       # Full diagnostic dump
hubble observe --since 1m             # Recent network flows
```

## Pitfalls

- **kube-proxy replacement requires kernel 4.19+**: check kernel version before enabling `kubeProxyReplacement=true`; fallback to partial replacement if needed
- **L7 policies need Envoy**: CiliumNetworkPolicy with HTTP rules injects Envoy as a library (not a sidecar); this requires more CPU than L3/L4 rules
- **FQDN policies have caching**: DNS responses are cached; policies based on FQDN may not update immediately when an IP changes — increase `--tofqdns-min-ttl` to reduce stale IPs
- **Hubble data retention**: Hubble stores flows in a ring buffer in memory; it doesn't persist to disk by default — use Hubble Timescape or export to Prometheus/Loki for persistence
- **Upgrading Cilium**: always check the upgrade guide; eBPF programs need to be reloaded and nodes may need to be drained in some upgrade paths

## Related Skills

- `kubernetes-architect` — cluster networking design
- `falco` — runtime security (pair with Cilium for defense in depth)
- `service-mesh-istio` — alternative service mesh (Istio vs Cilium Service Mesh)
- `distributed-tracing` — complements Hubble observability

## GitNexus Index

Index path: /Users/localuser/.claude/skills/cilium/.gitnexus
Created: 2026-05-24
