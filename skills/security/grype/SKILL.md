---
name: grype
description: Scan containers and filesystems for known vulnerabilities with Grype — a fast, accurate vulnerability scanner for container images and filesystems from Anchore. Use this skill whenever the user wants to find CVEs in Docker images, scan dependency trees, integrate vulnerability scanning in CI/CD, or compare Grype vs Trivy. Trigger for "grype scan", "anchore grype", "container cve scan", or "grype docker image".

SAFETY NOTE: This skill covers ONLY defensive vulnerability detection on systems you own or have permission to scan.
---

# Grype: Container and Filesystem Vulnerability Scanner

Grype is a fast, accurate open-source vulnerability scanner from Anchore. It scans container images and filesystems against multiple vulnerability databases (NVD, RHSA, Debian, Ubuntu, Alpine, etc.) and integrates with Syft for SBOM-based scanning.

> **Defensive use only**: Only scan systems, images, and codebases you own or have explicit permission to scan.

## Installation

```bash
# macOS
brew install anchore/grype/grype

# Linux / macOS (installer script)
curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b /usr/local/bin

# Verify
grype version
```

## Basic Scanning

```bash
# Scan a container image
grype nginx:latest

# Scan your application image
grype my-app:1.0.0

# Scan only CRITICAL and HIGH vulnerabilities
grype nginx:latest --fail-on critical

# Scan a local Dockerfile context
grype dir:./my-project

# Scan a local filesystem path
grype dir:/path/to/project

# Scan a specific file (e.g., lockfile or SBOM)
grype file:package-lock.json
grype file:requirements.txt
grype file:sbom.syft.json
```

## Output Formats

```bash
# Table (default)
grype nginx:latest

# JSON (for CI processing)
grype nginx:latest -o json

# JSON with detailed info
grype nginx:latest -o json | jq '.matches[] | {name: .artifact.name, version: .artifact.version, cve: .vulnerability.id, severity: .vulnerability.severity}'

# SARIF (GitHub Security tab)
grype nginx:latest -o sarif > results.sarif

# Template (custom)
grype nginx:latest -o template -t "{{range .Matches}}{{.Vulnerability.ID}} {{.Artifact.Name}}\n{{end}}"

# Embedded SBOM as CycloneDX
grype nginx:latest -o cyclonedx
```

## CI/CD Integration

### GitHub Actions

```yaml
# .github/workflows/grype.yml
name: Vulnerability Scan
on: [push, pull_request]

jobs:
  grype-scan:
    runs-on: ubuntu-latest
    permissions:
      security-events: write
      contents: read

    steps:
      - uses: actions/checkout@v4

      - name: Build image
        run: docker build -t my-app:${{ github.sha }} .

      - name: Scan image with Grype
        uses: anchore/scan-action@v3
        id: scan
        with:
          image: 'my-app:${{ github.sha }}'
          fail-build: true
          severity-cutoff: high
          output-format: sarif

      - name: Upload SARIF to GitHub
        uses: github/codeql-action/upload-sarif@v3
        if: always()
        with:
          sarif_file: ${{ steps.scan.outputs.sarif }}

      - name: Scan filesystem
        uses: anchore/scan-action@v3
        with:
          path: '.'
          fail-build: false
          output-format: table
```

### Docker Compose / Makefile

```makefile
# Makefile
.PHONY: security-scan

security-scan:
	@echo "Scanning Docker image for vulnerabilities..."
	grype my-app:latest --fail-on high
	@echo "Scanning project dependencies..."
	grype dir:. --fail-on critical
	@echo "Security scan complete!"

# Run before pushing to registry
pre-push: build security-scan push
```

## Grype + Syft (SBOM-Based Scanning)

```bash
# First generate an SBOM with Syft
syft my-app:latest -o syft-json > sbom.syft.json

# Then scan the SBOM with Grype (no need to have the image locally)
grype sbom:sbom.syft.json

# This workflow separates SBOM generation from scanning:
# 1. Dev team generates SBOM at build time
# 2. Security team scans SBOM independently
# 3. SBOM can be stored alongside the artifact
```

## Configuration File

```yaml
# ~/.grype.yaml or .grype.yaml in project root

output: table
quiet: false
check-for-app-update: false

db:
  auto-update: true
  validate-by-hash-on-start: false

# Ignore specific CVEs or conditions
ignore:
  - vulnerability: CVE-2023-12345
    reason: "Not exploitable in our context — network not exposed"
    expires: "2024-06-01"
  
  - vulnerability: CVE-2023-99999
    package:
      name: libssl
      version: "1.1.1n"
    reason: "Vendor confirmed not affected"

# Fail the scan at this severity or above  
fail-on-severity: high
```

## Interpreting Results

```
NAME          INSTALLED  FIXED-IN  TYPE  VULNERABILITY  SEVERITY
openssl       1.1.1n     1.1.1t    deb   CVE-2023-0464  HIGH
libxml2       2.9.14     2.9.14+   deb   CVE-2022-40303 MEDIUM
curl          7.88.1     (none)    deb   CVE-2023-28321 MEDIUM
```

Key columns:
- **FIXED-IN**: If populated, update to this version to remediate
- **(none)** in FIXED-IN: No fix available yet — consider workarounds or accepting risk
- **TYPE**: Package ecosystem (deb, rpm, apk, python, npm, go, java, etc.)

## Remediation Workflow

```bash
# 1. Identify vulnerable packages
grype my-app:latest -o json | jq '[.matches[] | select(.vulnerability.severity == "Critical")]'

# 2. Check if fixes are available
grype my-app:latest -o json | jq '[.matches[] | {cve: .vulnerability.id, fixedIn: .vulnerability.fix.versions}]'

# 3. After updating, verify fix
docker build -t my-app:patched .
grype my-app:patched --fail-on critical

# 4. Track remediation over time
grype my-app:latest -o json > before.json
# ... apply fixes ...
grype my-app:patched -o json > after.json
diff <(jq '[.matches[].vulnerability.id]' before.json | sort) \
     <(jq '[.matches[].vulnerability.id]' after.json | sort)
```

## Grype vs Trivy Comparison

| Feature | Grype | Trivy |
|---|---|---|
| Container scanning | Excellent | Excellent |
| IaC scanning | No | Yes |
| Secret scanning | No | Yes |
| K8s cluster scanning | No | Yes |
| SBOM integration | Native (Syft) | Yes |
| Speed | Very fast | Fast |
| Database sources | NVD, distro-specific | NVD, distro, GitHub |
| Best for | Pure container/code CVE scanning | All-in-one scanning |

## GitNexus Index

This skill is indexed by GitNexus for knowledge graph traversal.
Index path: /Users/localuser/.claude/skills/grype/.gitnexus
Last indexed: 2026-05-24
