---
name: opentelemetry-instrumentation
description: Instrument applications with OpenTelemetry for distributed tracing, metrics, and logs. Covers auto-instrumentation, manual spans, context propagation, and exporting to Jaeger, Tempo, or OTLP backends.
version: 1.0.0
tags: [opentelemetry, otel, tracing, distributed-tracing, observability, metrics, jaeger, tempo]
---

# OpenTelemetry Instrumentation

## Overview

This skill covers instrumenting applications with OpenTelemetry (OTel) — the vendor-neutral observability standard. It covers automatic instrumentation for popular frameworks, manual span creation for business logic, metric collection, log correlation, and exporting to any OTLP-compatible backend (Jaeger, Grafana Tempo, Honeycomb, DataDog, New Relic). Works for Python, Node.js, Go, and Java applications.

## When to Use

- Adding distributed tracing to a microservices architecture
- Debugging latency issues across service boundaries
- Migrating from Zipkin, Jaeger client libraries, or proprietary APM
- Correlating logs with trace IDs for unified observability
- Setting up SLO monitoring with custom metrics

## Step-by-Step Workflow

### 1. Python Auto-Instrumentation (Zero-Code)
```bash
pip install opentelemetry-distro opentelemetry-exporter-otlp
opentelemetry-bootstrap --action=install  # Installs all detected framework plugins

# Run with auto-instrumentation
OTEL_SERVICE_NAME=my-api \
OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4317 \
OTEL_TRACES_EXPORTER=otlp \
OTEL_METRICS_EXPORTER=otlp \
opentelemetry-instrument python app.py
```

### 2. Manual SDK Setup (Python)
```python
from opentelemetry import trace, metrics
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.exporter.otlp.proto.grpc.metric_exporter import OTLPMetricExporter
from opentelemetry.sdk.resources import Resource

def setup_telemetry(service_name: str):
    resource = Resource.create({
        "service.name": service_name,
        "service.version": "1.2.3",
        "deployment.environment": "production",
    })
    
    # Traces
    trace_exporter = OTLPSpanExporter(endpoint="http://localhost:4317")
    tracer_provider = TracerProvider(resource=resource)
    tracer_provider.add_span_processor(BatchSpanProcessor(trace_exporter))
    trace.set_tracer_provider(tracer_provider)
    
    # Metrics
    metric_exporter = OTLPMetricExporter(endpoint="http://localhost:4317")
    meter_provider = MeterProvider(
        resource=resource,
        metric_readers=[PeriodicExportingMetricReader(metric_exporter, export_interval_millis=60000)]
    )
    metrics.set_meter_provider(meter_provider)

setup_telemetry("order-service")
tracer = trace.get_tracer(__name__)
meter = metrics.get_meter(__name__)
```

### 3. Creating Spans and Adding Context
```python
from opentelemetry import trace
from opentelemetry.trace import StatusCode

tracer = trace.get_tracer(__name__)

def process_order(order_id: str, user_id: str):
    with tracer.start_as_current_span("process_order") as span:
        # Add semantic attributes
        span.set_attribute("order.id", order_id)
        span.set_attribute("user.id", user_id)
        span.set_attribute("order.source", "web")
        
        try:
            # Nested span for database call
            with tracer.start_as_current_span("db.fetch_order") as db_span:
                db_span.set_attribute("db.system", "postgresql")
                db_span.set_attribute("db.statement", "SELECT * FROM orders WHERE id = $1")
                order = fetch_from_db(order_id)
            
            with tracer.start_as_current_span("payment.charge") as pay_span:
                pay_span.set_attribute("payment.amount", order.total)
                pay_span.set_attribute("payment.currency", "USD")
                charge_result = charge_payment(order)
                pay_span.set_attribute("payment.transaction_id", charge_result.id)
            
            span.set_status(StatusCode.OK)
            return charge_result
            
        except PaymentError as e:
            span.set_status(StatusCode.ERROR, str(e))
            span.record_exception(e)
            raise
```

### 4. Custom Metrics
```python
from opentelemetry import metrics

meter = metrics.get_meter("order-service")

# Counter
orders_created = meter.create_counter(
    "orders.created",
    description="Number of orders created",
    unit="1",
)

# Histogram (for latency, sizes)
order_value = meter.create_histogram(
    "orders.value",
    description="Value of orders placed",
    unit="USD",
)

# UpDownCounter (for gauges that can go up/down)
active_carts = meter.create_up_down_counter(
    "carts.active",
    description="Currently active shopping carts",
)

# Usage
def create_order(order: Order):
    orders_created.add(1, {"region": "us-east-1", "channel": "web"})
    order_value.record(order.total, {"product_category": order.category})
    return save_order(order)
```

### 5. Node.js Instrumentation
```typescript
// src/instrumentation.ts — Must be first import
import { NodeSDK } from '@opentelemetry/sdk-node';
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-grpc';
import { OTLPMetricExporter } from '@opentelemetry/exporter-metrics-otlp-grpc';
import { PeriodicExportingMetricReader } from '@opentelemetry/sdk-metrics';
import { getNodeAutoInstrumentations } from '@opentelemetry/auto-instrumentations-node';
import { Resource } from '@opentelemetry/resources';
import { ATTR_SERVICE_NAME } from '@opentelemetry/semantic-conventions';

const sdk = new NodeSDK({
  resource: new Resource({ [ATTR_SERVICE_NAME]: 'api-gateway' }),
  traceExporter: new OTLPTraceExporter({ url: 'http://localhost:4317' }),
  metricReader: new PeriodicExportingMetricReader({
    exporter: new OTLPMetricExporter({ url: 'http://localhost:4317' }),
    exportIntervalMillis: 60000,
  }),
  instrumentations: [getNodeAutoInstrumentations({
    '@opentelemetry/instrumentation-fs': { enabled: false },
  })],
});

sdk.start();
process.on('SIGTERM', () => sdk.shutdown());
```

### 6. OTel Collector Configuration
```yaml
# otel-collector-config.yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318

processors:
  batch:
    timeout: 1s
    send_batch_size: 1024
  memory_limiter:
    limit_mib: 400

exporters:
  otlp/jaeger:
    endpoint: jaeger:4317
    tls:
      insecure: true
  prometheus:
    endpoint: "0.0.0.0:8889"

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [otlp/jaeger]
    metrics:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [prometheus]
```

## Key Commands Reference

```bash
# Install Python packages
pip install \
  opentelemetry-api \
  opentelemetry-sdk \
  opentelemetry-exporter-otlp \
  opentelemetry-instrumentation-fastapi \
  opentelemetry-instrumentation-sqlalchemy \
  opentelemetry-instrumentation-httpx

# Run OTel Collector with Docker
docker run -p 4317:4317 -p 4318:4318 \
  -v $(pwd)/otel-collector-config.yaml:/etc/otel-collector-config.yaml \
  otel/opentelemetry-collector:latest \
  --config=/etc/otel-collector-config.yaml

# Validate spans are arriving (Jaeger UI)
open http://localhost:16686

# Test OTLP export
grpcurl -plaintext -d '{}' localhost:4317 opentelemetry.proto.collector.trace.v1.TraceService/Export
```

## Common Patterns

### Pattern 1: Baggage for Cross-Service Context
```python
from opentelemetry.baggage import set_baggage, get_baggage
from opentelemetry.context import attach, detach

# In gateway service: set baggage that propagates to all downstream calls
ctx = set_baggage("user.tier", "premium")
ctx = set_baggage("request.id", request_id, context=ctx)
token = attach(ctx)
try:
    call_downstream_service()
finally:
    detach(token)

# In downstream service: read baggage
user_tier = get_baggage("user.tier")
```

### Pattern 2: Sampling Strategy
```python
from opentelemetry.sdk.trace.sampling import (
    ParentBased, TraceIdRatioBased, ALWAYS_ON
)

# Sample 10% of traces, but always sample errors
sampler = ParentBased(
    root=TraceIdRatioBased(0.1),
    remote_parent_sampled=ALWAYS_ON,  # Honor upstream sampling decision
)
tracer_provider = TracerProvider(sampler=sampler, resource=resource)
```

### Pattern 3: Log Correlation
```python
import logging
from opentelemetry import trace

class TraceContextFilter(logging.Filter):
    def filter(self, record):
        span = trace.get_current_span()
        ctx = span.get_span_context()
        if ctx.is_valid:
            record.trace_id = format(ctx.trace_id, '032x')
            record.span_id = format(ctx.span_id, '016x')
        else:
            record.trace_id = "0" * 32
            record.span_id = "0" * 16
        return True

logging.getLogger().addFilter(TraceContextFilter())
# Now logs contain trace_id and span_id for correlation
```

## Pitfalls to Avoid

1. **Not batching spans**: Sending every span individually creates high network overhead. Always use `BatchSpanProcessor` in production — never `SimpleSpanProcessor`. Configure `max_export_batch_size=512` and `schedule_delay_millis=5000` for throughput optimization.

2. **Cardinality explosion in metrics**: Adding high-cardinality labels (like `user_id`, `request_path` with IDs) to metrics creates millions of metric series, killing Prometheus/Thanos. Use only low-cardinality labels: `method`, `status_code`, `region`, `service`. High-cardinality data belongs in traces.

3. **Missing context propagation in async code**: When spawning threads or async tasks, the OTel context does not propagate automatically in Python. Use `copy_context()` and `Context.attach()` to manually propagate: `ctx = copy_context(); executor.submit(ctx.run, fn, arg)`.

## Related Skills

- `sentry-and-otel-setup` — Combining error tracking with OTel
- `go-microservices` — OTel setup for Go services
- `kafka-event-streaming` — Propagating trace context through Kafka messages
- `kubernetes-architect` — Deploying OTel Collector as a DaemonSet

## GitNexus Index

```json
{
  "skill": "opentelemetry-instrumentation",
  "category": "devops",
  "triggers": ["opentelemetry", "otel", "distributed tracing", "spans", "jaeger", "tempo", "observability", "instrumentation"],
  "outputs": ["traces", "metrics", "spans", "collector config", "instrumented service"],
  "complexity": "medium",
  "tools": ["opentelemetry", "jaeger", "grafana-tempo", "prometheus", "otel-collector"]
}
```
