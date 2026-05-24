---
name: checkov
description: Scan Infrastructure as Code for security misconfigurations with Checkov — a static analysis tool that checks Terraform, CloudFormation, Kubernetes, Helm, ARM, Bicep, Serverless, and Dockerfile for security issues before deployment. Use this skill whenever the user wants to audit IaC for security issues, add security scanning to Terraform pipelines, or check Kubernetes manifests against security best practices. Trigger for "checkov scan", "iac security", "terraform security scan", "checkov terraform", or "checkov kubernetes".

SAFETY NOTE: Checkov is a purely defensive static analysis tool for scanning your own IaC configurations.
---

# Checkov: Infrastructure as Code Security Scanner

Checkov is an open-source static analysis tool for Infrastructure as Code (IaC). It finds security misconfigurations in Terraform, CloudFormation, Kubernetes, Helm, ARM, Bicep, Serverless, and Dockerfiles — before they reach production.

## Installation

```bash
pip install checkov

# Or via pipx
pipx install checkov

# Or via Docker
docker pull bridgecrew/checkov
```

## Basic Usage

```bash
# Scan a Terraform directory
checkov -d ./terraform/

# Scan a specific file
checkov -f main.tf

# Scan Kubernetes manifests
checkov -d ./k8s/ --framework kubernetes

# Scan a Dockerfile
checkov -f Dockerfile --framework dockerfile

# Scan CloudFormation
checkov -f template.yaml --framework cloudformation

# Scan with specific output format
checkov -d ./terraform/ -o json
checkov -d ./terraform/ -o sarif --output-file-path checkov-results.sarif
checkov -d ./terraform/ -o table  # default
```

## Terraform Scanning

```bash
# Scan Terraform plan (more accurate than source)
terraform plan -out=plan.tfplan
terraform show -json plan.tfplan > plan.json
checkov -f plan.json --framework terraform_plan

# Scan Terraform source
checkov -d ./terraform/ --framework terraform

# Skip specific checks
checkov -d ./terraform/ --skip-check CKV_AWS_20,CKV_AWS_57

# Only run specific checks
checkov -d ./terraform/ --check CKV_AWS_3,CKV_AWS_21

# Set severity threshold
checkov -d ./terraform/ --check-threshold HIGH
```

## Common Terraform Issues Checkov Catches

### S3 Buckets

```hcl
# BAD — Checkov CKV_AWS_20: S3 bucket should not be publicly readable
resource "aws_s3_bucket" "data" {
  bucket = "my-data-bucket"
  acl    = "public-read"  # CKV_AWS_20: FAIL
}

# GOOD
resource "aws_s3_bucket" "data" {
  bucket = "my-data-bucket"
}
resource "aws_s3_bucket_acl" "data" {
  bucket = aws_s3_bucket.data.id
  acl    = "private"
}
resource "aws_s3_bucket_versioning" "data" {
  bucket = aws_s3_bucket.data.id
  versioning_configuration { status = "Enabled" }  # CKV_AWS_21
}
resource "aws_s3_bucket_server_side_encryption_configuration" "data" {
  bucket = aws_s3_bucket.data.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }  # CKV_AWS_19
  }
}
```

### Security Groups

```hcl
# BAD — CKV_AWS_25: Open to world
resource "aws_security_group_rule" "ssh" {
  type        = "ingress"
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]  # CKV_AWS_25: FAIL
}

# GOOD — restrict to known CIDR
resource "aws_security_group_rule" "ssh" {
  type        = "ingress"
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = ["10.0.0.0/8"]  # VPC CIDR only
}
```

### IAM Policies

```hcl
# BAD — CKV_AWS_40: IAM policy with wildcard permissions
resource "aws_iam_policy" "bad" {
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "*"   # CKV_AWS_40: FAIL
      Resource = "*"
    }]
  })
}

# GOOD — least privilege
resource "aws_iam_policy" "good" {
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject", "s3:PutObject"]
      Resource = "arn:aws:s3:::my-bucket/*"
    }]
  })
}
```

## Kubernetes Manifest Scanning

```bash
# Scan all Kubernetes manifests
checkov -d ./k8s/ --framework kubernetes

# Scan a Helm chart
checkov -d ./helm/my-chart/ --framework helm
```

Common Kubernetes issues:

```yaml
# BAD — CKV_K8S_14: no resource limits set
apiVersion: v1
kind: Pod
spec:
  containers:
    - name: app
      image: my-app:latest
      # No resources defined — CKV_K8S_11, CKV_K8S_12, CKV_K8S_14: FAIL

# GOOD
spec:
  containers:
    - name: app
      image: my-app:1.2.3  # CKV_K8S_15: avoid latest tag
      resources:
        requests:
          memory: "128Mi"
          cpu: "100m"
        limits:
          memory: "256Mi"
          cpu: "500m"
      securityContext:
        allowPrivilegeEscalation: false   # CKV_K8S_20
        readOnlyRootFilesystem: true       # CKV_K8S_22
        runAsNonRoot: true                 # CKV_K8S_6
        runAsUser: 1000
        capabilities:
          drop: ["ALL"]                    # CKV_K8S_28
```

## Dockerfile Scanning

```dockerfile
# BAD — CKV_DOCKER_2: no HEALTHCHECK
FROM ubuntu:latest          # CKV_DOCKER_7: use specific tag
RUN apt-get install -y curl  # OK

# GOOD
FROM ubuntu:22.04

HEALTHCHECK --interval=30s --timeout=5s \  # CKV_DOCKER_2
  CMD curl -f http://localhost:8080/health || exit 1

# CKV_DOCKER_3: Avoid running as root
RUN groupadd -r appgroup && useradd -r -g appgroup appuser
USER appuser

# CKV_DOCKER_4: Don't add secrets as environment variables
# ENV SECRET_KEY=hardcoded_value  # FAIL

COPY --chown=appuser:appgroup . /app
WORKDIR /app
```

## CI/CD Integration

### GitHub Actions

```yaml
# .github/workflows/checkov.yml
name: IaC Security Scan
on: [push, pull_request]

jobs:
  checkov:
    runs-on: ubuntu-latest
    permissions:
      security-events: write

    steps:
      - uses: actions/checkout@v4

      - name: Run Checkov on Terraform
        uses: bridgecrewio/checkov-action@master
        with:
          directory: terraform/
          framework: terraform
          output_format: sarif
          output_file_path: checkov-results.sarif
          soft_fail: false          # fail CI on issues
          check: "HIGH,CRITICAL"    # only high and critical

      - name: Upload to GitHub Security
        uses: github/codeql-action/upload-sarif@v3
        if: always()
        with:
          sarif_file: checkov-results.sarif

      - name: Run Checkov on Kubernetes
        uses: bridgecrewio/checkov-action@master
        with:
          directory: k8s/
          framework: kubernetes
          soft_fail: true           # warn only for K8s
```

### Pre-commit Hook

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/bridgecrewio/checkov
    rev: '3.2.0'
    hooks:
      - id: checkov
        args: ['--framework', 'terraform', '--quiet']
```

## Custom Checks (Python)

```python
# custom_checks/enforce_tagging.py
from checkov.common.models.enums import CheckCategories, CheckResult
from checkov.terraform.checks.resource.base_resource_check import BaseResourceCheck

class EnsureRequiredTags(BaseResourceCheck):
    def __init__(self):
        name = "Ensure all resources have required tags"
        id = "CKV_CUSTOM_1"
        supported_resources = ['aws_instance', 'aws_s3_bucket', 'aws_rds_instance']
        categories = [CheckCategories.GENERAL_SECURITY]
        super().__init__(name=name, id=id, categories=categories,
                         supported_resources=supported_resources)

    def scan_resource_conf(self, conf):
        required_tags = {"Owner", "Environment", "Project"}
        tags = conf.get("tags", [{}])
        if isinstance(tags, list):
            tags = tags[0]
        if isinstance(tags, dict):
            present = set(tags.keys())
            if required_tags.issubset(present):
                return CheckResult.PASSED
        return CheckResult.FAILED

scanner = EnsureRequiredTags()
```

```bash
# Run with custom checks
checkov -d ./terraform/ --external-checks-dir ./custom_checks/
```

## Output and Reporting

```bash
# JSON for programmatic processing
checkov -d ./terraform/ -o json | jq '.results.failed_checks[] | {id: .check_id, resource: .resource, file: .repo_file_path}'

# Count by severity
checkov -d ./terraform/ -o json | jq '.summary'

# Generate JUnit XML for test reports
checkov -d ./terraform/ -o junitxml > checkov-junit.xml

# Table with only failures
checkov -d ./terraform/ --compact
```

## Suppressing False Positives

```hcl
# Suppress in Terraform with comment
resource "aws_s3_bucket" "logs" {
  bucket = "my-access-logs"

  #checkov:skip=CKV_AWS_19:Access logs don't need encryption
  #checkov:skip=CKV_AWS_21:Versioning not needed for transient logs
}
```

## GitNexus Index

This skill is indexed by GitNexus for knowledge graph traversal.
Index path: /Users/localuser/.claude/skills/checkov/.gitnexus
Last indexed: 2026-05-24
