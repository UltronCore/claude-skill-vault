---
name: nuclei
description: Run automated vulnerability detection on your own web apps and infrastructure using Nuclei — a fast, template-based vulnerability scanner for defensive security assessments. Use this skill when the user needs to scan their own web applications for known vulnerabilities, misconfigurations, or CVEs using Nuclei templates. All use is strictly for systems you own or have explicit written authorization to test.

SAFETY NOTE: This skill covers ONLY authorized defensive security scanning of systems you own or have written permission to test. Never use Nuclei against systems you do not own or have explicit authorization to test. Unauthorized scanning is illegal.
---

# Nuclei: Template-Based Vulnerability Scanner

Nuclei is an open-source, template-driven vulnerability scanner. Security teams use it to detect known vulnerabilities, misconfigurations, and exposed services in their own infrastructure using community-maintained and custom templates.

> **IMPORTANT — Authorized use only**: Only scan systems you own or have explicit written authorization to test. Unauthorized scanning is illegal under the Computer Fraud and Abuse Act (US), Computer Misuse Act (UK), and equivalent laws in virtually every jurisdiction. Always get written permission before scanning any system.

## Installation

```bash
# macOS
brew install nuclei

# Linux / macOS (Go install)
go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest

# Verify and update templates
nuclei -update-templates
```

## Basic Usage (Your Own Systems Only)

```bash
# Scan your own domain — basic checks
nuclei -u https://your-app.example.com

# Scan only specific severity levels
nuclei -u https://your-app.example.com -severity critical,high

# Scan with specific template tags
nuclei -u https://your-app.example.com -tags cve,misconfig

# Dry run — see what would run without executing
nuclei -u https://your-app.example.com -dry-run

# Output to file
nuclei -u https://your-app.example.com -o nuclei-results.txt -severity high,critical
nuclei -u https://your-app.example.com -jsonl -o results.jsonl
```

## Template Categories

```bash
# List all available templates
nuclei -list-templates

# Scan only CVE templates
nuclei -u https://your-app.com -tags cve

# Scan for misconfigurations
nuclei -u https://your-app.com -tags misconfig

# Scan for exposed panels (admin, login pages)
nuclei -u https://your-app.com -tags panel

# Scan for exposed sensitive files
nuclei -u https://your-app.com -tags exposure

# Scan for default credentials (on your own systems)
nuclei -u https://your-app.com -tags default-logins

# Check for outdated software versions
nuclei -u https://your-app.com -tags tech -severity info

# SSL/TLS issues
nuclei -u https://your-app.com -tags ssl

# Cloud misconfiguration checks
nuclei -u https://your-app.com -tags cloud,aws,azure,gcp
```

## Scanning Multiple Targets (Your Own Infrastructure)

```bash
# Scan a list of your own URLs
nuclei -list my-targets.txt -severity high,critical

# my-targets.txt (your own systems only)
# https://api.mycompany.com
# https://staging.mycompany.com
# https://admin.internal.mycompany.com

# Scan an IP range (your own network)
nuclei -u 192.168.1.0/24 -tags network

# Scan from nmap output (authorized scans)
nmap -oX scan.xml 192.168.1.0/24
nuclei -nmap scan.xml
```

## Writing Custom Templates (Defensive Use)

```yaml
# Custom template: check for your own debug endpoint being exposed
# ~/.nuclei-templates/custom/debug-endpoint.yaml
id: internal-debug-endpoint-exposed

info:
  name: Debug Endpoint Exposed
  author: your-name
  severity: high
  description: Internal debug endpoint is publicly accessible
  tags: misconfig,exposure,custom

requests:
  - method: GET
    path:
      - "{{BaseURL}}/debug"
      - "{{BaseURL}}/_debug"
      - "{{BaseURL}}/actuator"
      - "{{BaseURL}}/actuator/env"

    matchers-condition: or
    matchers:
      - type: word
        words:
          - "environment"
          - "application.properties"
          - "classpath"
        condition: and
        part: body

      - type: status
        status:
          - 200
        
      - type: word
        words:
          - "DEBUG"
          - "TRACE"
        part: body
```

```yaml
# Custom template: check for sensitive headers leaking info
id: server-version-disclosure

info:
  name: Server Version Disclosure
  author: your-team
  severity: info
  description: Server is disclosing software version in response headers
  tags: misconfig,info-disclosure,custom

requests:
  - method: GET
    path:
      - "{{BaseURL}}/"
    
    matchers-condition: or
    matchers:
      - type: regex
        part: header
        regex:
          - 'Server: Apache/[0-9]'
          - 'Server: nginx/[0-9]'
          - 'X-Powered-By: PHP/[0-9]'
          - 'X-AspNet-Version: [0-9]'
```

## CI/CD Integration (Pre-Production Scanning)

```yaml
# .github/workflows/security-scan.yml
# Only runs against staging — not production without approval
name: Security Scan (Staging)
on:
  pull_request:
    branches: [main]

jobs:
  nuclei-scan:
    runs-on: ubuntu-latest
    # Only scan staging environment
    environment: staging

    steps:
      - name: Install Nuclei
        run: |
          go install github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest
          nuclei -update-templates

      - name: Scan staging environment
        env:
          STAGING_URL: ${{ vars.STAGING_URL }}  # Your own staging URL
        run: |
          nuclei \
            -u "$STAGING_URL" \
            -severity high,critical \
            -tags cve,misconfig,exposure \
            -o nuclei-results.jsonl \
            -jsonl \
            -silent

      - name: Parse results
        run: |
          CRITICAL=$(jq -r 'select(.info.severity == "critical")' nuclei-results.jsonl | wc -l)
          echo "Critical findings: $CRITICAL"
          if [ "$CRITICAL" -gt 0 ]; then
            echo "::error::$CRITICAL critical vulnerabilities found!"
            cat nuclei-results.jsonl | jq -r '.info.name + " - " + .matched-at'
            exit 1
          fi

      - name: Upload results
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: nuclei-scan-results
          path: nuclei-results.jsonl
```

## Template Filtering and Rate Limiting

```bash
# Limit rate to avoid overloading your own servers
nuclei -u https://your-app.com -rate-limit 10 -bulk-size 5

# Skip certain templates that cause noise in your environment
nuclei -u https://your-app.com \
  -exclude-tags intrusive \
  -exclude-tags dos         # never run denial-of-service tests in CI
  
# Target specific template IDs
nuclei -u https://your-app.com -id CVE-2021-44228  # Log4Shell check on your systems

# Run only templates updated recently (fresh CVEs)
nuclei -u https://your-app.com -new-templates

# Test a single template against your app
nuclei -u https://your-app.com -t http/cves/2021/CVE-2021-44228.yaml
```

## Interpreting Results

```
[critical] [http] [CVE-2021-44228] https://your-app.com/api/login
├── Name: Apache Log4j RCE
├── Matched: {{jndi:ldap://...}} in User-Agent header
└── Description: Remote code execution via JNDI injection

[high] [http] [exposed-panel] https://your-app.com/admin
├── Name: Jenkins Admin Panel Exposed
├── Matched: "Jenkins" in response body
└── Remediation: Restrict access to admin panel via IP allowlist
```

For each finding:
1. Note the CVE or template ID
2. Check the remediation guidance in the template
3. Verify manually — some findings are false positives
4. Patch or mitigate before deploying to production
5. Re-scan to confirm remediation

## Legal and Ethical Requirements

Before scanning ANY system:
1. Get **written** authorization from the system owner
2. Define the **scope** — exactly which URLs/IPs are in scope
3. Set a **time window** for the scan
4. Agree on **notification process** if critical issues found
5. Agree on **remediation timeline**

Nuclei should ONLY be used as part of an authorized penetration test, bug bounty program (within scope), or your own CI/CD pipeline against systems you operate.

## GitNexus Index

This skill is indexed by GitNexus for knowledge graph traversal.
Index path: /Users/localuser/.claude/skills/nuclei/.gitnexus
Last indexed: 2026-05-24
