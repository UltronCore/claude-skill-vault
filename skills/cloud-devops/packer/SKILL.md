---
name: packer
description: HashiCorp Packer — automated machine image builder for AWS AMIs, Docker images, VMware, GCP, Azure, and more. Use this skill whenever the user needs to build reproducible machine images, bake AMIs for EC2 or Karpenter nodes, create golden images with pre-installed software, set up multi-cloud image pipelines, or write HCL-based Packer templates. Trigger for "packer build", "AMI builder", "golden image", "bake ami", "packer template hcl", or "immutable infrastructure images".
---

# Packer — Automated Machine Image Builder

## Overview

HashiCorp Packer automates the creation of machine images (AMIs, Docker images, VMware OVAs, GCP images, Azure VHDs) from a single source configuration. It provisions a temporary machine, runs provisioners (shell scripts, Ansible, Chef), then captures a snapshot as a reusable image. Packer enables immutable infrastructure patterns — instead of updating running servers, you bake new images and replace instances. It uses HCL2 configuration files (`.pkr.hcl`) with a plugin architecture supporting 50+ builders.

## When to Use

- Building custom AWS AMIs for EC2, EKS worker nodes, or Karpenter NodePools
- Creating Docker images with complex multi-step provisioning
- Maintaining golden images with pre-installed agents (DataDog, SSM agent, CW agent)
- Ensuring reproducibility — every image built from the same template is identical
- Multi-cloud image pipelines (build once in AWS, copy to GCP/Azure)
- Patching base images regularly for CVE remediation

## Installation

```bash
# macOS
brew tap hashicorp/tap
brew install hashicorp/tap/packer

# Linux (Debian/Ubuntu)
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt install packer

# Verify
packer version

# Initialize plugins (run in the template directory)
packer init .
```

## Key Patterns

### AWS AMI — HCL2 Template

```hcl
# aws-ami.pkr.hcl

packer {
  required_plugins {
    amazon = {
      version = ">= 1.3.0"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

# Variables — override at build time with -var or .pkrvars.hcl files
variable "aws_region" {
  default = "us-east-1"
}

variable "base_ami" {
  default = "ami-0c02fb55956c7d316"  # Amazon Linux 2023
}

variable "instance_type" {
  default = "t3.medium"
}

# The source block defines what to build from
source "amazon-ebs" "al2023" {
  region        = var.aws_region
  source_ami    = var.base_ami
  instance_type = var.instance_type
  ssh_username  = "ec2-user"

  ami_name        = "my-golden-image-${formatdate("YYYY-MM-DD-hhmmss", timestamp())}"
  ami_description = "Golden image with Node.js 20, CloudWatch agent, SSM agent"

  # Tag the resulting AMI
  tags = {
    Name        = "golden-image"
    Environment = "production"
    BuildDate   = formatdate("YYYY-MM-DD", timestamp())
    Source      = "packer"
  }

  # Tag the source instance during build (useful for debugging)
  run_tags = {
    Name = "packer-builder"
  }
}

# The build block connects a source to provisioners
build {
  name    = "golden-image"
  sources = ["source.amazon-ebs.al2023"]

  # Run shell commands
  provisioner "shell" {
    inline = [
      "sudo dnf update -y",
      "sudo dnf install -y amazon-cloudwatch-agent amazon-ssm-agent",
      "sudo systemctl enable amazon-cloudwatch-agent amazon-ssm-agent",
    ]
  }

  # Install Node.js via script file
  provisioner "shell" {
    scripts = ["scripts/install-node.sh"]
    environment_vars = ["NODE_VERSION=20"]
  }

  # Copy config files from the local machine
  provisioner "file" {
    source      = "configs/cloudwatch-config.json"
    destination = "/tmp/cloudwatch-config.json"
  }

  provisioner "shell" {
    inline = [
      "sudo mv /tmp/cloudwatch-config.json /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json",
    ]
  }

  # Run Ansible playbook
  provisioner "ansible" {
    playbook_file = "ansible/harden.yml"
    extra_arguments = ["--extra-vars", "env=production"]
  }

  # Post-processor: manifest records the output AMI ID
  post-processor "manifest" {
    output     = "manifest.json"
    strip_path = true
  }
}
```

### Variables File

```hcl
# production.pkrvars.hcl — pass with: packer build -var-file=production.pkrvars.hcl .
aws_region    = "us-east-1"
base_ami      = "ami-0c02fb55956c7d316"
instance_type = "t3.medium"
```

### Multi-Region AMI Copy

```hcl
source "amazon-ebs" "base" {
  region        = "us-east-1"
  source_ami    = var.base_ami
  instance_type = "t3.medium"
  ssh_username  = "ec2-user"
  ami_name      = "my-app-${formatdate("YYYYMMDD-hhmmss", timestamp())}"

  # Copy the AMI to additional regions after build
  ami_regions = ["us-west-2", "eu-west-1", "ap-southeast-1"]

  # Encrypt in all regions
  encrypt_boot = true
  kms_key_id   = "alias/my-ami-key"  # for primary region
  region_kms_key_ids = {
    "us-west-2"      = "alias/my-ami-key"
    "eu-west-1"      = "alias/my-ami-key"
    "ap-southeast-1" = "alias/my-ami-key"
  }
}
```

### Docker Image via Packer

```hcl
packer {
  required_plugins {
    docker = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/docker"
    }
  }
}

source "docker" "ubuntu" {
  image  = "ubuntu:22.04"
  commit = true
  changes = [
    "EXPOSE 8080",
    "ENTRYPOINT [\"/app/server\"]",
    "USER nonroot",
  ]
}

build {
  sources = ["source.docker.ubuntu"]

  provisioner "shell" {
    inline = [
      "apt-get update && apt-get install -y ca-certificates curl",
      "useradd -r -s /sbin/nologin nonroot",
    ]
  }

  provisioner "file" {
    source      = "dist/server"
    destination = "/app/server"
  }

  post-processors {
    post-processor "docker-tag" {
      repository = "my-registry.io/my-app"
      tags       = ["latest", var.image_tag]
    }
    post-processor "docker-push" {}
  }
}
```

### GitHub Actions — Build AMI on Push

```yaml
name: Build AMI
on:
  push:
    branches: [main]
    paths: ['packer/**']

jobs:
  build-ami:
    runs-on: ubuntu-latest
    permissions:
      id-token: write  # for OIDC
      contents: read
    steps:
      - uses: actions/checkout@v4
      - uses: hashicorp/setup-packer@main
        with:
          version: "1.11.0"
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789:role/PackerRole
          aws-region: us-east-1
      - name: Packer Init
        run: packer init packer/
      - name: Packer Validate
        run: packer validate packer/
      - name: Packer Build
        run: packer build -var-file=packer/production.pkrvars.hcl packer/
      - name: Read AMI ID
        run: |
          AMI_ID=$(jq -r '.builds[-1].artifact_id' manifest.json | cut -d: -f2)
          echo "Built AMI: $AMI_ID"
          echo "AMI_ID=$AMI_ID" >> $GITHUB_ENV
```

## Common Commands

```bash
packer init .                               # Download required plugins
packer validate aws-ami.pkr.hcl            # Validate template syntax
packer fmt .                               # Format .pkr.hcl files
packer build aws-ami.pkr.hcl               # Build the image
packer build -var "aws_region=us-west-2" . # Override a variable
packer build -only="amazon-ebs.al2023" .   # Build only one source
packer build -debug .                      # Pause at each step for debugging
packer inspect aws-ami.pkr.hcl             # Show sources and provisioners

# Debug a failed build — the -debug flag pauses after each step
# and leaves the instance running so you can SSH in
packer build -debug -on-error=ask .
```

## Pitfalls

- **AMI name must be unique**: if a build fails halfway, a partial AMI with the same name may block future builds — deregister the partial AMI before retrying
- **SSH connectivity**: Packer connects via SSH; ensure the source AMI's security group allows inbound SSH from wherever Packer runs (a VPC with internet access, or use `session_manager_port_number` for SSM-based connectivity without SSH)
- **IAM permissions for Packer**: Packer needs `ec2:RunInstances`, `ec2:CreateImage`, `ec2:DescribeImages`, and friends — use the official [Packer IAM policy](https://developer.hashicorp.com/packer/integrations/hashicorp/amazon#iam-task-or-instance-role) from the docs
- **Provisioner ordering matters**: `file` provisioners run before `shell` in parallel batches — if you need to move a file after installing a package, use a separate `shell` provisioner after the `file` block
- **`timestamp()` in AMI names**: Packer evaluates `timestamp()` at template load time, not at build time — all sources in a single build use the same timestamp, which is correct behavior

## Related Skills

- `karpenter` — uses custom AMIs via EC2NodeClass `amiSelectorTerms`
- `opentofu` — can reference Packer-built AMIs via data sources
- `pulumi` — can look up AMI IDs from Packer manifest.json
- `aws-solution-architect` — EC2 and EKS AMI strategy
- `container-security` — harden Docker images built with Packer

## GitNexus Index

Index path: /Users/localuser/.claude/skills/packer/.gitnexus
Created: 2026-05-24
