---
name: nomad
description: HashiCorp Nomad — flexible workload orchestrator for containers, VMs, and binaries. Use this skill whenever the user needs to schedule jobs on bare-metal or cloud VMs without Kubernetes, run non-containerized workloads (Java JARs, raw binaries), orchestrate batch jobs alongside services, configure Nomad job specs, set up Nomad clusters, or migrate from cron/Kubernetes to Nomad. Trigger for "nomad job", "nomad scheduler", "nomad cluster", "hashicorp nomad", "orchestrate non-docker workloads", or "nomad vs kubernetes".
---

# Nomad — Flexible Workload Orchestrator

## Overview

HashiCorp Nomad is a flexible, high-performance workload orchestrator that schedules containers (Docker, Podman), virtual machines, Java apps, and raw binaries on any infrastructure. Unlike Kubernetes, Nomad is a single binary with no mandatory dependencies — it can manage batch jobs, services, and system tasks in a single cluster without requiring etcd, CoreDNS, or a container runtime. Nomad integrates natively with Consul (service discovery), Vault (secrets), and Terraform (infrastructure provisioning) in the HashiCorp ecosystem.

## When to Use

- Scheduling non-containerized workloads (JARs, Python scripts, binaries) alongside Docker services
- Running batch jobs with dependencies (fan-in/fan-out DAGs)
- Simpler Kubernetes alternative for teams that don't need the full K8s ecosystem
- Heterogeneous infrastructure (mix of bare-metal, cloud VMs, and edge devices)
- High-throughput batch processing with Nomad's parameterized jobs
- Multi-region deployments with built-in federation

## Installation

```bash
# macOS
brew tap hashicorp/tap
brew install hashicorp/tap/nomad

# Linux (Ubuntu/Debian)
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt install nomad

# Start a dev cluster (single node, ephemeral)
nomad agent -dev &

# Verify
nomad status
nomad node status
```

## Key Patterns

### Service Job — Docker Container

```hcl
# web-service.nomad.hcl
job "web-api" {
  datacenters = ["dc1"]
  type        = "service"  # long-running service

  update {
    max_parallel      = 1
    min_healthy_time  = "10s"
    healthy_deadline  = "3m"
    progress_deadline = "10m"
    auto_revert       = true  # roll back if unhealthy
  }

  group "api" {
    count = 3  # 3 instances

    # Spread across distinct hosts
    spread {
      attribute = "${node.unique.id}"
    }

    network {
      port "http" {
        to = 8080  # container port; Nomad assigns host port dynamically
      }
    }

    # Register with Consul service discovery
    service {
      name = "web-api"
      port = "http"
      tags = ["api", "v2"]

      check {
        type     = "http"
        path     = "/healthz"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "server" {
      driver = "docker"

      config {
        image = "my-registry.io/web-api:v1.2.0"
        ports = ["http"]
      }

      # Fetch secrets from Vault
      template {
        data = <<EOT
{{ with secret "secret/data/web-api/prod" }}
DATABASE_URL={{ .Data.data.database_url }}
API_KEY={{ .Data.data.api_key }}
{{ end }}
EOT
        destination = "secrets/env"
        env         = true  # inject as environment variables
      }

      resources {
        cpu    = 500   # 500 MHz
        memory = 512   # 512 MB
      }
    }
  }
}
```

### Batch Job — Data Processing

```hcl
job "data-processor" {
  datacenters = ["dc1"]
  type        = "batch"

  group "process" {
    count = 5  # run 5 parallel tasks

    task "worker" {
      driver = "docker"

      config {
        image   = "my-registry.io/processor:latest"
        command = "/app/process"
        args    = ["--input", "${NOMAD_META_input_bucket}", "--output", "${NOMAD_META_output_bucket}"]
      }

      resources {
        cpu    = 2000
        memory = 2048
      }
    }
  }

  # Constraints: only run on nodes with GPU
  constraint {
    attribute = "${node.class}"
    value     = "gpu-worker"
  }
}
```

### Parameterized Job — On-Demand Dispatch

```hcl
# Define a job template; dispatch it with custom payload per invocation
job "report-generator" {
  datacenters = ["dc1"]
  type        = "batch"

  parameterized {
    payload       = "optional"  # or "required"
    meta_required = ["report_type", "date_range"]
    meta_optional = ["output_format"]
  }

  group "generate" {
    task "generator" {
      driver = "exec"  # raw binary, no container

      config {
        command = "/usr/local/bin/generate-report"
        args    = [
          "--type", "${NOMAD_META_report_type}",
          "--range", "${NOMAD_META_date_range}",
          "--format", "${NOMAD_META_output_format}",
        ]
      }

      resources {
        cpu    = 1000
        memory = 1024
      }
    }
  }
}
```

```bash
# Dispatch the parameterized job
nomad job dispatch -meta report_type=sales -meta date_range=2024-01 report-generator
```

### System Job — Run on Every Node

```hcl
# System jobs run exactly one allocation per eligible node (like DaemonSet)
job "log-collector" {
  datacenters = ["dc1"]
  type        = "system"

  group "collector" {
    task "alloy" {
      driver = "docker"

      config {
        image        = "grafana/alloy:latest"
        network_mode = "host"  # access host network for log collection
        volumes = [
          "/var/log:/var/log:ro",
          "/var/lib/docker/containers:/var/lib/docker/containers:ro",
        ]
      }

      resources {
        cpu    = 200
        memory = 256
      }
    }
  }
}
```

### Consul Integration — Service Discovery

```hcl
# Services registered in Nomad are automatically discoverable via Consul DNS
# e.g., web-api.service.consul resolves to healthy instances

service {
  name     = "web-api"
  port     = "http"
  provider = "consul"  # or "nomad" for built-in provider

  tags = ["traefik.enable=true", "traefik.http.routers.web-api.rule=Host(`api.example.com`)"]

  check {
    type     = "http"
    path     = "/healthz"
    interval = "10s"
    timeout  = "2s"
  }

  # Sidecar proxy for Consul Connect (service mesh)
  connect {
    sidecar_service {
      proxy {
        upstreams {
          destination_name = "postgres"
          local_bind_port  = 5432
        }
      }
    }
  }
}
```

## Common Commands

```bash
nomad job run web-service.nomad.hcl       # Deploy a job
nomad job status web-api                   # Job status + allocation list
nomad job plan web-service.nomad.hcl      # Dry-run, show what would change
nomad job stop web-api                     # Stop a job (keeps history)
nomad job stop -purge web-api              # Stop and delete job history
nomad alloc logs <alloc-id>               # Tail stdout/stderr of an allocation
nomad alloc exec <alloc-id> /bin/sh       # Shell into a running allocation
nomad node status                          # List cluster nodes
nomad node drain -enable <node-id>        # Drain a node before maintenance
nomad operator debug                       # Capture full cluster debug bundle
```

## Pitfalls

- **Dynamic ports**: Nomad assigns random host ports by default — use the `to` field in `network` blocks and reference `${NOMAD_PORT_http}` in your app, or configure a load balancer like Traefik to pick up Consul service registrations
- **`exec` driver requires root or specific capabilities**: the `exec` driver runs processes directly on the host; it requires privileged access and is not suitable for untrusted workloads — use `docker` or `java` drivers for isolated execution
- **Allocation stickiness**: Nomad by default may reschedule allocations to different nodes on restart — use `sticky = true` in the `volume` block for stateful workloads, or use CSI volumes for persistent storage
- **Job version history**: Nomad keeps all job versions by default; use `vault_token` rotation carefully since old versions may hold stale tokens
- **Consul Connect requires CNI plugins**: the Consul Connect sidecar feature (L4 service mesh) requires CNI network plugins to be installed on Nomad client nodes, which is easy to miss when setting up new clients

## Related Skills

- `consul` — service discovery and mesh that pairs with Nomad
- `hashicorp-vault` — secrets management integrated with Nomad templates
- `opentofu` — provision the Nomad cluster infrastructure
- `packer` — build base images for Nomad client nodes
- `kubernetes-architect` — compare Nomad vs K8s for workload orchestration

## GitNexus Index

Index path: /Users/localuser/.claude/skills/nomad/.gitnexus
Created: 2026-05-24
