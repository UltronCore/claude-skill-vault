---
name: saga-pattern
description: Implement distributed transactions using the Saga pattern. Covers choreography-based sagas with event-driven compensation, orchestration-based sagas with a central coordinator, rollback strategies, and idempotency. Practical implementations in Python and TypeScript.
version: 1.0.0
tags: [saga-pattern, distributed-transactions, microservices, compensation, choreography, orchestration, eventual-consistency]
---

# Saga Pattern

## Overview

The Saga pattern solves distributed transactions across multiple microservices — when a single logical operation spans multiple services, each with its own database, you cannot use ACID transactions. A saga breaks the operation into a sequence of local transactions, each publishing events or calling the next step. If any step fails, the saga executes compensating transactions in reverse to undo completed steps. This skill covers both choreography (event-driven, no central coordinator) and orchestration (central saga coordinator) approaches.

## When to Use

- A business transaction spans multiple microservices (order + payment + inventory + shipping)
- Each service has its own database (no shared transaction scope possible)
- You need to handle partial failures gracefully with rollback logic
- Long-running transactions that may take seconds or minutes to complete
- Replacing two-phase commit (2PC) which doesn't scale across services

## Step-by-Step Workflow

### 1. Saga Design — Map Steps and Compensations
```
Business flow: Create Order
┌─────────────────────────────────────────────────────────────────────┐
│ Step 1: Reserve inventory     → Compensate: Release inventory       │
│ Step 2: Charge payment        → Compensate: Refund payment          │  
│ Step 3: Create shipment       → Compensate: Cancel shipment         │
│ Step 4: Update order status   → Compensate: Mark order as failed    │
└─────────────────────────────────────────────────────────────────────┘

Rule: Compensation must be idempotent (safe to retry)
Rule: Steps must be idempotent (safe if re-delivered)
Rule: Design for forward recovery (retry) before rollback
```

### 2. Choreography-Based Saga (Event-Driven)
```python
# Each service reacts to events and publishes next event
# No central coordinator — services are coupled only through events

import json
from dataclasses import dataclass, field
from datetime import datetime
from enum import Enum
from typing import Optional
import asyncio

class EventType(Enum):
    ORDER_CREATED = "order.created"
    INVENTORY_RESERVED = "inventory.reserved"
    INVENTORY_RESERVATION_FAILED = "inventory.reservation.failed"
    PAYMENT_CHARGED = "payment.charged"
    PAYMENT_FAILED = "payment.failed"
    SHIPMENT_CREATED = "shipment.created"
    ORDER_COMPLETED = "order.completed"
    # Compensation events
    INVENTORY_RELEASED = "inventory.released"
    PAYMENT_REFUNDED = "payment.refunded"

@dataclass
class SagaEvent:
    event_id: str
    event_type: str
    aggregate_id: str     # order_id
    correlation_id: str   # saga instance ID
    payload: dict
    timestamp: str = field(default_factory=lambda: datetime.utcnow().isoformat())

# Inventory Service — reacts to ORDER_CREATED
class InventoryService:
    async def handle_order_created(self, event: SagaEvent):
        order_id = event.payload["order_id"]
        items = event.payload["items"]
        
        try:
            # Idempotency check — already processed?
            if await self.already_processed(event.event_id):
                return
            
            # Try to reserve inventory
            reserved = await self.reserve_inventory(items, order_id)
            
            if reserved:
                # Publish success event
                await self.publish(SagaEvent(
                    event_id=f"inv-{order_id}",
                    event_type=EventType.INVENTORY_RESERVED.value,
                    aggregate_id=order_id,
                    correlation_id=event.correlation_id,
                    payload={"order_id": order_id, "reserved_items": items},
                ))
            else:
                # Publish failure — triggers compensation in other services
                await self.publish(SagaEvent(
                    event_id=f"inv-fail-{order_id}",
                    event_type=EventType.INVENTORY_RESERVATION_FAILED.value,
                    aggregate_id=order_id,
                    correlation_id=event.correlation_id,
                    payload={"order_id": order_id, "reason": "Insufficient stock"},
                ))
        finally:
            await self.mark_processed(event.event_id)

    async def handle_payment_failed(self, event: SagaEvent):
        """Compensating transaction — release inventory on payment failure."""
        order_id = event.payload["order_id"]
        if await self.already_processed(f"comp-{event.event_id}"):
            return
        await self.release_inventory(order_id)
        await self.publish(SagaEvent(
            event_id=f"inv-released-{order_id}",
            event_type=EventType.INVENTORY_RELEASED.value,
            aggregate_id=order_id,
            correlation_id=event.correlation_id,
            payload={"order_id": order_id},
        ))

# Payment Service — reacts to INVENTORY_RESERVED
class PaymentService:
    async def handle_inventory_reserved(self, event: SagaEvent):
        order_id = event.payload["order_id"]
        amount = event.payload.get("total_amount", 0)
        
        if await self.already_processed(event.event_id):
            return
        
        try:
            await self.charge_payment(order_id, amount)
            await self.publish(SagaEvent(
                event_id=f"pay-{order_id}",
                event_type=EventType.PAYMENT_CHARGED.value,
                aggregate_id=order_id,
                correlation_id=event.correlation_id,
                payload={"order_id": order_id, "amount": amount},
            ))
        except PaymentDeclinedError as e:
            await self.publish(SagaEvent(
                event_id=f"pay-fail-{order_id}",
                event_type=EventType.PAYMENT_FAILED.value,
                aggregate_id=order_id,
                correlation_id=event.correlation_id,
                payload={"order_id": order_id, "reason": str(e)},
            ))
```

### 3. Orchestration-Based Saga (Central Coordinator)
```typescript
// Saga orchestrator — explicit state machine with full control

enum SagaState {
  STARTED = "STARTED",
  INVENTORY_RESERVING = "INVENTORY_RESERVING",
  PAYMENT_CHARGING = "PAYMENT_CHARGING",
  SHIPMENT_CREATING = "SHIPMENT_CREATING",
  COMPLETED = "COMPLETED",
  // Compensation states
  COMPENSATING_PAYMENT = "COMPENSATING_PAYMENT",
  COMPENSATING_INVENTORY = "COMPENSATING_INVENTORY",
  FAILED = "FAILED",
}

interface SagaContext {
  sagaId: string;
  orderId: string;
  userId: string;
  items: OrderItem[];
  totalAmount: number;
  state: SagaState;
  failureReason?: string;
  retryCount: number;
  updatedAt: string;
}

class OrderSagaOrchestrator {
  constructor(
    private readonly db: SagaRepository,
    private readonly inventoryClient: InventoryClient,
    private readonly paymentClient: PaymentClient,
    private readonly shippingClient: ShippingClient,
    private readonly eventBus: EventBus,
  ) {}

  async execute(orderId: string, userId: string, items: OrderItem[], amount: number): Promise<void> {
    const sagaId = crypto.randomUUID();
    
    // Create saga state — persisted before any action
    let ctx: SagaContext = {
      sagaId, orderId, userId, items,
      totalAmount: amount,
      state: SagaState.STARTED,
      retryCount: 0,
      updatedAt: new Date().toISOString(),
    };
    
    await this.db.save(ctx);
    
    // Execute saga steps in sequence
    try {
      // Step 1: Reserve inventory
      ctx = await this.transition(ctx, SagaState.INVENTORY_RESERVING);
      await this.inventoryClient.reserve(orderId, items);
      
      // Step 2: Charge payment
      ctx = await this.transition(ctx, SagaState.PAYMENT_CHARGING);
      await this.paymentClient.charge(orderId, userId, amount);
      
      // Step 3: Create shipment
      ctx = await this.transition(ctx, SagaState.SHIPMENT_CREATING);
      await this.shippingClient.createShipment(orderId, userId);
      
      // Success
      ctx = await this.transition(ctx, SagaState.COMPLETED);
      await this.eventBus.publish("order.completed", { orderId, sagaId });
      
    } catch (error) {
      console.error(`Saga ${sagaId} failed at state ${ctx.state}:`, error);
      ctx.failureReason = error instanceof Error ? error.message : String(error);
      await this.compensate(ctx);
    }
  }

  private async compensate(ctx: SagaContext): Promise<void> {
    // Run compensating transactions in reverse order based on current state
    const compensations: Array<[SagaState, () => Promise<void>]> = [];

    if ([SagaState.SHIPMENT_CREATING, SagaState.PAYMENT_CHARGING].includes(ctx.state)) {
      compensations.push([
        SagaState.COMPENSATING_PAYMENT,
        () => this.paymentClient.refund(ctx.orderId, ctx.totalAmount),
      ]);
    }

    if ([
      SagaState.PAYMENT_CHARGING,
      SagaState.INVENTORY_RESERVING,
      SagaState.COMPENSATING_PAYMENT,
    ].includes(ctx.state)) {
      compensations.push([
        SagaState.COMPENSATING_INVENTORY,
        () => this.inventoryClient.release(ctx.orderId),
      ]);
    }

    for (const [state, compensate] of compensations) {
      ctx = await this.transition(ctx, state);
      try {
        await compensate();
      } catch (error) {
        // Log but continue — compensation must complete
        console.error(`Compensation step ${state} failed:`, error);
        // In production: dead-letter + manual intervention alert
      }
    }

    ctx = await this.transition(ctx, SagaState.FAILED);
    await this.eventBus.publish("order.failed", {
      orderId: ctx.orderId,
      reason: ctx.failureReason,
      sagaId: ctx.sagaId,
    });
  }

  private async transition(ctx: SagaContext, newState: SagaState): Promise<SagaContext> {
    const updated: SagaContext = { ...ctx, state: newState, updatedAt: new Date().toISOString() };
    await this.db.save(updated);  // Persist state before executing action
    return updated;
  }
}
```

### 4. Idempotency Key Pattern
```typescript
// Ensure each step is safe to retry without duplicate effects
class IdempotentStep {
  constructor(private readonly db: Database) {}

  async execute<T>(
    idempotencyKey: string,
    action: () => Promise<T>,
    ttlSeconds: number = 86400,
  ): Promise<T> {
    // Check if already executed
    const existing = await this.db.get(`idempotency:${idempotencyKey}`);
    if (existing) {
      return JSON.parse(existing) as T;
    }

    // Execute action
    const result = await action();

    // Store result to prevent re-execution
    await this.db.setex(
      `idempotency:${idempotencyKey}`,
      ttlSeconds,
      JSON.stringify(result),
    );

    return result;
  }
}

// Usage in saga steps
const idempotent = new IdempotentStep(redis);

await idempotent.execute(
  `reserve-inventory:${orderId}`,
  () => inventoryService.reserve(orderId, items),
);
```

### 5. Saga Recovery — Handling Crashes Mid-Execution
```python
import asyncio
from datetime import datetime, timedelta

class SagaRecoveryService:
    """Periodically finds and resumes stuck sagas."""
    
    async def recover_stuck_sagas(self):
        """Find sagas that haven't progressed in 5+ minutes."""
        stuck_cutoff = datetime.utcnow() - timedelta(minutes=5)
        
        stuck_sagas = await self.db.find_sagas(
            states=[
                SagaState.INVENTORY_RESERVING,
                SagaState.PAYMENT_CHARGING,
                SagaState.SHIPMENT_CREATING,
                SagaState.COMPENSATING_PAYMENT,
                SagaState.COMPENSATING_INVENTORY,
            ],
            updated_before=stuck_cutoff,
        )
        
        for saga in stuck_sagas:
            if saga.retry_count >= 3:
                await self.escalate_to_manual_review(saga)
            else:
                await self.orchestrator.resume(saga)
    
    async def resume(self, ctx: SagaContext):
        """Resume saga from last persisted state."""
        ctx.retry_count += 1
        await self.db.save(ctx)
        
        # Re-execute from current state
        state_handlers = {
            SagaState.INVENTORY_RESERVING: self.retry_inventory_reserve,
            SagaState.PAYMENT_CHARGING: self.retry_payment_charge,
            SagaState.COMPENSATING_PAYMENT: self.retry_payment_refund,
            SagaState.COMPENSATING_INVENTORY: self.retry_inventory_release,
        }
        
        handler = state_handlers.get(ctx.state)
        if handler:
            await handler(ctx)
```

## Key Commands Reference

```bash
# Query saga state from database
psql -c "SELECT saga_id, order_id, state, failure_reason, retry_count, updated_at 
          FROM sagas WHERE state NOT IN ('COMPLETED', 'FAILED') ORDER BY updated_at;"

# Find stuck sagas (not updated in 10+ minutes)
psql -c "SELECT * FROM sagas WHERE updated_at < NOW() - INTERVAL '10 minutes' 
          AND state NOT IN ('COMPLETED', 'FAILED');"

# Replay failed sagas (for forensics)
psql -c "SELECT saga_id, state, failure_reason FROM sagas WHERE state = 'FAILED' 
          AND created_at > NOW() - INTERVAL '24 hours' ORDER BY created_at DESC;"

# Monitor saga success rate
psql -c "SELECT state, COUNT(*), AVG(EXTRACT(EPOCH FROM (updated_at - created_at))) as avg_duration_sec
          FROM sagas WHERE created_at > NOW() - INTERVAL '1 hour' GROUP BY state;"
```

## Common Patterns

### Pattern 1: Outbox Pattern for Reliable Event Publishing
```typescript
// Publish events atomically with the database write (no lost events)
async function createOrderAndPublishEvent(order: Order, db: Transaction) {
  // Both writes in one transaction — event is never lost
  await db.query("INSERT INTO orders VALUES ($1, $2, $3)", [order.id, order.userId, order.total]);
  await db.query(
    "INSERT INTO outbox (event_type, payload, published) VALUES ($1, $2, false)",
    ["order.created", JSON.stringify(order)],
  );
  // Transaction commits — both writes succeed or neither does
}

// Separate process reads outbox and publishes to message broker
async function publishOutboxEvents(db: Database, broker: MessageBroker) {
  const events = await db.query("SELECT * FROM outbox WHERE published = false LIMIT 100 FOR UPDATE SKIP LOCKED");
  for (const event of events.rows) {
    await broker.publish(event.event_type, event.payload);
    await db.query("UPDATE outbox SET published = true WHERE id = $1", [event.id]);
  }
}
```

### Pattern 2: Saga Timeout and Deadline
```typescript
// Enforce maximum saga duration
class SagaWithTimeout {
  async execute(ctx: SagaContext, timeoutMs: number = 60_000): Promise<void> {
    const deadline = Date.now() + timeoutMs;

    const timeoutPromise = new Promise<never>((_, reject) =>
      setTimeout(() => reject(new SagaTimeoutError(`Saga ${ctx.sagaId} timed out`)), timeoutMs)
    );

    try {
      await Promise.race([this.runSaga(ctx), timeoutPromise]);
    } catch (error) {
      if (error instanceof SagaTimeoutError) {
        await this.compensate(ctx);  // Rollback on timeout
      }
      throw error;
    }
  }
}
```

### Pattern 3: Saga State Persistence with PostgreSQL
```sql
CREATE TABLE sagas (
    saga_id         UUID PRIMARY KEY,
    order_id        UUID NOT NULL,
    user_id         UUID NOT NULL,
    state           VARCHAR(50) NOT NULL,
    payload         JSONB NOT NULL DEFAULT '{}',
    failure_reason  TEXT,
    retry_count     INT NOT NULL DEFAULT 0,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_sagas_state ON sagas(state) WHERE state NOT IN ('COMPLETED', 'FAILED');
CREATE INDEX idx_sagas_order_id ON sagas(order_id);
CREATE INDEX idx_sagas_updated_at ON sagas(updated_at) WHERE state NOT IN ('COMPLETED', 'FAILED');
```

## Pitfalls to Avoid

1. **Non-idempotent compensating transactions**: Your refund service must handle being called twice (network retry after first success). Use idempotency keys on every external call. A double-refund from a compensation retry is worse than the original failure. Test compensation idempotency explicitly.

2. **Choreography without visibility**: Event-driven choreography is hard to observe — a failing saga produces a flood of events with no single place to look at the full picture. Add a saga tracker that listens to all saga events and maintains a read model of the current state, even if the saga itself is choreographed. Without this, debugging production failures requires reconstructing state from scattered logs.

3. **Forgetting to handle compensation failures**: A compensation that fails leaves the system in an inconsistent state. Don't silently ignore compensation errors — dead-letter them and alert. The system needs human intervention when compensation fails. In choreography, publish a `saga.stuck` event that triggers an alert. In orchestration, mark the saga as `COMPENSATION_FAILED` and page on-call.

## Related Skills

- `event-driven-architecture` — Event design for saga choreography
- `cqrs-patterns` — Read models for saga state visibility
- `kafka-event-streaming` — Message broker for saga events
- `circuit-breaker-patterns` — Wrapping saga steps with circuit breakers

## GitNexus Index

```json
{
  "skill": "saga-pattern",
  "category": "backend",
  "triggers": ["saga pattern", "distributed transaction", "choreography saga", "orchestration saga", "compensation transaction", "eventual consistency microservices"],
  "outputs": ["saga orchestrator", "compensation handler", "idempotency key", "event choreography", "saga state machine"],
  "complexity": "high",
  "tools": ["python", "typescript", "postgresql", "kafka", "redis"]
}
```
