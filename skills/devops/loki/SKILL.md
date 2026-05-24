---
name: loki
description: Loki — log aggregation and querying in the Grafana observability stack. Use this skill whenever the user needs to aggregate logs from Kubernetes pods or containers, write LogQL queries, set up Promtail or Alloy log collection, configure log retention and storage, alert on log patterns, or integrate logs with Grafana dashboards. Trigger for "loki", "LogQL", "Promtail", "log aggregation grafana", "kubernetes log collection", or "grafana logs".
---

# Loki — Log Aggregation for the Grafana Stack

## Overview

Grafana Loki is a horizontally scalable, highly available log aggregation system built for cost efficiency. Unlike Elasticsearch, Loki indexes only metadata labels (not log content), making storage far cheaper. Log content is compressed and stored in object storage (S3, GCS, etc.). Logs are queried via LogQL — a query language modeled after PromQL — and rendered in Grafana. Loki integrates natively with Prometheus metrics and Tempo traces, forming the core of the Grafana observability stack.

## When to Use

- Aggregating logs from Kubernetes pods, nodes, or systemd services
- Querying log content with label-based filtering and regex
- Alerting on log patterns (errors, anomalies) via ruler
- Correlating logs with metrics in Grafana dashboards
- Cost-sensitive environments where Elasticsearch is too expensive
- Replacing ELK/EFK stack with lighter infrastructure

## Installation

```bash
# Install Loki with Helm (single-binary mode for small clusters)
helm repo add grafana https://grafana.github.io/helm-charts
helm install loki grafana/loki \
  --namespace monitoring \
  --create-namespace \
  --set loki.commonConfig.replication_factor=1 \
  --set loki.storage.type=filesystem \
  --set singleBinary.replicas=1

# For production: distributed mode with S3
helm install loki grafana/loki \
  --namespace monitoring \
  --values loki-values.yaml

# Install Promtail (log collector agent)
helm install promtail grafana/promtail \
  --namespace monitoring \
  --set "loki.serviceName=loki"

# Verify
kubectl get pods -n monitoring -l app=loki
```

## Key Patterns

### Loki Production Configuration (S3 Backend)

```yaml
# loki-values.yaml
loki:
  auth_enabled: false
  commonConfig:
    replication_factor: 3
  storage:
    type: s3
    s3:
      region: us-east-1
      bucketnames: my-loki-logs
      s3forcepathstyle: false
  schemaConfig:
    configs:
      - from: "2024-01-01"
        store: tsdb
        object_store: s3
        schema: v13
        index:
          prefix: loki_index_
          period: 24h
  limits_config:
    retention_period: 30d
    ingestion_rate_mb: 16
    ingestion_burst_size_mb: 32
    max_query_series: 5000

# Compactor for retention enforcement
compactor:
  retention_enabled: true
  delete_request_store: s3
```

### Promtail Configuration — Kubernetes Pod Log Collection

```yaml
# promtail-config.yaml (mounted as ConfigMap)
server:
  http_listen_port: 3101

clients:
  - url: http://loki.monitoring.svc.cluster.local:3100/loki/api/v1/push

scrape_configs:
  - job_name: kubernetes-pods
    kubernetes_sd_configs:
      - role: pod
    pipeline_stages:
      # Parse JSON logs (common for structured logging)
      - json:
          expressions:
            level: level
            msg: message
            ts: timestamp
      # Set log level as a label for fast filtering
      - labels:
          level:
      # Drop debug logs to save storage
      - match:
          selector: '{level="debug"}'
          action: drop
    relabel_configs:
      # Use pod labels as Loki labels (keep cardinality low!)
      - source_labels: [__meta_kubernetes_pod_label_app]
        target_label: app
      - source_labels: [__meta_kubernetes_namespace]
        target_label: namespace
      - source_labels: [__meta_kubernetes_pod_name]
        target_label: pod
      - source_labels: [__meta_kubernetes_container_name]
        target_label: container
```

### LogQL — Filtering and Parsing

```logql
# Basic label filter — all logs from the api-server app in production
{app="api-server", namespace="production"}

# Regex filter on log content
{app="api-server"} |= "error" != "timeout"

# Filter by regex pattern
{app="api-server"} |~ "status=(4|5)[0-9]{2}"

# Parse JSON logs and filter by extracted field
{app="api-server"} | json | level="error" | line_format "{{.msg}}"

# Parse logfmt logs
{app="nginx"} | logfmt | status >= 500

# Pattern parser (faster than regex for common formats)
{app="nginx"} | pattern `<ip> - - [<_>] "<method> <uri> <_>" <status> <bytes>`
  | status >= 500
```

### LogQL — Metric Queries

```logql
# Error rate over 5 minutes (for Grafana panels)
sum(rate({app="api-server"} |= "error" [5m])) by (namespace)

# Request rate parsed from JSON
sum(rate({app="api-server"} | json | status != "" [5m])) by (status)

# 99th percentile latency from JSON logs
quantile_over_time(0.99,
  {app="api-server"}
  | json
  | unwrap duration_ms [5m]
) by (handler)

# Count errors per minute with rate
sum by (app) (
  rate({namespace="production"} |= "level=error" [1m])
)
```

### Loki Ruler — Alerting on Logs

```yaml
# loki-ruler.yaml
ruler:
  storage:
    type: local
    local:
      directory: /rules
  rule_path: /tmp/rules
  alertmanager_url: http://alertmanager:9093
  enable_api: true

# rules/alerts.yaml
groups:
  - name: log-alerts
    rules:
      - alert: HighErrorRate
        expr: |
          sum(rate({app="api-server"} |= "error" [5m])) by (namespace) > 0.1
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High error rate in {{ $labels.namespace }}"

      - alert: PodCrashLooping
        expr: |
          sum(count_over_time({namespace="production"} |= "Back-off restarting failed container" [10m])) > 5
        labels:
          severity: critical
```

### Grafana — Log Dashboard Panel

```json
{
  "type": "logs",
  "datasource": "Loki",
  "targets": [
    {
      "expr": "{app=\"$app\", namespace=\"$namespace\"} |= \"$search\"",
      "legendFormat": ""
    }
  ],
  "options": {
    "dedupStrategy": "signature",
    "showLabels": false,
    "sortOrder": "Descending",
    "wrapLogMessage": true
  }
}
```

## Common Commands

```bash
# Query logs via Loki HTTP API
curl -G "http://loki:3100/loki/api/v1/query_range" \
  --data-urlencode 'query={app="api-server"} |= "error"' \
  --data-urlencode 'start=1h ago' \
  --data-urlencode 'limit=100'

# Using logcli (Loki CLI)
logcli query '{app="api-server"}' --since=1h --limit=50
logcli series '{app="api-server"}' --since=1h
logcli labels  # list all label names

# Check Loki health
curl http://loki:3100/ready
curl http://loki:3100/metrics | grep loki_ingester

# Check Promtail targets
kubectl port-forward -n monitoring svc/promtail 3101 &
curl http://localhost:3101/targets
```

## Pitfalls

- **High cardinality labels**: never use pod IDs, request IDs, or IP addresses as Loki labels — they create millions of streams and destroy performance. Use only low-cardinality labels like `app`, `namespace`, `env`
- **Missing retention config**: Loki stores forever by default; always set `retention_period` in `limits_config` and enable compactor retention
- **LogQL `|= "text"` is a line filter, not a label filter**: `|=` scans log lines (fast but not instant); pre-filter with labels `{app="x"}` before adding line filters
- **`unwrap` requires numeric fields**: `quantile_over_time` needs `| unwrap <field>` where `<field>` parses to a number — ensure your log format emits numeric durations, not strings like "100ms"
- **Single-binary mode is not HA**: the `singleBinary` Helm mode is for testing; production needs the `distributed` or `simple-scalable` mode with separate read/write paths

## Related Skills

- `tempo` — distributed tracing (correlate with Loki logs)
- `prometheus-recording-rules` — metrics alongside log aggregation
- `alloy` — OpenTelemetry collector that sends to Loki
- `observability-engineer` — full Grafana stack strategy
- `falco` — runtime security events can be exported to Loki

## GitNexus Index

Index path: /Users/localuser/.claude/skills/loki/.gitnexus
Created: 2026-05-24
