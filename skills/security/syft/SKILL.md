---
name: syft
description: Generate Software Bills of Materials (SBOMs) with Syft — a CLI tool and library from Anchore that catalogs all packages, libraries, and dependencies in container images and filesystems. Use this skill whenever the user needs to create an SBOM, comply with software supply chain requirements, or generate a CycloneDX/SPDX inventory of their application's dependencies. Trigger for "syft sbom", "software bill of materials", "sbom generation", "supply chain security", or "syft anchore".

SAFETY NOTE: This skill covers ONLY defensive supply chain security practices — inventorying your own software components for visibility and vulnerability tracking.
---

# Syft: SBOM Generation Tool

Syft (from Anchore) generates Software Bills of Materials (SBOMs) — comprehensive inventories of every package and library in your container image or codebase. SBOMs are the foundation of supply chain security: you can't protect what you can't see.

> **Defensive use only**: Generate SBOMs for your own software and supply chain. SBOM data should be treated as sensitive — share only with authorized parties.

## Installation

```bash
# macOS
brew install anchore/syft/syft

# Linux / macOS
curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin

# Verify
syft --version
```

## Generating SBOMs

### From Container Images

```bash
# Scan a container image (table output by default)
syft nginx:latest

# Generate SBOM in SPDX JSON format
syft nginx:latest -o spdx-json > sbom.spdx.json

# Generate SBOM in CycloneDX format
syft nginx:latest -o cyclonedx-json > sbom.cyclonedx.json
syft nginx:latest -o cyclonedx-xml > sbom.cyclonedx.xml

# Syft's native format (most detailed)
syft nginx:latest -o syft-json > sbom.syft.json

# GitHub's SBOM format (compatible with Dependency Graph)
syft nginx:latest -o github-json > sbom.github.json

# Multiple formats at once
syft nginx:latest \
  -o spdx-json=sbom.spdx.json \
  -o cyclonedx-json=sbom.cyclonedx.json
```

### From Filesystem / Source Code

```bash
# Scan a local directory
syft dir:./my-project

# Scan a specific path
syft dir:/path/to/project -o spdx-json > sbom.spdx.json

# Scan a tarball
syft file:./my-app.tar -o spdx-json > sbom.spdx.json

# Scan a git repository
syft dir:. -o syft-json > sbom.syft.json
```

### From Registries (Without Pulling)

```bash
# Scan without pulling the full image
syft registry:nginx:latest -o spdx-json > sbom.spdx.json

# From a private registry
syft registry:my-registry.example.com/my-app:1.0 \
  -o cyclonedx-json > sbom.cyclonedx.json
```

## SBOM Formats Explained

| Format | Use Case | Standard |
|---|---|---|
| `spdx-json` | Legal compliance, interoperability | SPDX (Linux Foundation) |
| `spdx-tag-value` | Human-readable SPDX | SPDX |
| `cyclonedx-json` | Security tools, Grype, OWASP | CycloneDX (OWASP) |
| `cyclonedx-xml` | Enterprise tools | CycloneDX |
| `syft-json` | Richest detail, Grype native | Anchore |
| `github-json` | GitHub Dependency Graph | GitHub |
| `table` | Human review | N/A |

## CI/CD Integration

### GitHub Actions

```yaml
# .github/workflows/sbom.yml
name: Generate SBOM
on:
  push:
    branches: [main]
  release:
    types: [published]

jobs:
  sbom:
    runs-on: ubuntu-latest
    permissions:
      contents: write
      packages: read

    steps:
      - uses: actions/checkout@v4

      - name: Build image
        run: docker build -t my-app:${{ github.sha }} .

      - name: Generate SBOM with Syft
        uses: anchore/sbom-action@v0
        with:
          image: 'my-app:${{ github.sha }}'
          format: 'spdx-json'
          output-file: 'sbom.spdx.json'

      - name: Attest SBOM to image (provenance)
        uses: anchore/sbom-action/publish-sbom@v0
        with:
          sbom-artifact-match: ".*\\.spdx.json$"

      - name: Upload SBOM as artifact
        uses: actions/upload-artifact@v4
        with:
          name: sbom
          path: sbom.spdx.json

      - name: Scan SBOM for vulnerabilities
        uses: anchore/scan-action@v3
        with:
          sbom: 'sbom.spdx.json'
          fail-build: true
          severity-cutoff: critical
```

### Attach SBOM to Docker Image (OCI Artifact)

```bash
# Generate SBOM
syft my-app:latest -o spdx-json > sbom.spdx.json

# Attach SBOM to image in registry using ORAS or cosign
cosign attach sbom --sbom sbom.spdx.json my-registry.example.com/my-app:latest

# Or use Docker BuildKit attestations
docker buildx build \
  --sbom=true \
  --provenance=true \
  -t my-registry.example.com/my-app:latest \
  --push .
```

## Analyzing SBOMs

```bash
# List all packages in an SBOM
cat sbom.spdx.json | jq '.packages[] | {name: .name, version: .versionInfo}'

# Count packages by ecosystem
cat sbom.syft.json | jq '[.artifacts[].type] | group_by(.) | map({type: .[0], count: length})'

# Find specific packages
cat sbom.spdx.json | jq '.packages[] | select(.name | test("openssl"))'

# Compare two SBOMs (find new packages between versions)
# New packages in v2 that weren't in v1
diff \
  <(cat sbom-v1.syft.json | jq -r '.artifacts[] | "\(.name) \(.version)"' | sort) \
  <(cat sbom-v2.syft.json | jq -r '.artifacts[] | "\(.name) \(.version)"' | sort)
```

## Feed SBOM to Grype for Vulnerability Scanning

```bash
# Generate SBOM
syft my-app:latest -o syft-json > sbom.syft.json

# Scan SBOM for vulnerabilities (no image needed)
grype sbom:sbom.syft.json

# This separation is useful for:
# - Scanning air-gapped environments
# - Scanning archived images
# - Running security scans in separate pipelines
# - Providing SBOMs to customers/auditors
```

## Configuration

```yaml
# .syft.yaml
output:
  - format: spdx-json
    file: sbom.spdx.json

# Include or exclude paths
catalogers:
  package:
    search:
      scope: all-layers  # all-layers or squashed

log:
  level: warn

# Exclude dev dependencies
package:
  cataloger:
    enabled: true
  search:
    exclude-binary-overlap-by-ownership: false
```

## SBOM Compliance Use Cases

1. **US Executive Order 14028** (2021): Federal software must have SBOMs
2. **NTIA Minimum Elements**: Name, version, supplier, dependencies, timestamp, author, SBOM format
3. **SOC2 / ISO 27001**: Demonstrate software supply chain controls
4. **Customer requirements**: Enterprise customers increasingly require SBOMs with software deliverables
5. **Incident response**: When a new CVE drops, quickly determine which images are affected

## Syft + Grype + Cosign Workflow

```bash
# Complete supply chain security workflow:

# 1. Build image
docker build -t my-app:1.0 .

# 2. Generate SBOM
syft my-app:1.0 -o spdx-json > sbom.spdx.json

# 3. Scan for vulnerabilities
grype sbom:sbom.spdx.json --fail-on critical

# 4. Sign the image
cosign sign --key cosign.key my-registry.example.com/my-app:1.0

# 5. Attach and sign SBOM
cosign attach sbom --sbom sbom.spdx.json my-registry.example.com/my-app:1.0
cosign sign --key cosign.key --attachment sbom my-registry.example.com/my-app:1.0

# 6. Verify (downstream consumers)
cosign verify --key cosign.pub my-registry.example.com/my-app:1.0
```

## GitNexus Index

This skill is indexed by GitNexus for knowledge graph traversal.
Index path: /Users/localuser/.claude/skills/syft/.gitnexus
Last indexed: 2026-05-24
