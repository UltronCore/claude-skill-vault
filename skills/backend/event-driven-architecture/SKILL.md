---
name: event-driven-architecture
description: Design and implement event-driven architectures (EDA) with domain events, event stores, projections, and choreography vs orchestration patterns. Works with Kafka, RabbitMQ, EventBridge, or in-process event buses.
version: 1.0.0
tags: [event-driven, architecture, domain-events, choreography, orchestration, messaging, EDA]
---

# Event-Driven Architecture

## Overview

This skill covers the architectural patterns for building event-driven systems: identifying domain events, designing event schemas, choosing between choreography and orchestration, implementing event stores and projections, and handling eventual consistency. It's broker-agnostic — patterns apply to Kafka, RabbitMQ, AWS EventBridge, Azure Service Bus, or simple in-process buses.

## When to Use

- Decoupling services that currently share a database or call each other synchronously
- Implementing audit logs or activity feeds that need a full history of state changes
- Building real-time notifications, webhooks, or data sync across services
- Systems where operations span multiple services and need coordination
- Replacing synchronous REST chains that cause availability coupling

## Step-by-Step Workflow

### 1. Identify Domain Events
```markdown
## Event Storming Output (simplified)
Domain events are named in past tense — things that happened:

ORDER SERVICE:
- OrderPlaced
- OrderConfirmed
- OrderCancelled
- OrderShipped
- OrderDelivered

PAYMENT SERVICE:
- PaymentInitiated
- PaymentSucceeded
- PaymentFailed
- RefundIssued

INVENTORY SERVICE:
- InventoryReserved
- InventoryReleased
- StockDepleted

Rules:
1. Events describe facts — things that HAPPENED, not commands
2. Name from domain perspective, not technical (OrderPlaced not CreateOrder)
3. Include all data needed to process the event (don't require lookups)
```

### 2. Event Schema Design
```python
from dataclasses import dataclass, field
from datetime import datetime
from typing import Any
import uuid

@dataclass
class DomainEvent:
    """Base class for all domain events."""
    event_id: str = field(default_factory=lambda: str(uuid.uuid4()))
    event_type: str = field(default="")
    aggregate_id: str = ""
    aggregate_type: str = ""
    version: int = 1
    occurred_at: datetime = field(default_factory=datetime.utcnow)
    correlation_id: str = ""    # Links related events
    causation_id: str = ""      # ID of event/command that caused this
    metadata: dict = field(default_factory=dict)

@dataclass
class OrderPlaced(DomainEvent):
    event_type: str = "order.placed"
    aggregate_type: str = "Order"
    # Payload — include all needed data (avoid requiring lookups)
    customer_id: str = ""
    customer_email: str = ""
    items: list[dict] = field(default_factory=list)
    total_cents: int = 0
    currency: str = "USD"
    shipping_address: dict = field(default_factory=dict)

# Avro-compatible JSON schema equivalent
ORDER_PLACED_SCHEMA = {
    "type": "record",
    "name": "OrderPlaced",
    "namespace": "com.example.orders.v1",
    "fields": [
        {"name": "event_id", "type": "string"},
        {"name": "aggregate_id", "type": "string"},
        {"name": "occurred_at", "type": "long"},
        {"name": "customer_id", "type": "string"},
        {"name": "total_cents", "type": "int"},
        {"name": "items", "type": {"type": "array", "items": "..."}}
    ]
}
```

### 3. Choreography Pattern (Services React Independently)
```python
# Each service subscribes to relevant events — no central coordinator

# inventory-service/subscribers.py
class InventoryEventHandler:
    def __init__(self, inventory_repo, event_publisher):
        self.repo = inventory_repo
        self.publisher = event_publisher
    
    def on_order_placed(self, event: OrderPlaced):
        """Reserve inventory when order is placed."""
        try:
            reservation = self.repo.reserve(event.aggregate_id, event.items)
            self.publisher.publish(InventoryReserved(
                aggregate_id=reservation.id,
                order_id=event.aggregate_id,
                items=event.items,
                correlation_id=event.correlation_id,
                causation_id=event.event_id,
            ))
        except InsufficientStockError as e:
            self.publisher.publish(InventoryReservationFailed(
                order_id=event.aggregate_id,
                reason=str(e),
                causation_id=event.event_id,
            ))

# payment-service/subscribers.py
class PaymentEventHandler:
    def on_inventory_reserved(self, event: InventoryReserved):
        """Charge payment after inventory is confirmed."""
        payment = self.payment_gateway.charge(
            order_id=event.order_id,
            amount=event.reservation.total_cents,
        )
        self.publisher.publish(PaymentSucceeded(
            order_id=event.order_id,
            causation_id=event.event_id,
        ))
```

### 4. Orchestration Pattern (Saga with Central Coordinator)
```python
# order-service/sagas/create_order_saga.py
class CreateOrderSaga:
    """Coordinates order creation across services via commands."""
    
    STEPS = [
        ("reserve_inventory", "inventory_reserved", "inventory_reservation_failed"),
        ("charge_payment", "payment_succeeded", "payment_failed"),
        ("confirm_order", "order_confirmed", None),
    ]
    
    def __init__(self, state: SagaState):
        self.state = state
    
    def handle(self, event: DomainEvent):
        if isinstance(event, OrderPlaced):
            self.send_command(ReserveInventory(
                order_id=event.aggregate_id,
                items=event.items,
            ))
        
        elif isinstance(event, InventoryReserved):
            self.send_command(ChargePayment(
                order_id=event.order_id,
                amount=event.reservation.total_cents,
            ))
        
        elif isinstance(event, InventoryReservationFailed):
            # Compensate: cancel the order
            self.send_command(CancelOrder(
                order_id=event.order_id,
                reason=event.reason,
            ))
        
        elif isinstance(event, PaymentFailed):
            # Compensate: release inventory
            self.send_command(ReleaseInventory(
                order_id=event.order_id,
                items=self.state.reserved_items,
            ))
```

### 5. Event Store
```python
import json
from datetime import datetime

class PostgresEventStore:
    """Append-only event store with optimistic concurrency."""
    
    def __init__(self, db):
        self.db = db
    
    def append(self, stream_id: str, events: list[DomainEvent], expected_version: int):
        """Append events to stream. Raises if version doesn't match."""
        with self.db.transaction():
            current_version = self.db.query_one(
                "SELECT MAX(version) FROM events WHERE stream_id = %s",
                stream_id
            ) or 0
            
            if current_version != expected_version:
                raise OptimisticConcurrencyError(
                    f"Expected version {expected_version}, got {current_version}"
                )
            
            for i, event in enumerate(events):
                self.db.execute(
                    """INSERT INTO events (stream_id, event_type, version, payload, occurred_at)
                       VALUES (%s, %s, %s, %s, %s)""",
                    stream_id,
                    event.event_type,
                    expected_version + i + 1,
                    json.dumps(event.__dict__, default=str),
                    event.occurred_at,
                )
    
    def load_stream(self, stream_id: str, from_version: int = 0) -> list[DomainEvent]:
        rows = self.db.query(
            "SELECT event_type, payload FROM events WHERE stream_id = %s AND version > %s ORDER BY version",
            stream_id, from_version
        )
        return [deserialize_event(row) for row in rows]
```

### 6. Projection (Read Model)
```python
class OrderSummaryProjection:
    """Build a read-optimized view from events."""
    
    def __init__(self, read_db):
        self.read_db = read_db
    
    def handle(self, event: DomainEvent):
        if isinstance(event, OrderPlaced):
            self.read_db.upsert("order_summaries", {
                "order_id": event.aggregate_id,
                "customer_id": event.customer_id,
                "status": "pending",
                "total": event.total_cents / 100,
                "item_count": len(event.items),
                "created_at": event.occurred_at,
            })
        
        elif isinstance(event, OrderConfirmed):
            self.read_db.update("order_summaries",
                where={"order_id": event.aggregate_id},
                set={"status": "confirmed", "confirmed_at": event.occurred_at}
            )
```

## Common Patterns

### Pattern 1: Outbox Pattern (Reliable Event Publishing)
```python
# Atomically save entity + event in same transaction
def place_order(order_data: dict):
    with db.transaction():
        order = Order.create(order_data)
        db.save(order)
        # Save to outbox — same transaction as entity
        db.execute(
            "INSERT INTO outbox (event_type, payload, created_at) VALUES (%s, %s, %s)",
            "order.placed", json.dumps(order.to_event()), datetime.utcnow()
        )
    # Background process polls outbox and publishes to broker
```

### Pattern 2: Event Versioning
```python
# Version in event type, upcasting for backward compatibility
def deserialize_event(raw: dict) -> DomainEvent:
    event_type = raw["event_type"]
    if event_type == "order.placed.v1":
        # Upcast v1 to v2 structure
        return OrderPlaced(
            **raw["payload"],
            # Add new required field with default
            shipping_method=raw["payload"].get("shipping_method", "standard")
        )
    elif event_type == "order.placed.v2":
        return OrderPlaced(**raw["payload"])
```

### Pattern 3: Dead Letter Queue Reprocessing
```bash
# Move failed events from DLQ back to main queue
aws sqs receive-message --queue-url https://sqs.us-east-1.amazonaws.com/acc/events-dlq \
  --max-number-of-messages 10 |
jq -r '.Messages[] | {Id: .MessageId, ReceiptHandle: .ReceiptHandle, Body: .Body}' |
# Re-publish to main queue after fixing the consumer bug
aws sqs send-message --queue-url https://sqs.us-east-1.amazonaws.com/acc/events \
  --message-body "$body"
```

## Pitfalls to Avoid

1. **Events as commands**: Events describe what happened (`OrderPlaced`) — they're facts, not requests. If you name events as commands (`PlaceOrder`, `ProcessPayment`), you've built a request-response system, not EDA. Commands are imperatives sent to one consumer; events are facts published to many.

2. **Eventual consistency surprises**: EDA requires accepting that read models lag behind writes. UI code must handle "order placed — will appear in your history within seconds." Design UX for optimistic updates and explain the consistency model to product. Don't fight it with synchronous reads after async writes.

3. **Schema coupling**: Putting all event fields in a flat structure and letting consumers map them creates tight schema coupling. Use bounded context translation at integration boundaries — don't share internal domain objects across services as event payloads.

## Related Skills

- `kafka-event-streaming` — Kafka as the event broker
- `cqrs-patterns` — Command/Query separation that pairs with EDA
- `saga-pattern` — Distributed transaction coordination
- `circuit-breaker-patterns` — Resilience when event consumers fail

## GitNexus Index

```json
{
  "skill": "event-driven-architecture",
  "category": "backend",
  "triggers": ["event driven", "domain events", "choreography", "orchestration", "event store", "event sourcing", "outbox pattern"],
  "outputs": ["event schema", "saga implementation", "event store", "projection", "choreography flow"],
  "complexity": "high",
  "tools": ["kafka", "rabbitmq", "eventbridge", "postgres", "redis"]
}
```
