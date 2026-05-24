---
name: cqrs-patterns
description: Implement Command Query Responsibility Segregation (CQRS) to separate read and write models, enabling independent scaling, optimized read models, and clear domain boundaries.
version: 1.0.0
tags: [cqrs, architecture, commands, queries, read-model, write-model, domain-driven-design]
---

# CQRS Patterns

## Overview

This skill covers implementing CQRS — the architectural pattern that separates command (write) and query (read) responsibilities into distinct models. It covers command handling with validation, aggregate state management, optimized read models (projections), and the synchronization mechanisms between write and read sides. CQRS pairs naturally with event sourcing but works with traditional persistence too.

## When to Use

- Read and write traffic have very different scalability needs
- You need multiple specialized read models (dashboard, mobile app, reporting) over the same domain data
- Complex domain logic that doesn't map cleanly to a single CRUD model
- Audit logging or temporal queries requiring event history
- When simple CRUD is causing impedance mismatch between domain and storage

## Step-by-Step Workflow

### 1. Identify Commands and Queries
```markdown
## Command Side (writes — changes state)
Commands: PlaceOrder, CancelOrder, UpdateShippingAddress, ApplyCoupon
Handlers: Validate → Execute business logic → Persist → Publish event

## Query Side (reads — never change state)
Queries: GetOrderById, GetOrdersByCustomer, GetOrderSummaryDashboard
Handlers: Fetch from optimized read model → Return DTO
```

### 2. Command Handler Implementation
```python
from dataclasses import dataclass
from typing import Optional
from datetime import datetime

# Commands — plain data objects, no behavior
@dataclass
class PlaceOrderCommand:
    customer_id: str
    items: list[dict]
    shipping_address: dict
    coupon_code: Optional[str] = None

@dataclass
class CancelOrderCommand:
    order_id: str
    customer_id: str
    reason: str

# Command result
@dataclass
class CommandResult:
    success: bool
    order_id: Optional[str] = None
    error: Optional[str] = None

# Command handler — all business logic lives here
class PlaceOrderCommandHandler:
    def __init__(self, order_repo, inventory_service, event_bus, id_generator):
        self.order_repo = order_repo
        self.inventory = inventory_service
        self.event_bus = event_bus
        self.id_generator = id_generator
    
    def handle(self, cmd: PlaceOrderCommand) -> CommandResult:
        # Validation
        if not cmd.items:
            return CommandResult(success=False, error="Order must have at least one item")
        
        # Business logic
        total = self._calculate_total(cmd.items, cmd.coupon_code)
        if total <= 0:
            return CommandResult(success=False, error="Invalid order total")
        
        # Check inventory availability
        availability = self.inventory.check_availability(cmd.items)
        if not availability.all_available:
            return CommandResult(success=False, error=f"Out of stock: {availability.unavailable_items}")
        
        # Create aggregate
        order = Order(
            id=self.id_generator.new_id(),
            customer_id=cmd.customer_id,
            items=cmd.items,
            total_cents=int(total * 100),
            status="pending",
            created_at=datetime.utcnow(),
        )
        
        # Persist (write side)
        self.order_repo.save(order)
        
        # Publish event (triggers read model update)
        self.event_bus.publish(OrderPlaced(
            aggregate_id=order.id,
            customer_id=order.customer_id,
            items=order.items,
            total_cents=order.total_cents,
        ))
        
        return CommandResult(success=True, order_id=order.id)
    
    def _calculate_total(self, items, coupon_code):
        subtotal = sum(item['price'] * item['quantity'] for item in items)
        if coupon_code:
            discount = self._get_discount(coupon_code)
            return subtotal * (1 - discount)
        return subtotal
```

### 3. Query Handler Implementation
```python
# Queries — describe what data is needed
@dataclass
class GetOrderByIdQuery:
    order_id: str
    customer_id: str  # For authorization

@dataclass
class GetCustomerOrdersQuery:
    customer_id: str
    status: Optional[str] = None
    page: int = 0
    page_size: int = 20

# DTOs — shaped for the consumer, not the domain
@dataclass
class OrderDetailDTO:
    order_id: str
    status: str
    items: list[dict]
    total: float
    placed_at: str
    estimated_delivery: Optional[str]

# Query handler reads from optimized read store (can be different DB)
class GetOrderByIdQueryHandler:
    def __init__(self, read_db):
        self.db = read_db
    
    def handle(self, query: GetOrderByIdQuery) -> Optional[OrderDetailDTO]:
        # Read from denormalized, optimized table
        row = self.db.query_one(
            """SELECT o.*, c.name as customer_name, 
                      array_agg(row_to_json(oi)) as items
               FROM order_read_model o
               JOIN order_items_read_model oi ON oi.order_id = o.id
               WHERE o.id = %s AND o.customer_id = %s
               GROUP BY o.id""",
            query.order_id, query.customer_id
        )
        if not row:
            return None
        return OrderDetailDTO(**row)
```

### 4. Dispatcher (Routes Commands and Queries)
```python
class CommandBus:
    def __init__(self):
        self._handlers: dict[type, callable] = {}
    
    def register(self, command_type: type, handler):
        self._handlers[command_type] = handler
    
    def dispatch(self, command) -> CommandResult:
        handler = self._handlers.get(type(command))
        if not handler:
            raise ValueError(f"No handler registered for {type(command).__name__}")
        return handler.handle(command)

class QueryBus:
    def __init__(self):
        self._handlers: dict[type, callable] = {}
    
    def register(self, query_type: type, handler):
        self._handlers[query_type] = handler
    
    def execute(self, query):
        handler = self._handlers.get(type(query))
        if not handler:
            raise ValueError(f"No handler registered for {type(query).__name__}")
        return handler.handle(query)

# Wiring (in DI container / startup)
command_bus = CommandBus()
command_bus.register(PlaceOrderCommand, PlaceOrderCommandHandler(
    order_repo, inventory_service, event_bus, id_generator
))

query_bus = QueryBus()
query_bus.register(GetOrderByIdQuery, GetOrderByIdQueryHandler(read_db))
```

### 5. Read Model Projection
```python
class OrderReadModelProjection:
    """Maintains the optimized read model from domain events."""
    
    def __init__(self, read_db):
        self.db = read_db
    
    def on_order_placed(self, event: OrderPlaced):
        self.db.execute("""
            INSERT INTO order_read_model
                (id, customer_id, status, total, item_count, created_at)
            VALUES (%s, %s, 'pending', %s, %s, %s)
            ON CONFLICT (id) DO NOTHING
        """, event.aggregate_id, event.customer_id,
             event.total_cents / 100, len(event.items), event.occurred_at)
    
    def on_order_confirmed(self, event: OrderConfirmed):
        self.db.execute(
            "UPDATE order_read_model SET status = 'confirmed', confirmed_at = %s WHERE id = %s",
            event.occurred_at, event.aggregate_id
        )
    
    def on_order_shipped(self, event: OrderShipped):
        self.db.execute(
            """UPDATE order_read_model 
               SET status = 'shipped', tracking_number = %s, estimated_delivery = %s
               WHERE id = %s""",
            event.tracking_number, event.estimated_delivery, event.aggregate_id
        )
```

### 6. FastAPI Integration
```python
from fastapi import FastAPI, Depends

app = FastAPI()

@app.post("/orders", status_code=201)
def place_order(body: PlaceOrderRequest, cmd_bus: CommandBus = Depends(get_command_bus)):
    cmd = PlaceOrderCommand(
        customer_id=get_current_user().id,
        items=body.items,
        shipping_address=body.shipping_address,
    )
    result = cmd_bus.dispatch(cmd)
    if not result.success:
        raise HTTPException(422, detail=result.error)
    return {"order_id": result.order_id}

@app.get("/orders/{order_id}")
def get_order(order_id: str, q_bus: QueryBus = Depends(get_query_bus)):
    query = GetOrderByIdQuery(order_id=order_id, customer_id=get_current_user().id)
    order = q_bus.execute(query)
    if not order:
        raise HTTPException(404)
    return order
```

## Common Patterns

### Pattern 1: Multiple Read Models for Same Data
```python
# Order exists once in write model, but multiple read projections
# Read Model 1: Customer-facing order detail
class OrderDetailProjection: ...

# Read Model 2: Admin dashboard with all fields
class OrderAdminProjection: ...

# Read Model 3: Reporting aggregates for analytics
class OrderRevenueProjection:
    def on_order_placed(self, event):
        self.db.execute("""
            INSERT INTO daily_revenue (date, amount)
            VALUES (%s, %s)
            ON CONFLICT (date) DO UPDATE SET amount = daily_revenue.amount + %s
        """, event.occurred_at.date(), event.total_cents, event.total_cents)
```

### Pattern 2: Command Validation Decorator
```python
def validate_command(fn):
    @wraps(fn)
    def wrapper(self, cmd):
        errors = cmd.validate()
        if errors:
            return CommandResult(success=False, error="; ".join(errors))
        return fn(self, cmd)
    return wrapper

@dataclass
class PlaceOrderCommand:
    customer_id: str
    items: list[dict]
    
    def validate(self) -> list[str]:
        errors = []
        if not self.customer_id:
            errors.append("customer_id required")
        if not self.items:
            errors.append("items required")
        return errors
```

### Pattern 3: Rebuild Read Model from Event History
```bash
# When read model is corrupted or schema changes,
# rebuild from event store by replaying all events
python manage.py rebuild_projection OrderReadModelProjection --from-beginning
```

## Pitfalls to Avoid

1. **CQRS everywhere**: CQRS adds significant complexity. Apply it to domains with complex business rules and scalability needs, not CRUD endpoints. A simple user settings page doesn't need CQRS. Start with simple CRUD and extract CQRS for the bounded contexts that need it.

2. **Synchronous read model updates**: If you update the read model in the same transaction as the write, you haven't gained independence. The read model should update asynchronously via events. Accept the slight consistency lag and design the UI for it.

3. **Leaking domain logic into queries**: Query handlers must not contain business rules — they only shape data for consumption. If you catch yourself putting validation or calculations in a query handler, that logic belongs in the command side.

## Related Skills

- `event-driven-architecture` — Events that trigger read model updates
- `saga-pattern` — Multi-step command coordination
- `postgres-advanced` — Optimizing the read model database
- `event-driven-architecture` — EDA as the sync mechanism

## GitNexus Index

```json
{
  "skill": "cqrs-patterns",
  "category": "backend",
  "triggers": ["cqrs", "command query", "read model", "write model", "projection", "command bus", "query bus"],
  "outputs": ["command handler", "query handler", "read model", "command bus", "projection"],
  "complexity": "high",
  "tools": ["python", "fastapi", "postgresql", "kafka", "redis"]
}
```
