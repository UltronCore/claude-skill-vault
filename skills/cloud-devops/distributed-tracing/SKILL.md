---
name: distributed-tracing
description: Instrument microservices with distributed tracing using OpenTelemetry, Jaeger, and Tempo. Covers span creation, context propagation, sampling strategies, trace-to-log correlation, and building service dependency maps from trace data.
version: 1.0.0
tags: [distributed-tracing, opentelemetry, jaeger, tempo, spans, context-propagation, observability, python, nodejs]
---

# Distributed Tracing

## Overview

Distributed tracing tracks a request across multiple services by attaching a trace ID that propagates through HTTP headers, message queues, and async calls. Each service creates spans — timed segments with metadata — that are collected into a trace timeline showing exactly where latency comes from. OpenTelemetry (OTel) is the vendor-neutral standard for instrumentation; Jaeger and Grafana Tempo are common backends for storage and visualization.

## When to Use

- Debugging high latency in microservices where logs alone don't reveal which service is slow
- Understanding service dependency graphs and call chains
- Finding N+1 query problems and slow database calls in production
- Correlating a specific user's failing request across 5+ services
- SLA violation investigation: which service broke the 200ms budget
- Capacity planning: identify the slowest percentile paths in your architecture

## Step-by-Step Workflow

### 1. OpenTelemetry Setup (Python)

```python
# pip install opentelemetry-sdk opentelemetry-exporter-otlp opentelemetry-instrumentation-fastapi
# pip install opentelemetry-instrumentation-httpx opentelemetry-instrumentation-sqlalchemy

from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.resources import Resource, SERVICE_NAME

def setup_tracing(service_name: str, otlp_endpoint: str = "http://localhost:4317"):
    """Initialize OpenTelemetry tracing with OTLP export to Jaeger/Tempo."""
    resource = Resource.create({SERVICE_NAME: service_name})
    provider = TracerProvider(resource=resource)

    exporter = OTLPSpanExporter(endpoint=otlp_endpoint, insecure=True)
    provider.add_span_processor(BatchSpanProcessor(exporter))

    trace.set_tracer_provider(provider)
    return trace.get_tracer(service_name)

# Auto-instrument FastAPI (captures all requests automatically)
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.instrumentation.httpx import HTTPXClientInstrumentor
from opentelemetry.instrumentation.sqlalchemy import SQLAlchemyInstrumentor

tracer = setup_tracing("order-service")

from fastapi import FastAPI
app = FastAPI()
FastAPIInstrumentor.instrument_app(app)  # Auto: request/response spans
HTTPXClientInstrumentor().instrument()    # Auto: outbound HTTP spans
SQLAlchemyInstrumentor().instrument()     # Auto: DB query spans

# Manual span creation for business logic
from opentelemetry import trace
from opentelemetry.trace import Status, StatusCode

tracer = trace.get_tracer(__name__)

async def process_order(order_id: str, user_id: str):
    with tracer.start_as_current_span("process_order") as span:
        # Add business-relevant attributes
        span.set_attribute("order.id", order_id)
        span.set_attribute("user.id", user_id)
        span.set_attribute("order.service", "order-processor")

        try:
            # Nested spans for sub-operations
            with tracer.start_as_current_span("validate_inventory") as inv_span:
                result = await check_inventory(order_id)
                inv_span.set_attribute("inventory.available", result["available"])

            with tracer.start_as_current_span("charge_payment") as pay_span:
                payment = await charge(order_id, result["total"])
                pay_span.set_attribute("payment.id", payment["id"])
                pay_span.set_attribute("payment.amount", result["total"])

            span.set_status(Status(StatusCode.OK))
            return payment

        except Exception as e:
            # Record exception in span
            span.record_exception(e)
            span.set_status(Status(StatusCode.ERROR, str(e)))
            raise
```

### 2. Context Propagation Across Services

```python
# Trace context propagates via HTTP headers automatically with OTel instrumentation
# Manual propagation when needed (e.g., message queues)

from opentelemetry import trace, propagate
from opentelemetry.trace.propagation.tracecontext import TraceContextTextMapPropagator

# Inject trace context into message headers (for Kafka, SQS, etc.)
def inject_trace_to_headers(headers: dict) -> dict:
    """Add W3C trace context headers for propagation."""
    propagator = TraceContextTextMapPropagator()
    propagator.inject(headers)
    return headers

# Extract trace context from incoming message
def extract_trace_from_headers(headers: dict):
    """Resume the trace from an incoming message."""
    propagator = TraceContextTextMapPropagator()
    ctx = propagator.extract(headers)
    return ctx

# Usage with Kafka consumer
from confluent_kafka import Consumer

def process_kafka_message(msg):
    # Extract trace context from message headers
    headers = dict(msg.headers() or [])
    ctx = extract_trace_from_headers(headers)

    # Start a new span that's a child of the original trace
    with tracer.start_as_current_span("process_order_event", context=ctx) as span:
        span.set_attribute("kafka.topic", msg.topic())
        span.set_attribute("kafka.partition", msg.partition())
        payload = json.loads(msg.value())
        span.set_attribute("order.id", payload["order_id"])
        # Process...

# When producing messages, inject context
def produce_kafka_message(producer, topic: str, payload: dict):
    headers = {}
    inject_trace_to_headers(headers)
    producer.produce(topic, json.dumps(payload).encode(), headers=list(headers.items()))
```

### 3. Node.js Auto-Instrumentation

```typescript
// tracing.ts — must be required BEFORE any other imports
import { NodeSDK } from "@opentelemetry/sdk-node";
import { OTLPTraceExporter } from "@opentelemetry/exporter-trace-otlp-grpc";
import { Resource } from "@opentelemetry/resources";
import { SEMRESATTRS_SERVICE_NAME } from "@opentelemetry/semantic-conventions";
import { getNodeAutoInstrumentations } from "@opentelemetry/auto-instrumentations-node";

const exporter = new OTLPTraceExporter({
  url: process.env.OTLP_ENDPOINT ?? "http://localhost:4317",
});

const sdk = new NodeSDK({
  resource: new Resource({
    [SEMRESATTRS_SERVICE_NAME]: process.env.SERVICE_NAME ?? "my-service",
  }),
  traceExporter: exporter,
  // Auto-instruments: http, express, fastify, pg, redis, grpc, aws-sdk...
  instrumentations: [getNodeAutoInstrumentations({
    "@opentelemetry/instrumentation-fs": { enabled: false }, // Too noisy
  })],
});

sdk.start();
process.on("SIGTERM", () => sdk.shutdown());

// Usage: custom spans in business logic
import { trace, context, SpanStatusCode } from "@opentelemetry/api";

const tracer = trace.getTracer("checkout-service");

export async function processCheckout(cartId: string, userId: string) {
  return tracer.startActiveSpan("checkout.process", async (span) => {
    span.setAttribute("cart.id", cartId);
    span.setAttribute("user.id", userId);
    try {
      const order = await createOrder(cartId, userId);
      span.setAttribute("order.id", order.id);
      span.setStatus({ code: SpanStatusCode.OK });
      return order;
    } catch (err) {
      span.recordException(err as Error);
      span.setStatus({ code: SpanStatusCode.ERROR });
      throw err;
    } finally {
      span.end();
    }
  });
}
```

### 4. Jaeger + Tempo Docker Setup

```yaml
# docker-compose.yml — full tracing stack
version: "3.8"
services:
  jaeger:
    image: jaegertracing/all-in-one:1.55
    ports:
      - "16686:16686"   # Jaeger UI
      - "4317:4317"     # OTLP gRPC
      - "4318:4318"     # OTLP HTTP
    environment:
      COLLECTOR_OTLP_ENABLED: "true"

  # Grafana Tempo (alternative to Jaeger, integrates with Grafana)
  tempo:
    image: grafana/tempo:latest
    command: ["-config.file=/etc/tempo.yaml"]
    volumes:
      - ./tempo.yaml:/etc/tempo.yaml
    ports:
      - "3200:3200"   # Tempo HTTP API
      - "4317:4317"   # OTLP gRPC (use instead of jaeger)

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    environment:
      GF_AUTH_ANONYMOUS_ENABLED: "true"
    volumes:
      - ./grafana-datasources.yaml:/etc/grafana/provisioning/datasources/datasources.yaml
```

```yaml
# tempo.yaml
server:
  http_listen_port: 3200
distributor:
  receivers:
    otlp:
      protocols:
        grpc:
          endpoint: 0.0.0.0:4317
ingester:
  max_block_duration: 5m
compactor:
  compaction:
    block_retention: 48h
storage:
  trace:
    backend: local
    local:
      path: /tmp/tempo/blocks
```

### 5. Sampling Strategies

```python
# Sampling reduces trace volume in high-traffic production systems
from opentelemetry.sdk.trace.sampling import (
    TraceIdRatioBased,
    ParentBased,
    ALWAYS_ON,
    ALWAYS_OFF,
)
from opentelemetry.sdk.trace import TracerProvider

# Always sample 10% of traces (tail-based sampling)
ratio_sampler = ParentBased(root=TraceIdRatioBased(0.1))

# Custom sampler: always sample errors and slow requests
from opentelemetry.sdk.trace.sampling import Sampler, Decision, SamplingResult
from opentelemetry.trace import SpanKind
from opentelemetry.util.types import Attributes

class SmartSampler(Sampler):
    """Always sample: errors, slow endpoints, admin routes. Sample 1% of normal traffic."""

    def should_sample(self, parent_context, trace_id, name, kind, attributes, links) -> SamplingResult:
        attrs = attributes or {}

        # Always sample error-prone or critical paths
        if (attrs.get("http.route", "").startswith("/admin") or
            attrs.get("http.route", "") in ["/checkout", "/payment"]):
            return SamplingResult(Decision.RECORD_AND_SAMPLE)

        # 1% sample rate for everything else
        if (trace_id & 0xFFFF) < 0x028F:  # ~1%
            return SamplingResult(Decision.RECORD_AND_SAMPLE)

        return SamplingResult(Decision.DROP)

    def get_description(self) -> str:
        return "SmartSampler"

provider = TracerProvider(sampler=SmartSampler())
```

### 6. Trace-to-Log Correlation

```python
# Add trace IDs to log records for correlation in Grafana/Datadog/Loki

import logging
import structlog
from opentelemetry import trace

class TraceContextProcessor:
    """Add OpenTelemetry trace/span IDs to every log record."""

    def __call__(self, logger, method, event_dict):
        span = trace.get_current_span()
        if span.is_recording():
            ctx = span.get_span_context()
            event_dict["trace_id"] = format(ctx.trace_id, "032x")
            event_dict["span_id"] = format(ctx.span_id, "016x")
            event_dict["trace_flags"] = ctx.trace_flags
        return event_dict

structlog.configure(
    processors=[
        structlog.stdlib.add_log_level,
        structlog.stdlib.add_logger_name,
        TraceContextProcessor(),
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.JSONRenderer(),
    ]
)

log = structlog.get_logger()

async def process_order(order_id: str):
    with tracer.start_as_current_span("process_order") as span:
        span.set_attribute("order.id", order_id)
        # Log will automatically include trace_id and span_id
        log.info("processing_order", order_id=order_id)
        # In Grafana: click "View in Traces" from log line -> jump to trace
```

## Key Commands Reference

```bash
# Install OTel for Python
pip install opentelemetry-sdk opentelemetry-exporter-otlp opentelemetry-instrumentation-fastapi
pip install opentelemetry-instrumentation-httpx opentelemetry-instrumentation-sqlalchemy opentelemetry-instrumentation-redis

# Install OTel for Node.js
npm install @opentelemetry/sdk-node @opentelemetry/auto-instrumentations-node @opentelemetry/exporter-trace-otlp-grpc

# Start Jaeger (all-in-one for dev)
docker run -d --name jaeger -p 16686:16686 -p 4317:4317 -p 4318:4318 jaegertracing/all-in-one:1.55

# View traces: http://localhost:16686

# Send a test trace
curl -X POST http://localhost:4318/v1/traces \
  -H "Content-Type: application/json" \
  -d @test-trace.json

# OTel Collector (prod: receives, processes, exports)
docker run otel/opentelemetry-collector-contrib --config /etc/otel-config.yaml

# Query Tempo traces via API
curl "http://localhost:3200/api/traces/{traceId}"

# Trace sampling diagnostics
# Look for "sampled" flag in W3C traceparent header: 00-{traceId}-{spanId}-01 (01=sampled)
```

## Common Patterns

### Pattern 1: Service Graph from Traces

```python
# Build a dependency graph from trace data
from collections import defaultdict
import httpx

async def get_service_graph(tempo_url: str, time_range_hours: int = 1) -> dict:
    """Query Tempo for service-to-service call counts."""
    # Tempo's service graph API (requires Tempo 1.5+)
    response = await httpx.get(
        f"{tempo_url}/api/services",
        params={"start": int(__import__("time").time()) - time_range_hours * 3600}
    )
    return response.json()
```

### Pattern 2: Span Events for State Transitions

```python
# Use span events (timestamped annotations) for state changes
with tracer.start_as_current_span("order_fulfillment") as span:
    span.add_event("inventory_reserved", {"warehouse.id": "wh-1"})
    await reserve_inventory(order_id)

    span.add_event("payment_charged", {"payment.method": "card"})
    await charge_payment(order_id)

    span.add_event("shipping_scheduled", {"carrier": "fedex", "days": 3})
    await schedule_shipping(order_id)
```

### Pattern 3: Baggage for Cross-Service Metadata

```python
# Baggage propagates key-value metadata alongside trace context
from opentelemetry.baggage import set_baggage, get_baggage
from opentelemetry import context

# Set baggage in inbound request
ctx = set_baggage("user.tier", "gold")
ctx = set_baggage("experiment.id", "ab-test-checkout-v2", context=ctx)
token = context.attach(ctx)

# Any downstream service can read it
tier = get_baggage("user.tier")  # "gold" — available in all child spans
```

## Pitfalls to Avoid

1. **Head-based sampling loses error traces**: If you sample 1% at the start of a request, you'll miss 99% of errors since you don't know if a request will fail until it's complete. Use tail-based sampling (OpenTelemetry Collector's `tail_sampling` processor) which buffers spans and decides after the fact — keeping all errors.

2. **Propagating trace context through async queues manually**: Forgetting to inject and extract W3C trace context headers in Kafka/SQS messages breaks trace continuity. Every span from the consumer will appear as a new root trace with no connection to the producer. Always use OTel's `inject`/`extract` APIs — never manually copy trace IDs.

3. **High cardinality attributes causing storage explosion**: Attributes like `user.id` (millions of unique values) or `order.id` cause exponential storage growth in metric backends like Prometheus when used as labels. These are fine as span attributes in Jaeger/Tempo (stored once per span), but never use high-cardinality values as Prometheus metric labels.

## Related Skills

- `observability-engineer` — Metrics (Prometheus), logs (Loki), and the full observability stack
- `opentelemetry-instrumentation` — Deep OTel SDK configuration and custom exporters
- `sentry-and-otel-setup` — Error tracking + distributed tracing in one setup
- `chaos-engineering` — Using traces to verify resilience and measure degradation

## GitNexus Index

```json
{
  "skill": "distributed-tracing",
  "category": "devops",
  "triggers": ["distributed tracing", "opentelemetry", "jaeger", "grafana tempo", "spans", "trace propagation", "otel instrumentation", "service mesh tracing"],
  "outputs": ["TracerProvider setup", "tracer.start_as_current_span", "inject_trace_to_headers", "SmartSampler", "trace-log correlation"],
  "complexity": "medium",
  "tools": ["opentelemetry", "jaeger", "tempo", "grafana", "fastapi", "express", "kafka", "python", "typescript"]
}
```
