---
name: prometheus-recording-rules
description: Prometheus recording rules — advanced metric pre-aggregation and alerting. Use this skill whenever the user needs to write Prometheus recording rules, optimize slow queries, pre-compute expensive metrics for dashboards, create multi-window burn rate alerts (Google SRE book), design SLO alerting rules, or tune Prometheus rule evaluation. Trigger for "recording rules", "PrometheusRule CRD", "rate() query slow", "SLO alerting", "multi-window multi-burn-rate", or "pre-aggregate prometheus metrics".
---

# Prometheus Recording Rules — Advanced Metric Aggregation

## Overview

Prometheus recording rules pre-compute expensive PromQL expressions and store the results as new time series. This solves two major problems: (1) slow dashboard queries that scan millions of data points, and (2) multi-window SLO alerting that requires complex expressions evaluated repeatedly. Recording rules run at a configurable evaluation interval and are stored like regular metrics.

## When to Use

- Dashboard queries that time out or take >2 seconds
- Computing request error rates, latency percentiles at multiple granularities
- Google SRE-style multi-window burn rate SLO alerts
- Cross-service aggregations that multiple teams query
- Reducing query load on Prometheus by pre-aggregating high-cardinality metrics

## File Structure

```yaml
# rules/recording-rules.yml
groups:
  - name: http_requests_aggregations
    interval: 30s  # evaluation interval (default: global evaluation_interval)
    rules:
      - record: job:http_requests_total:rate5m
        expr: rate(http_requests_total[5m])
      - record: job:http_errors_total:rate5m
        expr: rate(http_requests_total{status=~"5.."}[5m])
```

## Key Patterns

### Naming Convention

Recording rules follow the standard `level:metric:operations` convention:

```
<aggregation_level>:<metric_name>:<list_of_operations>
```

Examples:
- `job:http_requests_total:rate5m` — rate over 5m, grouped by job
- `job_handler:http_request_duration_seconds:p99_1h` — 99th percentile, 1h window, by job+handler
- `cluster:node_cpu_utilisation:mean5m` — cluster-level CPU mean

### Request Rate and Error Rate

```yaml
groups:
  - name: http.rules
    interval: 30s
    rules:
      # Total request rate per job and status code
      - record: job_status:http_requests_total:rate5m
        expr: |
          sum by (job, status) (
            rate(http_requests_total[5m])
          )

      # Error ratio per job (fraction of 5xx vs total)
      - record: job:http_error_ratio:rate5m
        expr: |
          sum by (job) (rate(http_requests_total{status=~"5.."}[5m]))
          /
          sum by (job) (rate(http_requests_total[5m]))

      # Availability (1 - error ratio) for SLO calculations
      - record: job:http_availability:rate5m
        expr: |
          1 - (
            sum by (job) (rate(http_requests_total{status=~"5.."}[5m]))
            /
            sum by (job) (rate(http_requests_total[5m]))
          )
```

### Latency Percentiles

```yaml
  - name: latency.rules
    rules:
      # 99th percentile latency per job and handler
      - record: job_handler:http_request_duration_seconds:p99_5m
        expr: |
          histogram_quantile(0.99,
            sum by (job, handler, le) (
              rate(http_request_duration_seconds_bucket[5m])
            )
          )

      - record: job_handler:http_request_duration_seconds:p95_5m
        expr: |
          histogram_quantile(0.95,
            sum by (job, handler, le) (
              rate(http_request_duration_seconds_bucket[5m])
            )
          )

      # Average latency
      - record: job:http_request_duration_seconds:mean5m
        expr: |
          sum by (job) (rate(http_request_duration_seconds_sum[5m]))
          /
          sum by (job) (rate(http_request_duration_seconds_count[5m]))
```

### SLO Alerting — Multi-Window Multi-Burn-Rate (Google SRE Book)

This is the most important use of recording rules. The idea: alert when you're burning through your error budget too fast, using two time windows to reduce noise.

```yaml
groups:
  # Pre-compute error rates at multiple windows for SLO burn rate alerting
  - name: slo_windows
    interval: 30s
    rules:
      # 5m window
      - record: job:http_error_ratio:rate5m
        expr: |
          sum by (job) (rate(http_requests_total{status=~"5.."}[5m]))
          / sum by (job) (rate(http_requests_total[5m]))

      # 30m window
      - record: job:http_error_ratio:rate30m
        expr: |
          sum by (job) (rate(http_requests_total{status=~"5.."}[30m]))
          / sum by (job) (rate(http_requests_total[30m]))

      # 1h window
      - record: job:http_error_ratio:rate1h
        expr: |
          sum by (job) (rate(http_requests_total{status=~"5.."}[1h]))
          / sum by (job) (rate(http_requests_total[1h]))

      # 6h window
      - record: job:http_error_ratio:rate6h
        expr: |
          sum by (job) (rate(http_requests_total{status=~"5.."}[6h]))
          / sum by (job) (rate(http_requests_total[6h]))

  # Multi-window burn rate alerts using the pre-computed recording rules
  # SLO: 99.9% availability (0.1% error budget)
  - name: slo_alerts
    rules:
      # Page now: burning 14x fast (consume budget in 1h)
      - alert: HighErrorBurnRateFast
        expr: |
          job:http_error_ratio:rate5m{job="api"} > (14.4 * 0.001)
          and
          job:http_error_ratio:rate1h{job="api"} > (14.4 * 0.001)
        for: 2m
        labels:
          severity: critical
          page: "true"
        annotations:
          summary: "High error burn rate (fast window)"
          description: "API error rate {{ $value | humanizePercentage }} is consuming error budget 14x faster than target"

      # Page now: burning 6x fast (consume budget in 6h)
      - alert: HighErrorBurnRateSlow
        expr: |
          job:http_error_ratio:rate30m{job="api"} > (6 * 0.001)
          and
          job:http_error_ratio:rate6h{job="api"} > (6 * 0.001)
        for: 15m
        labels:
          severity: critical
        annotations:
          summary: "Elevated error burn rate (slow window)"

      # Warn: burning 3x fast (consume budget in 3 days)
      - alert: ElevatedErrorBurnRate
        expr: |
          job:http_error_ratio:rate6h{job="api"} > (3 * 0.001)
        for: 1h
        labels:
          severity: warning
```

### Infrastructure Recording Rules

```yaml
  - name: node.rules
    rules:
      # CPU utilization per node
      - record: node:node_cpu_utilisation:avg1m
        expr: |
          1 - avg by (instance) (
            rate(node_cpu_seconds_total{mode="idle"}[1m])
          )

      # Memory utilization per node
      - record: node:node_memory_utilisation:ratio
        expr: |
          1 - (
            node_memory_MemFree_bytes + node_memory_Buffers_bytes + node_memory_Cached_bytes
          ) / node_memory_MemTotal_bytes

      # Disk I/O utilization
      - record: node:node_disk_io_utilisation:avg1m
        expr: |
          avg by (instance, device) (
            rate(node_disk_io_time_seconds_total[1m])
          )
```

### PrometheusRule CRD (Kubernetes/Operator)

```yaml
# With kube-prometheus-stack or prometheus-operator
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: my-app-recording-rules
  namespace: monitoring
  labels:
    prometheus: kube-prometheus  # must match prometheus operator selector
    role: alert-rules
spec:
  groups:
    - name: my-app.rules
      interval: 30s
      rules:
        - record: job:my_app_requests:rate5m
          expr: rate(my_app_http_requests_total[5m])
        - alert: MyAppHighErrorRate
          expr: job:http_error_ratio:rate5m{job="my-app"} > 0.05
          for: 5m
          labels:
            severity: warning
```

## Pitfalls

- **Recording rule staleness**: recording rules only produce a sample every `interval` seconds — if you need sub-30s resolution for alerts, reduce the interval (but more frequent evaluation = more CPU)
- **Missing data propagation**: if the underlying metric has gaps, recording rules produce no data for that window; this is correct but can cause alerts to not fire when expected
- **Long windows consume memory**: Prometheus needs to keep `[6h]` of data in RAM for a 6h window query; ensure your retention and memory are sized appropriately
- **Cardinality explosion**: avoid recording rules that produce high-cardinality output (many label combinations); use `sum by` judiciously to reduce cardinality
- **`rate()` inside `histogram_quantile`**: the correct pattern is `histogram_quantile(0.99, sum by (le) (rate(bucket[5m])))` — not wrapping `histogram_quantile` in `rate()`

## Related Skills

- `loki` — log aggregation in the Grafana stack
- `tempo` — distributed tracing in the Grafana stack
- `alloy` — OpenTelemetry collector that sends to Prometheus
- `observability-engineer` — broader observability strategy

## GitNexus Index

Index path: /Users/localuser/.claude/skills/prometheus-recording-rules/.gitnexus
Created: 2026-05-24
