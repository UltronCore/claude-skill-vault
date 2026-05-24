---
name: trivy
description: Scan containers, code, and infrastructure for vulnerabilities using Trivy — a comprehensive, fast security scanner for container images, filesystems, git repos, Kubernetes, and IaC. Use this skill whenever the user wants to scan Docker images for CVEs, check code dependencies for vulnerabilities, or integrate security scanning into CI/CD pipelines. Trigger for "trivy scan", "container vulnerability scan", "trivy docker", or "trivy ci".

SAFETY NOTE: This skill covers ONLY defensive vulnerability detection and remediation. All techniques are for protecting your own systems.
---

# Trivy: Comprehensive Security Scanner

Trivy is an open-source security scanner that detects vulnerabilities in container images, filesystems, git repos, Kubernetes clusters, and Infrastructure as Code. It is one of the most widely used tools in defensive security workflows.

> **Defensive use only**: All scanning must target your own systems, images you own or have permission to scan, and your own code repositories.

## Installation

```bash
# macOS
brew install aquasecurity/trivy/trivy

# Linux
apt-get install trivy
# or
curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin

# Docker
docker pull aquasec/trivy
```

## Scanning Container Images

```bash
# Scan a Docker image for CVEs
trivy image nginx:latest

# Scan your own application image
trivy image my-app:1.0.0

# Scan with specific severity filter (show only HIGH and CRITICAL)
trivy image --severity HIGH,CRITICAL nginx:latest

# Scan and output as JSON for CI parsing
trivy image --format json --output results.json nginx:latest

# Scan and fail CI if vulnerabilities found above threshold
trivy image --exit-code 1 --severity CRITICAL nginx:latest

# Scan a local tarball (exported with docker save)
trivy image --input my-app.tar

# Scan from a private registry
trivy image --username $REGISTRY_USER --password $REGISTRY_PASSWORD \
  my-registry.example.com/my-app:latest
```

## Scanning Code and Dependencies

```bash
# Scan a local filesystem (finds dependency manifests)
trivy fs .

# Scan a git repository
trivy repo https://github.com/my-org/my-app

# Scan for secrets in your codebase
trivy fs --scanners secret .

# Scan for misconfigurations (IaC issues) in your code
trivy fs --scanners misconfig .

# Scan everything at once
trivy fs --scanners vuln,secret,misconfig .

# Scan only specific file types
trivy fs --include-dev-deps --file-patterns "**/*.py" .
```

## IaC Scanning

```bash
# Scan Terraform files
trivy config ./terraform/

# Scan Kubernetes manifests
trivy config ./k8s/

# Scan Helm charts
trivy config ./helm/my-chart/

# Scan CloudFormation templates
trivy config ./cloudformation/

# Scan Dockerfile
trivy config ./Dockerfile

# Show all findings including passed checks
trivy config --include-non-failures ./terraform/
```

## Kubernetes Cluster Scanning

```bash
# Scan your current Kubernetes cluster
trivy k8s --report all cluster

# Scan a specific namespace
trivy k8s --namespace production cluster

# Scan a specific workload
trivy k8s deployment/my-app

# Export cluster report
trivy k8s --format json --output k8s-report.json cluster

# Check for compliance issues (NSA, CIS)
trivy k8s --compliance k8s-nsa-1.0 cluster
trivy k8s --compliance k8s-cis-1.23 cluster
```

## SBOM Generation and Scanning

```bash
# Generate SBOM from an image
trivy image --format spdx-json --output sbom.spdx.json my-app:latest
trivy image --format cyclonedx --output sbom.cyclonedx.json my-app:latest

# Scan an existing SBOM for vulnerabilities
trivy sbom ./sbom.spdx.json
```

## CI/CD Integration

### GitHub Actions

```yaml
# .github/workflows/security.yml
name: Security Scan
on: [push, pull_request]

jobs:
  trivy-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build Docker image
        run: docker build -t my-app:${{ github.sha }} .

      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: 'my-app:${{ github.sha }}'
          format: 'sarif'
          output: 'trivy-results.sarif'
          severity: 'CRITICAL,HIGH'
          exit-code: '1'

      - name: Upload Trivy scan results to GitHub Security tab
        uses: github/codeql-action/upload-sarif@v3
        if: always()
        with:
          sarif_file: 'trivy-results.sarif'

      - name: Scan repository code
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          scan-ref: '.'
          scanners: 'vuln,secret,misconfig'
          format: 'table'
```

### GitLab CI

```yaml
# .gitlab-ci.yml
trivy-container-scan:
  image: docker:stable
  services:
    - docker:dind
  variables:
    IMAGE: $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA
  before_script:
    - apk add --no-cache curl
    - curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin
  script:
    - docker build -t $IMAGE .
    - trivy image --exit-code 1 --severity CRITICAL $IMAGE
  allow_failure: false
```

## Output Formats

```bash
# Table (default — human readable)
trivy image my-app:latest

# JSON (machine parseable)
trivy image --format json my-app:latest

# SARIF (GitHub/GitLab security tab integration)
trivy image --format sarif my-app:latest

# SPDX (SBOM format)
trivy image --format spdx-json my-app:latest

# CycloneDX (SBOM format)
trivy image --format cyclonedx my-app:latest

# Template (custom output)
trivy image --format template --template "@contrib/html.tpl" my-app:latest
```

## Configuration File

```yaml
# trivy.yaml (project root or ~/.trivy/trivy.yaml)
format: table
severity:
  - CRITICAL
  - HIGH
scan:
  scanners:
    - vuln
    - secret
    - misconfig
image:
  removed-pkgs: true
vulnerability:
  ignore-unfixed: true   # skip vulnerabilities with no fix available
secret:
  config: trivy-secret.yaml
```

## Ignore Known False Positives

```yaml
# .trivyignore (gitignore format)
# Ignore a specific CVE
CVE-2023-12345

# Ignore CVEs by package
CVE-2023-99999 libssl

# Ignore by image/path  
# trivy:ignore:CVE-2023-12345
```

## Common Remediation Patterns

After finding vulnerabilities:
1. Update base image to a patched version (`FROM node:20-alpine` → check for newer)
2. Update specific packages in Dockerfile: `RUN apk upgrade --no-cache`
3. Use distroless or minimal base images to reduce attack surface
4. Remove unnecessary packages: prefer `alpine` over `ubuntu` base
5. Use multi-stage builds to exclude build tools from final image

## GitNexus Index

This skill is indexed by GitNexus for knowledge graph traversal.
Index path: /Users/localuser/.claude/skills/trivy/.gitnexus
Last indexed: 2026-05-24
