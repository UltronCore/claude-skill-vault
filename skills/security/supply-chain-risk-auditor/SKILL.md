# Supply Chain Risk Auditor

## Overview
Systematically audit the supply-chain threat landscape of a project's dependencies. Identify typosquatting, dependency confusion, abandoned packages, known CVEs, malicious packages, and excessive permission scopes.

## Trigger
Use when asked to audit dependencies for supply chain risk, check for malicious packages, review third-party library security, or perform a software composition analysis (SCA).

## Workflow

### 1. Enumerate Dependencies
Collect full dependency tree including transitive deps:
```bash
# Node.js
npm ls --all --json > deps.json
npm audit --json > audit.json

# Python
pip-audit --output json > pip-audit.json
pip list --format=json > installed.json

# Go
go list -m -json all > go-deps.json
govulncheck ./... > vuln.txt

# Rust
cargo audit --json > cargo-audit.json

# Java/Maven
mvn dependency:tree -DoutputType=dot > tree.dot
```

### 2. Known Vulnerability Scan
- Run `npm audit` / `pip-audit` / `cargo audit` / `govulncheck`
- Cross-reference with OSV (osv.dev), NVD, and GitHub Advisory Database
- Flag: Critical and High CVEs in direct and transitive dependencies

### 3. Package Health Assessment
For each direct dependency, evaluate:
- **Maintenance**: Last commit date, open issues, release cadence
- **Popularity**: Download count, GitHub stars (low = higher risk)
- **Ownership**: Single maintainer vs. org-backed
- **Bus factor**: How many active contributors

### 4. Typosquatting and Name Confusion
Check for:
- Packages with names similar to popular packages (e.g., `reqeusts` vs `requests`)
- Dependency confusion attacks: internal package names that exist on public registries
- Homoglyph attacks in package names

```bash
# Check for typosquatting candidates
npm search <package-name>
```

### 5. Malicious Package Indicators
Red flags to look for:
- Preinstall/postinstall scripts that run shell commands
- Packages that fetch remote code at install or runtime
- Obfuscated code in published package vs. source repo
- Mismatch between published npm/pypi code and GitHub source
- Recently published packages with high version numbers

### 6. License Risk
- Identify GPL/AGPL licenses that may require open-sourcing your code
- Flag unknown or custom licenses
- Check for license compatibility conflicts

### 7. Permissions and Access Scope
- Review packages with broad filesystem, network, or process access
- Flag packages using `eval()`, `exec()`, dynamic requires
- Identify packages making outbound network calls

### 8. Remediation Priorities
Rank findings by:
1. Exploitable CVE in directly-used package
2. Malicious package indicators
3. Abandoned package with no maintainer
4. High CVE in transitive dependency
5. License compliance issue

## Output
Structured report with:
- Executive summary of risk posture
- Critical/High CVE table with fix versions
- Abandoned/unmaintained package list
- Suspicious package flags with evidence
- Recommended dependency pinning and lockfile strategies
- Suggested replacements for high-risk dependencies

## GitNexus Index
This skill is indexed by GitNexus for knowledge graph traversal.
Index path: /Users/localuser/claude-skill-vault/skills/security/supply-chain-risk-auditor/.gitnexus
Last indexed: 2026-05-23
