---
name: opentofu
description: OpenTofu — the open-source, community-driven fork of Terraform (maintained by the Linux Foundation). Use this skill whenever the user mentions OpenTofu, tofu CLI, migrating from Terraform to OpenTofu, needs HCL infrastructure-as-code, state management, provider configuration, modules, workspaces, or any Terraform-compatible IaC workflow. Trigger for "tofu plan", "tofu apply", OpenTofu providers, or "open source terraform".
---

# OpenTofu — Open-Source Infrastructure as Code

## Overview

OpenTofu is the open-source, Linux Foundation-backed fork of Terraform (MPL-licensed). It is API-compatible with Terraform up to version 1.5 and adds features like state encryption, provider-defined functions, and improved variable handling. The CLI command is `tofu` instead of `terraform`.

## When to Use

- Writing HCL infrastructure code for any cloud provider
- Migrating existing Terraform code to OpenTofu (drop-in replacement for most cases)
- CI/CD pipelines that need an open-source IaC engine
- State encryption and advanced workspace management
- Using the OpenTofu registry or community modules

## Installation

```bash
# macOS
brew install opentofu

# Linux (apt)
curl -fsSL https://get.opentofu.org/install-opentofu.sh | sh -s -- --install-method deb

# Verify
tofu version
```

## Migrating from Terraform

```bash
# 1. Install OpenTofu
brew install opentofu

# 2. In your existing Terraform directory, just use tofu instead of terraform
tofu init        # reads existing .terraform.lock.hcl
tofu plan
tofu apply

# State files are fully compatible — no migration needed for local state
# For Terraform Cloud state, migrate to a different backend first
```

## Key Patterns

### Basic Resource Definition

```hcl
terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "registry.opentofu.org/hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket         = "my-tofu-state"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name        = "${var.project}-vpc"
    Environment = var.environment
  }
}

output "vpc_id" {
  value = aws_vpc.main.id
}
```

### Variables and Locals

```hcl
variable "project" {
  type        = string
  description = "Project name used in resource tags"
}

variable "environment" {
  type    = string
  default = "dev"
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging, or prod"
  }
}

locals {
  common_tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "opentofu"
  }
  name_prefix = "${var.project}-${var.environment}"
}
```

### Modules

```hcl
# modules/eks-cluster/main.tf
resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  role_arn = var.role_arn
  version  = var.kubernetes_version
  vpc_config {
    subnet_ids = var.subnet_ids
  }
}

# root/main.tf
module "eks" {
  source             = "./modules/eks-cluster"
  cluster_name       = "${local.name_prefix}-eks"
  role_arn           = aws_iam_role.eks.arn
  subnet_ids         = module.vpc.private_subnet_ids
  kubernetes_version = "1.29"
}
```

### State Encryption (OpenTofu-exclusive)

```hcl
terraform {
  encryption {
    key_provider "pbkdf2" "my_key" {
      passphrase = var.state_passphrase
    }
    method "aes_gcm" "default" {
      keys = key_provider.pbkdf2.my_key
    }
    state {
      method = method.aes_gcm.default
    }
    plan {
      method = method.aes_gcm.default
    }
  }
}
```

### For-Each and Dynamic Blocks

```hcl
variable "subnets" {
  type = map(object({
    cidr = string
    az   = string
  }))
  default = {
    public  = { cidr = "10.0.1.0/24", az = "us-east-1a" }
    private = { cidr = "10.0.2.0/24", az = "us-east-1b" }
  }
}

resource "aws_subnet" "this" {
  for_each          = var.subnets
  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az
  tags              = merge(local.common_tags, { Name = "${local.name_prefix}-${each.key}" })
}
```

### Data Sources

```hcl
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

resource "aws_instance" "web" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"
}
```

## Common CLI Commands

```bash
tofu init                    # Initialize working directory
tofu plan                    # Show planned changes
tofu plan -out=tfplan        # Save plan to file
tofu apply tfplan            # Apply saved plan (no prompt)
tofu apply -auto-approve     # Apply without prompt (CI use)
tofu destroy                 # Destroy all resources
tofu workspace new staging   # Create new workspace
tofu workspace select prod   # Switch workspace
tofu state list              # List resources in state
tofu state show <resource>   # Show resource state
tofu import aws_s3_bucket.x  existing-bucket-name  # Import existing resource
tofu fmt -recursive          # Format all .tf files
tofu validate                # Validate configuration
tofu output                  # Show all outputs
```

## Pitfalls

- **Provider lock file**: run `tofu providers lock` after changing provider versions; commit `.terraform.lock.hcl`
- **`count` vs `for_each`**: use `for_each` with maps/sets for stable addressing; `count` causes resource churn when list order changes
- **Remote state locking**: always use a backend with locking (S3 + DynamoDB, GCS, Azure Blob) to prevent concurrent applies
- **Sensitive outputs**: mark `sensitive = true` on outputs containing credentials — they still appear in state, just not in CLI output
- **State in VCS**: never commit `.tfstate` files; use a remote backend
- **Partial applies**: if `tofu apply` fails mid-way, run `tofu plan` again before retrying to see the true diff

## Related Skills

- `terraform-code-generation` — HCL generation patterns
- `pulumi` — alternative IaC with real programming languages
- `atlantis` — PR-based Terraform/OpenTofu automation
- `kubernetes-architect` — K8s infrastructure with tofu
- `aws-solution-architect` — AWS resource patterns

## GitNexus Index

Index path: /Users/localuser/.claude/skills/opentofu/.gitnexus
Created: 2026-05-24
