---
name: boundary
description: HashiCorp Boundary — identity-based secure remote access without VPN or bastion hosts. Use this skill whenever the user needs to provide SSH/RDP/database access to engineers without exposing infrastructure, replace bastion hosts with identity-aware access, set up just-in-time access with Vault-brokered credentials, configure Boundary targets and host catalogs, or integrate with SSO for infrastructure access. Trigger for "boundary access", "hashicorp boundary", "replace bastion host", "just-in-time access", "boundary targets", or "identity-based ssh access".
---

# HashiCorp Boundary — Identity-Based Remote Access

## Overview

HashiCorp Boundary provides secure remote access to hosts and services based on identity — not network perimeter. Instead of giving engineers a VPN or bastion host access, Boundary lets them connect to databases, Kubernetes clusters, or SSH targets through a policy-driven proxy that logs every session. Boundary integrates with Vault to broker short-lived credentials (no shared passwords), supports SSO via OIDC (Okta, Azure AD, Google), and works on any infrastructure without firewall rule changes. The result: engineers get the access they need, security gets audit logs of every connection.

## When to Use

- Replacing VPN + bastion hosts with identity-aware access control
- Providing database access to engineers without sharing root passwords
- Implementing just-in-time access with automatic credential injection from Vault
- Auditing every SSH session, database connection, and Kubernetes kubectl command
- Multi-cloud or multi-datacenter access that spans network boundaries
- SOC2/compliance requirements for privileged access management (PAM)

## Installation

```bash
# macOS
brew tap hashicorp/tap
brew install hashicorp/tap/boundary

# Linux (Ubuntu/Debian)
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt install boundary

# Install Boundary Desktop (GUI for engineers)
# Download from https://developer.hashicorp.com/boundary/downloads

# Start dev mode (ephemeral, all-in-one — for testing)
boundary dev &
export BOUNDARY_ADDR='http://127.0.0.1:9200'

# Verify
boundary status
```

## Key Patterns

### Production Boundary Configuration — Controller

```hcl
# /etc/boundary/controller.hcl

disable_mlock = true

controller {
  name        = "us-east-controller"
  description = "Production Boundary controller"

  database {
    url = env("BOUNDARY_POSTGRES_URL")  # PostgreSQL backend
  }

  public_cluster_addr = "boundary.internal.mycompany.com:9201"
}

listener "tcp" {
  address              = "0.0.0.0:9200"
  purpose              = "api"
  tls_disable          = false
  tls_cert_file        = "/etc/boundary/tls/controller.pem"
  tls_key_file         = "/etc/boundary/tls/controller-key.pem"
  cors_enabled         = true
  cors_allowed_origins = ["https://boundary.mycompany.com"]
}

listener "tcp" {
  address = "0.0.0.0:9201"
  purpose = "cluster"
}

kms "awskms" {
  purpose    = "root"
  region     = "us-east-1"
  kms_key_id = "alias/boundary-root"
}

kms "awskms" {
  purpose    = "worker-auth"
  region     = "us-east-1"
  kms_key_id = "alias/boundary-worker-auth"
}
```

### Worker Configuration

```hcl
# /etc/boundary/worker.hcl — runs close to the targets (in the same VPC)
worker {
  name        = "us-east-worker-1"
  description = "Worker in us-east-1 VPC"

  # Workers connect outbound to controller — no inbound firewall rules needed
  initial_upstreams = ["boundary.internal.mycompany.com:9201"]

  public_addr = "worker1.internal.mycompany.com"
}

listener "tcp" {
  address = "0.0.0.0:9202"
  purpose = "proxy"
}

kms "awskms" {
  purpose    = "worker-auth"
  region     = "us-east-1"
  kms_key_id = "alias/boundary-worker-auth"
}
```

### Terraform — Boundary Resources as Code

```hcl
# Configure Boundary provider
provider "boundary" {
  addr                            = "https://boundary.mycompany.com"
  auth_method_id                  = var.boundary_auth_method_id
  password_auth_method_login_name = var.boundary_login_name
  password_auth_method_password   = var.boundary_password
}

# Scope hierarchy: global → org → project
resource "boundary_scope" "org" {
  name     = "mycompany"
  scope_id = "global"
}

resource "boundary_scope" "production" {
  name     = "production"
  scope_id = boundary_scope.org.id
}

# Host catalog — a collection of hosts
resource "boundary_host_catalog_static" "aws_hosts" {
  name     = "AWS Production Hosts"
  scope_id = boundary_scope.production.id
}

# Individual hosts
resource "boundary_host_static" "postgres_primary" {
  name            = "postgres-primary"
  host_catalog_id = boundary_host_catalog_static.aws_hosts.id
  address         = "10.0.1.50"  # private IP — only worker can reach it
}

# Host set — groups hosts into a target
resource "boundary_host_set_static" "postgres_hosts" {
  name            = "postgres-hosts"
  host_catalog_id = boundary_host_catalog_static.aws_hosts.id
  host_ids        = [boundary_host_static.postgres_primary.id]
}

# Target — what engineers connect to
resource "boundary_target" "postgres" {
  name         = "postgres-production"
  description  = "Production PostgreSQL database"
  type         = "tcp"
  scope_id     = boundary_scope.production.id
  default_port = 5432

  host_source_ids = [boundary_host_set_static.postgres_hosts.id]

  # Vault credential brokering — inject dynamic credentials on connect
  brokered_credential_source_ids = [
    boundary_credential_source_vault_generic.postgres_creds.id
  ]

  # Session recording (HCP Boundary or Boundary Enterprise)
  # enable_session_recording = true

  # Worker filter — only workers in us-east-1 can proxy this target
  egress_worker_filter = "\"us-east-1\" in \"/tags/region\""
}

# Vault credential store
resource "boundary_credential_store_vault" "main" {
  name       = "vault-prod"
  scope_id   = boundary_scope.production.id
  address    = "https://vault.internal.mycompany.com"
  token      = var.vault_token  # or use Vault auth method
  namespace  = "admin"
}

# Credential library — fetches creds from Vault on each session
resource "boundary_credential_source_vault_generic" "postgres_creds" {
  name                = "postgres-dynamic-creds"
  credential_store_id = boundary_credential_store_vault.main.id
  path                = "database/creds/my-app-role"  # Vault dynamic creds path
  http_method         = "GET"
  credential_type     = "username_password"
}
```

### OIDC Auth — SSO with Okta or Azure AD

```hcl
resource "boundary_auth_method_oidc" "okta" {
  name             = "okta-sso"
  scope_id         = boundary_scope.org.id
  issuer           = "https://mycompany.okta.com"
  client_id        = var.okta_client_id
  client_secret    = var.okta_client_secret
  signing_algorithms = ["RS256"]
  api_url_prefix   = "https://boundary.mycompany.com"
  callback_url     = "https://boundary.mycompany.com/v1/auth-methods/oidc:authenticate:callback"
  is_primary_for_scope = true

  # Map Okta groups to Boundary managed groups
  # Groups are then granted roles within scopes
  claims_scopes = ["openid", "profile", "email", "groups"]
}

# Managed group — users in this OIDC group get the role below
resource "boundary_managed_group" "engineers" {
  name           = "engineers"
  auth_method_id = boundary_auth_method_oidc.okta.id
  filter         = "\"engineering\" in \"/token/groups\""
}

# Grant engineers access to connect to production targets
resource "boundary_role" "engineer_prod_access" {
  name     = "engineer-production-access"
  scope_id = boundary_scope.production.id

  grant_scope_ids = [boundary_scope.production.id]
  principal_ids   = [boundary_managed_group.engineers.id]

  grant_strings = [
    "ids=*;type=target;actions=list,read,authorize-session",
  ]
}
```

### Connecting via Boundary CLI

```bash
# Authenticate with SSO
boundary authenticate oidc -auth-method-id=amoidc_xxxx

# List targets (shows what the authenticated user can access)
boundary targets list -scope-id=p_xxxx -recursive

# Connect to a target (Boundary opens a local proxy tunnel)
boundary connect -target-id=tssh_xxxx

# Connect to SSH (Boundary injects credentials)
boundary connect ssh -target-id=tssh_xxxx

# Connect to a database (opens a local port; connect your DB client to it)
boundary connect postgres -target-id=ttcp_xxxx -dbname=mydb

# Connect to Kubernetes API (then use kubectl)
boundary connect kube -target-id=ttcp_xxxx -- get pods

# Named sessions — connect via target name
boundary connect -target-name="postgres-production" -target-scope-name="production"
```

## Common Commands

```bash
boundary status                                    # Cluster health
boundary targets list -scope-id=<project-id>      # List available targets
boundary sessions list -scope-id=<project-id>     # List active sessions
boundary sessions cancel -id=<session-id>         # Kill a session
boundary accounts list -auth-method-id=<id>       # List user accounts
boundary users list -scope-id=<org-id>            # List users
boundary roles list -scope-id=<project-id>        # List roles
boundary server -config=controller.hcl            # Start server
```

## Pitfalls

- **Worker connectivity is outbound-only**: workers connect to controllers, not the other way — ensure workers have outbound TCP to the controller's cluster port (9201); no inbound rules needed on the worker
- **Target requires a host source**: a target without a `host_source_ids` cannot be used to connect — always attach a host set or dynamic host catalog
- **Credential brokering vs injection**: "brokered" credentials are shown to the engineer to use manually (e.g., a password displayed at connect time); injected credentials are passed directly to the SSH or DB client without the engineer ever seeing them (requires Boundary Enterprise/HCP for SSH injection)
- **Session recording storage**: session recording requires HCP Boundary or Boundary Enterprise and an S3 bucket configured on the worker — not available in OSS Boundary
- **Token renewal**: the Boundary CLI token expires; re-authenticate with `boundary authenticate` when sessions start failing with 401 errors

## Related Skills

- `hashicorp-vault` — pairs with Boundary for dynamic credential brokering
- `consul` — Boundary can use dynamic host catalogs based on Consul service catalog
- `opentofu` — Boundary provider manages all resources as infrastructure code
- `security-hardening-checklist` — broader privileged access management strategy
- `soc2-compliance` — session recording and audit logs are key SOC2 evidence

## GitNexus Index

Index path: /Users/localuser/.claude/skills/boundary/.gitnexus
Created: 2026-05-24
