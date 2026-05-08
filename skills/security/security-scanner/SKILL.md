---
name: security-scanner
description: Route security scanning tasks to the right tool — containers, secrets, SAST, SBOM, web apps
type: tool-routing
repos_absorbed: [trivy, gitleaks, trufflehog, semgrep, grype, gosec, snyk-cli, owasp-zap]
---

# Security Scanner

Routes security scanning tasks to the correct tool based on scan target and goal.

## Routing Table

| Target | Goal | Tool | API Required |
|--------|------|------|-------------|
| Container image / Dockerfile | CVE vulnerability scan | trivy | No |
| Git repo / file history | Find committed secrets | gitleaks | No |
| Git repo / live secrets | Detect + validate live secrets | trufflehog | No |
| Source code | SAST / custom rules | semgrep | No |
| SBOM / binary / image | Vulnerability matching | grype (+ syft) | No |
| Go source code | Security audit | gosec | No |
| Running web app | DAST / active scan | owasp-zap | No |
| Any target (SaaS) | CI-integrated scan + fix | snyk | SNYK_TOKEN |

## Tool Commands

### trivy — Container & Filesystem CVE Scanning
```bash
# Install
brew install trivy

# Scan container image
trivy image nginx:latest

# Scan local filesystem
trivy fs /path/to/project

# Scan IaC (Terraform, k8s)
trivy config /path/to/iac

# JSON output
trivy image --format json --output results.json nginx:latest

# Fail on HIGH+ severity
trivy image --exit-code 1 --severity HIGH,CRITICAL nginx:latest
```

### gitleaks — Git History Secret Scanning
```bash
# Install
brew install gitleaks

# Scan current repo
gitleaks detect --source . --report-format json --report-path gitleaks-report.json

# Scan specific branch
gitleaks detect --source . --log-opts "main..HEAD"

# Pre-commit hook
gitleaks protect --staged
```

### trufflehog — Secret Detection + Validation
```bash
# Install
brew install trufflehog

# Scan GitHub repo
trufflehog github --repo https://github.com/org/repo

# Scan local filesystem
trufflehog filesystem /path/to/project --only-verified

# Scan git history (only verified live secrets)
trufflehog git file://. --only-verified --json
```

### semgrep — SAST / Custom Rules
```bash
# Install
pip install semgrep

# Auto-detect language and use community rules
semgrep --config=auto /path/to/code

# Security-focused ruleset
semgrep --config=p/security-audit /path/to/code

# Specific language
semgrep --config=p/python /path/to/code

# Custom rule file
semgrep --config=rules.yml /path/to/code

# JSON output
semgrep --config=auto --json -o results.json /path/to/code
```

### grype — SBOM-Based Vulnerability Scanning
```bash
# Install
brew install grype

# Also install syft for SBOM generation
brew install syft

# Scan container image
grype nginx:latest

# Scan from SBOM
syft nginx:latest -o syft-json > sbom.json
grype sbom:sbom.json

# Scan local directory
grype dir:/path/to/project

# Only show HIGH+
grype nginx:latest --fail-on high
```

### gosec — Go Security Audit
```bash
# Install
go install github.com/securego/gosec/v2/cmd/gosec@latest

# Scan Go project
gosec ./...

# JSON output
gosec -fmt json -out results.json ./...

# Specific rule categories
gosec -include=G101,G401 ./...

# Exclude test files
gosec -exclude-dir=vendor ./...
```

### owasp-zap — DAST Web App Scanning
```bash
# Docker (recommended)
docker pull ghcr.io/zaproxy/zaproxy:stable

# Baseline scan (passive)
docker run -t ghcr.io/zaproxy/zaproxy:stable zap-baseline.py \
  -t https://target-app.example.com -r report.html

# Full scan (active)
docker run -t ghcr.io/zaproxy/zaproxy:stable zap-full-scan.py \
  -t https://target-app.example.com -r report.html

# API scan (OpenAPI/Swagger)
docker run -t ghcr.io/zaproxy/zaproxy:stable zap-api-scan.py \
  -t https://target-app.example.com/openapi.json -f openapi -r report.html
```

### snyk — SaaS-Integrated Scanning
```bash
# Install
brew install snyk
# or
npm install -g snyk

# Auth (requires SNYK_TOKEN or interactive login)
snyk auth $SNYK_TOKEN

# Scan dependencies
snyk test

# Scan container
snyk container test nginx:latest

# Scan IaC
snyk iac test /path/to/terraform/

# Monitor (report to Snyk dashboard)
snyk monitor
```

## Decision Guide

**"Scan my Docker image for CVEs"** → trivy image
**"Did we ever commit a secret?"** → gitleaks detect
**"Do we have live AWS keys anywhere?"** → trufflehog --only-verified
**"Find SQL injection in our Python code"** → semgrep --config=p/python
**"Scan our Go service for security issues"** → gosec ./...
**"Test our running API for vulnerabilities"** → owasp-zap zap-api-scan.py
**"Full SaaS-managed scanning with fix suggestions"** → snyk (requires account)

## Output Interpretation

- **trivy / grype**: CVE IDs, severity (CRITICAL/HIGH/MEDIUM/LOW), fixed-in version
- **gitleaks / trufflehog**: File path, line number, secret type, commit hash
- **semgrep**: Rule ID, message, file, line, fix suggestion
- **gosec**: CWE ID, severity, confidence, file, line
- **owasp-zap**: OWASP category, risk level, evidence, solution

## CI Integration Notes

All tools support `--exit-code 1` or equivalent to fail pipelines on findings.
Trivy, semgrep, and snyk have native GitHub Actions integrations.
Gitleaks has a pre-commit hook mode (`gitleaks protect --staged`).
