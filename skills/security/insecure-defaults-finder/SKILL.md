# Insecure Defaults Finder

## Overview
Systematically identify weak configurations, hardcoded secrets, insecure default settings, and misconfigured security controls across a codebase and its infrastructure configuration.

## Trigger
Use when asked to find hardcoded secrets, check for insecure defaults, audit configuration security, detect weak cryptographic settings, or scan for credentials in code.

## Workflow

### 1. Secret and Credential Scanning
Search for hardcoded secrets using pattern matching:
```bash
# Use truffleHog or gitleaks
trufflehog filesystem <path> --json
gitleaks detect --source=<path> --report-format json

# Manual grep patterns
grep -rn "password\s*=\s*['\"]" .
grep -rn "api_key\s*=\s*['\"]" .
grep -rn "secret\s*=\s*['\"]" .
grep -rn "BEGIN.*PRIVATE KEY" .
grep -rn "AKIA[0-9A-Z]{16}" .  # AWS access keys
```

Common secret patterns to check:
- Passwords and API keys in source code
- Private keys and certificates checked into git
- Database connection strings with credentials
- OAuth tokens and service account keys
- JWT secrets and signing keys

### 2. Weak Cryptographic Defaults
- MD5 or SHA1 used for security-sensitive hashing
- ECB mode in block cipher usage
- Hard-coded IVs or salts
- Insufficient key lengths (< 2048-bit RSA, < 128-bit AES)
- `Math.random()` used for security purposes instead of CSPRNG
- Insecure TLS versions (TLS 1.0, 1.1) enabled

### 3. Authentication and Session Defaults
- Default or weak admin credentials
- Missing password complexity enforcement
- No account lockout or rate limiting
- Session tokens with insufficient entropy
- Missing `Secure` or `HttpOnly` cookie flags
- Sessions without expiration

### 4. Network and Server Configuration
Check for:
- Listening on `0.0.0.0` instead of specific interfaces
- Debug mode enabled in production configs
- CORS set to `*` (allow all origins)
- Missing HTTPS enforcement / HSTS headers
- Open ports and services not needed
- Default ports for admin interfaces

### 5. Framework and Library Defaults
Common insecure framework defaults:
- Django: `DEBUG=True`, default `SECRET_KEY`
- Express: Missing Helmet.js security headers
- Spring: Actuator endpoints exposed without auth
- Rails: `config.force_ssl = false`
- Flask: `TESTING=True` in production

### 6. Infrastructure as Code (IaC)
Scan Terraform, CloudFormation, Kubernetes manifests:
```bash
# Checkov for IaC scanning
checkov -d <path> --output json

# tfsec for Terraform
tfsec <terraform-dir> --format json
```

Flag:
- S3 buckets with public access
- Security groups with 0.0.0.0/0 ingress on sensitive ports
- Unencrypted storage (EBS, RDS, S3)
- IAM roles with `*` permissions
- Kubernetes pods running as root

### 7. Environment Variable Patterns
- Secrets passed as env vars without encryption at rest
- `.env` files committed to version control
- Missing `.gitignore` entries for config files

## Output
Report organized by category:
- **Critical**: Hardcoded credentials, exposed private keys
- **High**: Weak crypto, disabled security features
- **Medium**: Insecure defaults, missing hardening
- **Low**: Informational findings, best practice deviations

Each finding includes: location, evidence snippet (redacted), severity, and specific remediation steps.
