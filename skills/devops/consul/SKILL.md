---
name: consul
description: HashiCorp Consul — service discovery, service mesh, and distributed configuration. Use this skill whenever the user needs service registration and health checking, DNS-based service discovery, Consul Connect service mesh with mTLS, KV store for distributed config, ACL policies, or wants to understand how Consul pairs with Nomad/Vault. Trigger for "consul service discovery", "consul connect", "consul kv", "consul dns", "consul acl", "hashicorp consul", or "service mesh consul".
---

# Consul — Service Discovery and Service Mesh

## Overview

HashiCorp Consul provides service discovery, health checking, a key-value store, and a service mesh with mutual TLS (Consul Connect). Services register themselves or are registered by Nomad, and other services discover them via DNS (`<service>.service.consul`) or the HTTP API. Consul Connect uses Envoy sidecar proxies to enforce L4/L7 policies between services without application code changes. Consul integrates natively with Nomad (workload orchestration), Vault (certificate management), and Terraform (infrastructure).

## When to Use

- Service discovery for microservices across VMs or containers
- Health checking with automatic removal of unhealthy instances from DNS
- Consul Connect (service mesh) for mTLS and L7 traffic management without Kubernetes
- Distributed key-value store for dynamic configuration
- Multi-datacenter service federation
- Access control and audit logging via ACL system

## Installation

```bash
# macOS
brew tap hashicorp/tap
brew install hashicorp/tap/consul

# Linux (Ubuntu/Debian)
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt install consul

# Start a dev agent (single node, ephemeral — for testing)
consul agent -dev &

# Verify
consul members
consul catalog services
```

## Key Patterns

### Consul Server Configuration (Production)

```hcl
# /etc/consul.d/consul.hcl (server node)
datacenter = "us-east-1"
data_dir   = "/opt/consul"
log_level  = "INFO"

server           = true
bootstrap_expect = 3  # 3-node cluster for quorum

# Addresses
client_addr    = "0.0.0.0"
advertise_addr = "{{ GetInterfaceIP \"eth0\" }}"

# UI
ui_config {
  enabled = true
}

# TLS for inter-node communication
tls {
  defaults {
    ca_file   = "/etc/consul.d/consul-agent-ca.pem"
    cert_file = "/etc/consul.d/dc1-server-consul-0.pem"
    key_file  = "/etc/consul.d/dc1-server-consul-0-key.pem"
    verify_incoming        = true
    verify_outgoing        = true
    verify_server_hostname = true
  }
}

# Auto-encrypt for client TLS distribution
auto_encrypt {
  allow_tls = true
}

# Gossip encryption
encrypt = "base64-encoded-32-byte-key"

# ACL
acl {
  enabled        = true
  default_policy = "deny"
  enable_token_persistence = true
}

# Enable Connect (service mesh)
connect {
  enabled = true
}
```

### Service Registration — JSON Definition

```json
// /etc/consul.d/web-api.json
{
  "service": {
    "name": "web-api",
    "id": "web-api-1",
    "port": 8080,
    "tags": ["api", "v2"],
    "meta": {
      "version": "2.1.0",
      "environment": "production"
    },
    "check": {
      "id": "web-api-health",
      "http": "http://localhost:8080/healthz",
      "interval": "10s",
      "timeout": "3s",
      "deregister_critical_service_after": "90s"
    }
  }
}
```

```bash
consul reload  # reload config without restart
consul catalog services
consul health service web-api  # show only passing instances
```

### Service Discovery via DNS

```bash
# Consul DNS runs on port 8600 by default
# Services are discoverable at <service>.service.<datacenter>.consul

# Look up all healthy instances of "web-api"
dig @127.0.0.1 -p 8600 web-api.service.consul

# Look up only instances with tag "v2"
dig @127.0.0.1 -p 8600 v2.web-api.service.consul

# SRV record includes port
dig @127.0.0.1 -p 8600 web-api.service.consul SRV

# Forward .consul queries from system DNS to Consul (Linux systemd-resolved)
# /etc/systemd/resolved.conf.d/consul.conf:
# [Resolve]
# DNS=127.0.0.1:8600
# DOMAINS=~consul
```

### Consul Connect — Service Mesh with mTLS

```hcl
# Register a service with Connect proxy (sidecar)
{
  "service": {
    "name": "payment-service",
    "port": 9090,
    "connect": {
      "sidecar_service": {
        "proxy": {
          "upstreams": [
            {
              "destination_name": "database",
              "local_bind_port": 5432
            }
          ]
        }
      }
    }
  }
}
```

```hcl
# Intention: allow payment-service to talk to database
# (deny all by default when Connect is enabled)
consul intention create payment-service database

# Or via HCL config file (preferred for GitOps)
# /etc/consul.d/intentions.hcl
config_entry {
  kind = "service-intentions"
  name = "database"
  
  sources {
    name   = "payment-service"
    action = "allow"
  }
}
consul config write /etc/consul.d/intentions.hcl
```

### Key-Value Store

```bash
# Write a value
consul kv put config/app/database_url "postgres://..."
consul kv put config/app/feature_flags/dark_mode "true"

# Read a value
consul kv get config/app/database_url

# List all keys under a prefix
consul kv get -recurse config/app/

# Watch for changes (blocks until key changes)
consul watch -type=key -key=config/app/database_url cat

# Delete
consul kv delete config/app/feature_flags/dark_mode
```

### ACL — Token-Based Access Control

```bash
# Bootstrap ACL system (run once)
consul acl bootstrap
# Save the master token from the output

# Create a policy for web-api service
consul acl policy create \
  -name "web-api-policy" \
  -rules @web-api-policy.hcl \
  -token "$MASTER_TOKEN"

# web-api-policy.hcl
# service "web-api" {
#   policy = "write"  # register, deregister, update checks
# }
# service_prefix "" {
#   policy = "read"   # discover all services
# }
# node_prefix "" {
#   policy = "read"   # read node info
# }

# Create a token using the policy
consul acl token create \
  -description "web-api service token" \
  -policy-name "web-api-policy" \
  -token "$MASTER_TOKEN"
```

### Consul Template — Dynamic Config Files

```bash
# Install consul-template
brew install consul-template  # or download binary

# Template file: nginx.conf.ctmpl
upstream backend {
{{ range service "web-api" }}
  server {{ .Address }}:{{ .Port }};
{{ end }}
}

# Run consul-template to regenerate nginx.conf whenever services change
consul-template \
  -template "nginx.conf.ctmpl:nginx.conf:nginx -s reload" \
  -once  # run once (or omit for continuous watch)
```

## Common Commands

```bash
consul members                            # List cluster members
consul catalog services                   # List all registered services
consul health service web-api             # Service health (passing instances)
consul health checks web-api-1            # Checks for a specific instance
consul kv get -recurse config/            # List all KV entries under prefix
consul intention list                     # List all Connect intentions
consul debug                              # Capture cluster debug bundle
consul validate /etc/consul.d/            # Validate config files
consul snapshot save backup.snap          # Save cluster state snapshot
consul snapshot restore backup.snap       # Restore from snapshot
```

## Pitfalls

- **ACL default-deny blocks everything**: when enabling ACLs with `default_policy = "deny"`, all services immediately lose the ability to register or discover other services — create and assign tokens before enabling ACLs in production
- **Gossip encryption is not automatic**: generate the gossip key with `consul keygen` and add it to all nodes' config; mismatched keys prevent cluster formation without useful error messages
- **DNS TTL and caching**: Consul DNS returns a very short TTL (by default 0s for health-aware responses); ensure clients don't cache DNS responses from upstream resolvers that may override this
- **Connect intentions are deny-all by default once Connect is enabled**: enabling Consul Connect without creating intentions for existing services breaks all service-to-service traffic silently at the sidecar layer
- **`bootstrap_expect` must match cluster size**: if set to 3 but only 2 servers start, the cluster never elects a leader — check this when recovering from node failures

## Related Skills

- `nomad` — workload orchestrator that integrates with Consul for service registration
- `hashicorp-vault` — secrets backend for Consul certificate management (CA)
- `opentofu` — provision Consul servers on cloud infrastructure
- `service-mesh-istio` — alternative service mesh approach (Istio vs Consul Connect)
- `cilium` — eBPF-based alternative for Kubernetes service mesh

## GitNexus Index

Index path: /Users/localuser/.claude/skills/consul/.gitnexus
Created: 2026-05-24
