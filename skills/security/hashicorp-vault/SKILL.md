---
name: hashicorp-vault
description: HashiCorp Vault — secrets management, encryption as a service, and dynamic credentials. Use this skill whenever the user needs to store and retrieve secrets, generate dynamic database credentials, issue short-lived certificates (PKI), set up Kubernetes auth for pod secret access, configure Vault policies, or implement secrets rotation. Trigger for "vault secrets", "vault kv", "vault dynamic credentials", "vault pki", "vault kubernetes auth", "hashicorp vault", or "secrets management vault".
---

# HashiCorp Vault — Secrets Management

## Overview

HashiCorp Vault is a secrets management tool that provides secure storage for tokens, passwords, certificates, and API keys, plus dynamic credential generation — it can create short-lived database credentials on-demand so that no long-lived secrets need to be distributed. Vault supports many backends (AWS, GCP, Azure, databases, PKI, SSH) and authentication methods (Kubernetes, AWS IAM, LDAP, OIDC). The key insight: instead of storing a database password in your app config, Vault generates a new unique credential for each request with a TTL, and the credential is automatically revoked after the lease expires.

## When to Use

- Centralizing secret storage across microservices and environments
- Generating dynamic database credentials (Postgres, MySQL, MongoDB)
- Issuing short-lived TLS certificates (PKI secrets engine)
- Kubernetes pod authentication without hardcoded service account tokens
- Encrypting application data at rest without managing encryption keys
- Secret rotation and audit logging for compliance (SOC2, PCI-DSS)

## Installation

```bash
# macOS
brew tap hashicorp/tap
brew install hashicorp/tap/vault

# Linux (Ubuntu/Debian)
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt install vault

# Start a dev server (ephemeral, in-memory — for testing only)
vault server -dev &
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='root'  # printed by dev server

# Verify
vault status
```

## Key Patterns

### KV Secrets Engine — Static Secrets

```bash
# Enable KV v2 (versioned) secrets engine
vault secrets enable -path=secret kv-v2

# Write a secret
vault kv put secret/myapp/prod \
  database_url="postgres://user:pass@host:5432/db" \
  api_key="sk-..."

# Read a secret
vault kv get secret/myapp/prod
vault kv get -field=database_url secret/myapp/prod

# List secrets
vault kv list secret/myapp/

# Get secret metadata (versions, creation time)
vault kv metadata get secret/myapp/prod

# Get a specific version
vault kv get -version=2 secret/myapp/prod

# Delete (soft delete, recoverable)
vault kv delete secret/myapp/prod

# Permanently destroy a version
vault kv destroy -versions=1 secret/myapp/prod
```

### Dynamic Database Credentials — PostgreSQL

```bash
# Enable the database secrets engine
vault secrets enable database

# Configure the connection (Vault will use this to manage credentials)
vault write database/config/my-postgres \
  plugin_name=postgresql-database-plugin \
  allowed_roles="my-app-role" \
  connection_url="postgresql://{{username}}:{{password}}@postgres:5432/mydb?sslmode=disable" \
  username="vault-admin" \
  password="vault-admin-password"

# Create a role (Vault will generate users with this SQL on each request)
vault write database/roles/my-app-role \
  db_name=my-postgres \
  creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; \
    GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO \"{{name}}\";" \
  default_ttl="1h" \
  max_ttl="24h"

# Generate credentials (application calls this at startup)
vault read database/creds/my-app-role
# Returns: username=v-app-xyz1234, password=A1B2C3...
# These credentials expire automatically after 1h
```

### PKI Secrets Engine — TLS Certificate Authority

```bash
# Enable PKI
vault secrets enable -path=pki pki
vault secrets tune -max-lease-ttl=87600h pki

# Generate root CA
vault write -field=certificate pki/root/generate/internal \
  common_name="my-org.com" \
  ttl=87600h > CA_cert.crt

# Configure URLs
vault write pki/config/urls \
  issuing_certificates="$VAULT_ADDR/v1/pki/ca" \
  crl_distribution_points="$VAULT_ADDR/v1/pki/crl"

# Create an intermediate CA
vault secrets enable -path=pki_int pki
vault write -format=json pki_int/intermediate/generate/internal \
  common_name="my-org.com Intermediate Authority" | jq -r '.data.csr' > pki_intermediate.csr

vault write -format=json pki/root/sign-intermediate \
  csr=@pki_intermediate.csr \
  format=pem_bundle \
  ttl=43800h | jq -r '.data.certificate' > intermediate.cert.pem

vault write pki_int/intermediate/set-signed certificate=@intermediate.cert.pem

# Create a role for issuing certs
vault write pki_int/roles/my-app \
  allowed_domains="my-app.example.com,*.my-app.example.com" \
  allow_subdomains=true \
  max_ttl="720h"

# Issue a certificate
vault write pki_int/issue/my-app \
  common_name="api.my-app.example.com" \
  ttl="24h"
```

### Kubernetes Auth — Pod Authentication

```bash
# Enable Kubernetes auth method
vault auth enable kubernetes

# Configure Vault to trust the Kubernetes cluster
vault write auth/kubernetes/config \
  kubernetes_host="https://$KUBERNETES_SERVICE_HOST:$KUBERNETES_SERVICE_PORT" \
  token_reviewer_jwt="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
  kubernetes_ca_cert="$(cat /var/run/secrets/kubernetes.io/serviceaccount/ca.crt)"

# Create a role binding service account to a Vault policy
vault write auth/kubernetes/role/my-app \
  bound_service_account_names=my-app-sa \
  bound_service_account_namespaces=production \
  policies=my-app-policy \
  ttl=1h
```

```hcl
# my-app-policy.hcl
# Allow the app to read its own secrets
path "secret/data/myapp/prod" {
  capabilities = ["read"]
}

# Allow generating dynamic database credentials
path "database/creds/my-app-role" {
  capabilities = ["read"]
}
```

```bash
vault policy write my-app-policy my-app-policy.hcl
```

```python
# Python app: authenticate with Vault using Kubernetes service account token
import hvac, os

client = hvac.Client(url=os.environ["VAULT_ADDR"])

# Login with Kubernetes JWT
jwt_token = open("/var/run/secrets/kubernetes.io/serviceaccount/token").read()
client.auth.kubernetes.login(role="my-app", jwt=jwt_token)

# Read secret
secret = client.secrets.kv.v2.read_secret_version(path="myapp/prod", mount_point="secret")
db_url = secret["data"]["data"]["database_url"]
```

### Vault Agent — Sidecar for Auto-Auth and Secret Templating

```hcl
# vault-agent-config.hcl (Kubernetes sidecar)
auto_auth {
  method "kubernetes" {
    mount_path = "auth/kubernetes"
    config = {
      role = "my-app"
    }
  }

  sink "file" {
    config = {
      path = "/vault/token"
    }
  }
}

template {
  source      = "/vault/templates/config.tmpl"
  destination = "/app/config/config.env"
  perms       = 0600
  command     = "kill -HUP $(cat /app/app.pid)"  # reload app on secret change
}
```

```
{{/* /vault/templates/config.tmpl */}}
{{ with secret "secret/data/myapp/prod" }}
DATABASE_URL={{ .Data.data.database_url }}
API_KEY={{ .Data.data.api_key }}
{{ end }}
{{ with secret "database/creds/my-app-role" }}
DB_USERNAME={{ .Data.username }}
DB_PASSWORD={{ .Data.password }}
{{ end }}
```

## Common Commands

```bash
vault status                              # Cluster status
vault secrets list                        # List enabled secrets engines
vault auth list                           # List enabled auth methods
vault policy list                         # List policies
vault policy read my-app-policy           # Read a policy
vault token lookup                        # Info about current token
vault token create -policy=my-app-policy -ttl=1h  # Create a token
vault lease renew <lease-id>              # Renew a dynamic credential lease
vault lease revoke <lease-id>             # Immediately revoke a lease
vault audit list                          # List audit devices
vault audit enable file file_path=/var/log/vault_audit.log  # Enable audit log
```

## Pitfalls

- **Seal/unseal**: Vault starts sealed and must be unsealed with multiple keys (Shamir's Secret Sharing) or auto-unseal (AWS KMS, GCP Cloud KMS) after every restart — plan for auto-unseal in production or Vault restarts cause outages
- **Token TTL vs lease TTL**: the app token has a TTL, and dynamic credential leases also have TTLs — the Vault Agent handles both renewals automatically; without it, credentials silently expire
- **Root token should not be used in production**: the root token bootstraps Vault but should be immediately revoked after creating admin tokens with appropriate policies; never commit root tokens to code
- **KV v1 vs v2**: KV v2 adds versioning and metadata but has a different API path (`/secret/data/<path>` vs `/secret/<path>`) — make sure applications use the correct path
- **Audit log overhead**: enabling the file audit log on a high-traffic Vault instance writes every request to disk — use a syslog or socket audit device and ship to a centralized logging system to avoid disk saturation

## Related Skills

- `consul` — pairs with Vault for service mesh certificate management
- `nomad` — uses Vault for secret injection via `template` blocks in job specs
- `opentofu` — Vault provider can manage policies, roles, and mounts as code
- `kubernetes-architect` — Vault Agent Injector as a mutating webhook for K8s pods
- `hashicorp-boundary` — uses Vault for brokered credential injection

## GitNexus Index

Index path: /Users/localuser/.claude/skills/hashicorp-vault/.gitnexus
Created: 2026-05-24
