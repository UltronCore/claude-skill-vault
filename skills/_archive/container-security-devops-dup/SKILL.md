---
name: container-security
description: Harden Docker containers and Kubernetes workloads against common attack vectors. Covers image scanning with Trivy, distroless base images, non-root containers, seccomp/AppArmor profiles, Pod Security Standards, network policies, and supply chain security with SLSA.
version: 1.0.0
tags: [container-security, docker, kubernetes, trivy, seccomp, pod-security, network-policy, supply-chain, devops, security]
---

# Container Security

## Overview

Container security spans the entire lifecycle: build-time (base image selection, dependency scanning), runtime (seccomp profiles, non-root UIDs, read-only filesystems), and orchestration (Pod Security Standards, network policies, RBAC). The most common vulnerabilities come from overprivileged containers, unscanned images, and excessive network access — each addressable with standard tooling without sacrificing developer experience.

## When to Use

- Preparing for a security audit or SOC 2 certification that requires container hardening
- Images triggering vulnerability alerts in CI/CD pipelines (Trivy, Snyk, Grype)
- Running privileged containers or containers as root (highest-risk pattern)
- Microservices with no network segmentation (any pod can reach any other pod)
- Containers with access to host filesystem, PID namespace, or hostNetwork
- Integrating supply chain security checks into CI (SBOM, provenance attestation)

## Step-by-Step Workflow

### 1. Hardened Dockerfile

```dockerfile
# Multi-stage: build in full image, copy to minimal runtime
FROM python:3.12-slim AS builder
WORKDIR /app
COPY requirements.txt .
# Install to a local directory (not system Python)
RUN pip install --user --no-cache-dir -r requirements.txt

# Production stage: distroless or slim
FROM gcr.io/distroless/python3-debian12
# Alternative: python:3.12-slim with explicit hardening

WORKDIR /app

# Copy only the installed packages and app code
COPY --from=builder /root/.local /root/.local
COPY --chown=nonroot:nonroot src/ .

# Non-root user (distroless includes 'nonroot' UID 65532)
USER nonroot

# Immutable metadata
LABEL org.opencontainers.image.source="https://github.com/org/repo"
LABEL org.opencontainers.image.revision="${GIT_COMMIT}"

EXPOSE 8080
ENTRYPOINT ["python", "main.py"]
```

```dockerfile
# For Node.js — minimal attack surface
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force
COPY src/ ./src/

# Alpine-based with non-root user
FROM node:20-alpine
RUN addgroup -g 1001 -S appgroup && adduser -u 1001 -S appuser -G appgroup
WORKDIR /app
COPY --from=builder --chown=appuser:appgroup /app .
USER appuser

# Explicit port — no EXPOSE with 0 or wildcard
EXPOSE 3000
CMD ["node", "src/index.js"]
```

### 2. Trivy Image Scanning

```bash
# Install Trivy
brew install aquasecurity/trivy/trivy
# Or via Docker:
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy:latest image myapp:latest

# Scan local image — all severity levels
trivy image myapp:latest

# CI-ready: fail on CRITICAL and HIGH, exit code 1
trivy image --exit-code 1 --severity CRITICAL,HIGH myapp:latest

# Scan filesystem (code + deps before build)
trivy fs --scanners vuln,secret,misconfig .

# Generate SBOM (Software Bill of Materials)
trivy image --format cyclonedx --output sbom.json myapp:latest
trivy image --format spdx-json --output sbom.spdx.json myapp:latest

# Scan Kubernetes cluster
trivy k8s --report summary cluster

# Ignore specific CVEs with justification
cat > .trivyignore << 'EOF'
# CVE-2023-12345: Not exploitable — we don't call the affected code path
CVE-2023-12345
EOF
trivy image --ignorefile .trivyignore myapp:latest
```

```yaml
# .github/workflows/security.yml — scan in CI
name: Container Security
on: [push, pull_request]

jobs:
  trivy-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build image
        run: docker build -t myapp:${{ github.sha }} .

      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: myapp:${{ github.sha }}
          format: sarif
          output: trivy-results.sarif
          severity: CRITICAL,HIGH
          exit-code: "1"

      - name: Upload scan results to GitHub Security
        uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: trivy-results.sarif
```

### 3. Kubernetes Pod Security

```yaml
# Pod Security Standards — enforce at namespace level
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    # Enforce restricted policy (blocks privileged pods)
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/enforce-version: v1.28
    # Warn and audit on baseline violations
    pod-security.kubernetes.io/warn: baseline
    pod-security.kubernetes.io/audit: baseline
---
# Hardened Pod spec (passes 'restricted' policy)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-server
  namespace: production
spec:
  replicas: 3
  selector:
    matchLabels:
      app: api-server
  template:
    metadata:
      labels:
        app: api-server
    spec:
      # Service account with no extra permissions
      serviceAccountName: api-server-sa
      automountServiceAccountToken: false  # Disable if not needed

      # Pod-level security
      securityContext:
        runAsNonRoot: true
        runAsUser: 65534            # nobody
        runAsGroup: 65534
        fsGroup: 65534
        seccompProfile:
          type: RuntimeDefault      # Applies default seccomp filter

      containers:
        - name: api
          image: myapp:1.2.3@sha256:abc...  # Pin to digest, not tag
          ports:
            - containerPort: 8080
              protocol: TCP

          # Container-level security
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true   # No writes to container filesystem
            capabilities:
              drop: ["ALL"]               # Drop all Linux capabilities
              # add: ["NET_BIND_SERVICE"] # Only add what's needed

          # Writable volumes for temp files
          volumeMounts:
            - name: tmp
              mountPath: /tmp
            - name: cache
              mountPath: /app/cache

          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: 500m
              memory: 256Mi

      volumes:
        - name: tmp
          emptyDir:
            sizeLimit: 50Mi
        - name: cache
          emptyDir:
            sizeLimit: 100Mi
```

### 4. Network Policies (Zero-Trust)

```yaml
# Default deny all — then allow explicitly
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: production
spec:
  podSelector: {}      # Apply to ALL pods
  policyTypes:
    - Ingress
    - Egress
---
# Allow: api-server receives traffic from ingress controller only
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-ingress-to-api
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: api-server
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              name: ingress-nginx
          podSelector:
            matchLabels:
              app.kubernetes.io/name: ingress-nginx
      ports:
        - port: 8080
          protocol: TCP
  egress:
    # Allow DNS
    - ports:
        - port: 53
          protocol: UDP
    # Allow outbound to database namespace
    - to:
        - namespaceSelector:
            matchLabels:
              name: data
          podSelector:
            matchLabels:
              app: postgres
      ports:
        - port: 5432
    # Allow outbound HTTPS to external APIs
    - ports:
        - port: 443
```

### 5. Secrets Management (No Secrets in Images)

```yaml
# Use External Secrets Operator — pull from AWS SSM / Vault / GCP Secret Manager
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: api-secrets
  namespace: production
spec:
  refreshInterval: 5m
  secretStoreRef:
    name: aws-ssm-store
    kind: ClusterSecretStore
  target:
    name: api-secrets           # Creates this Kubernetes Secret
    creationPolicy: Owner
  data:
    - secretKey: DATABASE_URL
      remoteRef:
        key: /prod/api/database-url
    - secretKey: JWT_SECRET
      remoteRef:
        key: /prod/api/jwt-secret
```

## Key Commands Reference

```bash
# Trivy scanning
trivy image --severity CRITICAL,HIGH myapp:latest
trivy fs --scanners vuln,secret .          # Check for secrets in code too
trivy config k8s/                          # Misconfig scan of K8s manifests
trivy sbom sbom.json                       # Scan an existing SBOM

# Docker security inspection
docker inspect myapp:latest | jq '.[0].Config.User'
docker run --rm --security-opt no-new-privileges \
  --read-only --user 65534 myapp:latest

# Check running containers for security issues
docker ps --format "{{.Names}}" | xargs -I{} docker inspect {} \
  | jq '.[] | {name: .Name, user: .Config.User, privileged: .HostConfig.Privileged}'

# Kubernetes Pod Security
kubectl get pods -n production -o json | \
  jq '.items[] | {name: .metadata.name, user: .spec.securityContext.runAsUser}'

# Audit with kube-bench (CIS Kubernetes Benchmark)
kubectl apply -f https://raw.githubusercontent.com/aquasecurity/kube-bench/main/job.yaml
kubectl logs -l app=kube-bench

# Falco runtime security (detects anomalous behavior)
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm install falco falcosecurity/falco --namespace falco --create-namespace \
  --set falco.grpc.enabled=true --set falco.grpcOutput.enabled=true

# Check image provenance
cosign verify --certificate-identity-regexp ".*" \
  --certificate-oidc-issuer-regexp ".*" myapp:latest
```

## Common Patterns

### Pattern 1: Automated Secret Detection Pre-Commit

```bash
# Install gitleaks to scan for committed secrets
brew install gitleaks

# Scan repo history
gitleaks detect --source . --log-opts="HEAD~10..HEAD"

# Pre-commit hook
cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash
gitleaks protect --staged --redact
if [ $? -ne 0 ]; then
    echo "Secrets detected! Aborting commit."
    exit 1
fi
EOF
chmod +x .git/hooks/pre-commit
```

### Pattern 2: RBAC Least-Privilege ServiceAccount

```yaml
# Give each service only the permissions it needs
apiVersion: v1
kind: ServiceAccount
metadata:
  name: order-service-sa
  namespace: production
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: order-service-role
  namespace: production
rules:
  # Only read its own ConfigMap — nothing else
  - apiGroups: [""]
    resources: ["configmaps"]
    resourceNames: ["order-service-config"]
    verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: order-service-binding
  namespace: production
subjects:
  - kind: ServiceAccount
    name: order-service-sa
roleRef:
  kind: Role
  name: order-service-role
  apiGroup: rbac.authorization.k8s.io
```

### Pattern 3: OPA/Gatekeeper Policy Enforcement

```yaml
# Enforce no :latest tags in production
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: nolatesttag
spec:
  crd:
    spec:
      names:
        kind: NoLatestTag
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package nolatesttag
        violation[{"msg": msg}] {
          container := input.review.object.spec.containers[_]
          endswith(container.image, ":latest")
          msg := sprintf("Container %v uses :latest tag — pin to a digest", [container.name])
        }
---
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: NoLatestTag
metadata:
  name: no-latest-tag-prod
spec:
  match:
    namespaces: ["production"]
```

## Pitfalls to Avoid

1. **Running as root inside containers**: Even without `--privileged`, a root container can write to mounted volumes, read secrets from environment variables, and escalate via kernel exploits. Always set `runAsNonRoot: true` and a specific UID in the Pod security context. Use `USER` in Dockerfiles — many base images default to root.

2. **Pinning to mutable tags instead of digests**: `myapp:1.2.3` can be overwritten by anyone with registry access, creating a supply chain attack vector. In production manifests, always reference the immutable content digest: `myapp:1.2.3@sha256:abc123...`. Use Kyverno or OPA/Gatekeeper to enforce this policy cluster-wide.

3. **Not scanning Helm charts and K8s manifests for misconfigurations**: `trivy image` only catches CVEs in the image. Run `trivy config k8s/` or `trivy config helm/` to find security misconfigurations (missing resource limits, hostNetwork: true, etc.) before they reach the cluster. Add this to every CI pipeline.

## Related Skills

- `kubernetes-architect` — Cluster architecture, multi-tenancy, node security
- `api-security-hardening` — Application-level security controls
- `senior-devops` — Broader SRE practices including security runbooks
- `soc2-compliance` — SOC 2 requirements that container security addresses
- `security-hardening-checklist` — Full system hardening checklist

## GitNexus Index

```json
{
  "skill": "container-security",
  "category": "security",
  "triggers": ["container security", "docker hardening", "kubernetes security", "trivy scan", "pod security", "non-root container", "network policy", "seccomp", "distroless", "supply chain security", "SBOM", "image scanning"],
  "outputs": ["hardened Dockerfile", "trivy CI workflow", "Pod securityContext", "NetworkPolicy", "RBAC ServiceAccount", "OPA Gatekeeper ConstraintTemplate"],
  "complexity": "high",
  "tools": ["docker", "trivy", "kubernetes", "gatekeeper", "falco", "cosign", "kube-bench", "gitleaks"]
}
```
