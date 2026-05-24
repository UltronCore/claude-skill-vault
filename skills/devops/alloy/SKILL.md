---
name: alloy
description: Grafana Alloy — OpenTelemetry collector and telemetry pipeline for the Grafana stack. Use this skill whenever the user needs to collect metrics, logs, or traces with an OTel-native collector, replace Prometheus Agent or Promtail with a unified collector, configure Alloy to send to Loki/Tempo/Mimir/Prometheus, write River/Alloy configuration files, or set up a telemetry pipeline from Kubernetes. Trigger for "grafana alloy", "alloy collector", "River config", "replace promtail alloy", or "otel collector grafana".
---

# Grafana Alloy — Unified Telemetry Collector

## Overview

Grafana Alloy is an OpenTelemetry-native telemetry pipeline that replaces Prometheus Agent, Promtail, and Grafana Agent (now deprecated). It collects metrics, logs, traces, and profiles from any source and routes them to any destination — Prometheus, Loki, Tempo, Mimir, Grafana Cloud, or any OTLP-compatible backend. Alloy uses a component-based configuration language called River (`.alloy` files) where components are wired together with references, making the data flow explicit and auditable. It runs as a DaemonSet in Kubernetes for node-level collection or as a Deployment for centralized aggregation.

## When to Use

- Replacing Promtail (log collection) or Prometheus Agent (metric scraping) with a single binary
- Collecting OpenTelemetry traces, metrics, and logs and routing to Grafana Cloud or self-hosted Grafana stack
- Building complex telemetry pipelines with filtering, transformation, and batching
- Scraping Kubernetes metrics and forwarding to a remote Prometheus-compatible endpoint
- Auto-discovering Kubernetes pods and services for log/metric collection

## Installation

```bash
# Install with Helm (Kubernetes — collects from all nodes)
helm repo add grafana https://grafana.github.io/helm-charts
helm install alloy grafana/alloy \
  --namespace monitoring \
  --create-namespace \
  --set alloy.configMap.create=true \
  --set alloy.configMap.content="$(cat alloy-config.alloy)"

# Verify
kubectl get pods -n monitoring -l app.kubernetes.io/name=alloy
kubectl logs -n monitoring -l app.kubernetes.io/name=alloy --tail=20
```

## Key Patterns

### Basic Alloy Configuration — Metrics + Logs to Grafana Cloud

```river
// alloy-config.alloy
// Discover Kubernetes pods
discovery.kubernetes "pods" {
  role = "pod"
}

// Relabel: only collect pods with the annotation prometheus.io/scrape=true
discovery.relabel "pods_scrape" {
  targets = discovery.kubernetes.pods.targets

  rule {
    source_labels = ["__meta_kubernetes_pod_annotation_prometheus_io_scrape"]
    action        = "keep"
    regex         = "true"
  }

  rule {
    source_labels = ["__meta_kubernetes_pod_annotation_prometheus_io_path"]
    action        = "replace"
    target_label  = "__metrics_path__"
    regex         = "(.+)"
  }

  rule {
    source_labels = ["__meta_kubernetes_namespace"]
    target_label  = "namespace"
  }

  rule {
    source_labels = ["__meta_kubernetes_pod_label_app"]
    target_label  = "app"
  }
}

// Scrape discovered pods
prometheus.scrape "pods" {
  targets    = discovery.relabel.pods_scrape.output
  forward_to = [prometheus.remote_write.grafana_cloud.receiver]
  scrape_interval = "30s"
}

// Remote write metrics to Grafana Cloud (or Mimir/Prometheus)
prometheus.remote_write "grafana_cloud" {
  endpoint {
    url = env("GRAFANA_CLOUD_METRICS_URL")
    basic_auth {
      username = env("GRAFANA_CLOUD_USER")
      password = env("GRAFANA_CLOUD_API_KEY")
    }
  }
}
```

### Log Collection — Kubernetes Pod Logs

```river
// Discover pods for log collection
discovery.kubernetes "pods" {
  role = "pod"
}

// Relabel to add useful log labels
discovery.relabel "pod_logs" {
  targets = discovery.kubernetes.pods.targets

  rule {
    source_labels = ["__meta_kubernetes_pod_uid", "__meta_kubernetes_pod_container_name"]
    target_label  = "__path__"
    separator     = "/"
    replacement   = "/var/log/pods/*$1/*.log"
  }

  rule {
    source_labels = ["__meta_kubernetes_namespace"]
    target_label  = "namespace"
  }

  rule {
    source_labels = ["__meta_kubernetes_pod_name"]
    target_label  = "pod"
  }

  rule {
    source_labels = ["__meta_kubernetes_pod_container_name"]
    target_label  = "container"
  }

  rule {
    source_labels = ["__meta_kubernetes_pod_label_app"]
    target_label  = "app"
  }
}

// Tail log files from discovered pods
loki.source.file "pod_logs" {
  targets    = discovery.relabel.pod_logs.output
  forward_to = [loki.process.parse_logs.receiver]
}

// Process logs: parse JSON and drop debug-level entries
loki.process "parse_logs" {
  forward_to = [loki.write.grafana_cloud.receiver]

  stage.json {
    expressions = {
      level = "level",
      msg   = "message",
    }
  }

  stage.labels {
    values = {
      level = "",
    }
  }

  stage.match {
    selector = `{level="debug"}`
    action   = "drop"
  }
}

// Send logs to Loki / Grafana Cloud
loki.write "grafana_cloud" {
  endpoint {
    url = env("GRAFANA_CLOUD_LOGS_URL")
    basic_auth {
      username = env("GRAFANA_CLOUD_USER")
      password = env("GRAFANA_CLOUD_API_KEY")
    }
  }
}
```

### OTLP Traces — Receive and Forward to Tempo

```river
// Receive OTLP traces from services (gRPC + HTTP)
otelcol.receiver.otlp "default" {
  grpc {
    endpoint = "0.0.0.0:4317"
  }
  http {
    endpoint = "0.0.0.0:4318"
  }
  output {
    traces = [otelcol.processor.batch.default.input]
  }
}

// Batch before forwarding (reduces HTTP round-trips)
otelcol.processor.batch "default" {
  timeout = "5s"
  send_batch_size = 1000
  output {
    traces = [otelcol.exporter.otlp.tempo.input]
  }
}

// Export to Tempo
otelcol.exporter.otlp "tempo" {
  client {
    endpoint = "tempo.monitoring.svc.cluster.local:4317"
    tls {
      insecure = true
    }
  }
}
```

### Self-Monitoring — Alloy Metrics to Prometheus

```river
// Alloy exposes its own metrics at /metrics
prometheus.scrape "alloy_self" {
  targets = [{"__address__" = "localhost:12345"}]
  forward_to = [prometheus.remote_write.grafana_cloud.receiver]
  job_name = "alloy"
}
```

### Clustering (High-Availability Alloy)

```river
// Enable Alloy clustering for HA log/metric collection
// Each instance only scrapes a subset of targets

clustering {
  enabled = true
}

// With clustering enabled, prometheus.scrape distributes targets
// automatically across all Alloy instances — no duplicate scraping
prometheus.scrape "pods" {
  targets             = discovery.relabel.pods_scrape.output
  forward_to          = [prometheus.remote_write.mimir.receiver]
  clustering {
    enabled = true
  }
}
```

## Common Commands

```bash
# Check Alloy configuration syntax
alloy fmt alloy-config.alloy     # format
alloy run alloy-config.alloy     # run locally

# In Kubernetes: access Alloy UI (shows component graph)
kubectl port-forward -n monitoring svc/alloy 12345 &
# Visit http://localhost:12345 — shows live component wiring + health

# Check Alloy metrics
curl http://localhost:12345/metrics | grep alloy_

# Reload config without restart
kill -HUP $(pgrep alloy)

# View logs in Kubernetes
kubectl logs -n monitoring -l app.kubernetes.io/name=alloy -f
```

## Pitfalls

- **River syntax is whitespace-sensitive**: unlike HCL/YAML, River uses `=` for assignment but block labels use `"quoted"` strings — the Alloy LSP extension for VS Code helps catch syntax errors early
- **Prometheus scrape targets and clustering**: without `clustering { enabled = true }` in scrape components, every Alloy pod scrapes every target, causing duplicate metrics and double-counting
- **Log file paths on Kubernetes**: Alloy must run as a DaemonSet with `/var/log/pods` mounted as `hostPath` — if this volume mount is missing, `loki.source.file` finds no logs
- **OTLP receiver port conflicts**: if running alongside an OpenTelemetry Collector, they'll both try to bind 4317/4318 — run Alloy on alternate ports or replace the existing collector entirely
- **Environment variables for secrets**: never put API keys directly in `.alloy` files; use `env("VAR")` and mount secrets as environment variables via Kubernetes secrets

## Related Skills

- `loki` — log destination for Alloy
- `tempo` — trace destination for Alloy
- `prometheus-recording-rules` — metric destination for Alloy
- `observability-engineer` — full Grafana stack strategy
- `opentelemetry-instrumentation` — instrument services that send to Alloy

## GitNexus Index

Index path: /Users/localuser/.claude/skills/alloy/.gitnexus
Created: 2026-05-24
