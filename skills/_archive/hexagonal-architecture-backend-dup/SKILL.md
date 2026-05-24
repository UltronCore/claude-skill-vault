---
name: hexagonal-architecture
description: Implement Hexagonal Architecture (Ports and Adapters) to isolate business logic from infrastructure. Covers domain core design, port interfaces, adapter implementations for databases/APIs/queues, dependency inversion, and testability patterns.
version: 1.0.0
tags: [hexagonal-architecture, ports-adapters, domain-driven-design, clean-code, testability, dependency-inversion, python, typescript]
---

# Hexagonal Architecture (Ports and Adapters)

## Overview

Hexagonal Architecture separates your application into three zones: the domain core (pure business logic with no external dependencies), ports (interfaces that define how the core communicates with the outside world), and adapters (concrete implementations of those ports for specific technologies). The result is business logic that can be tested in isolation, infrastructure that can be swapped without changing domain code, and clear boundaries that prevent framework coupling from leaking into your core.

## When to Use

- Business logic is complex enough that you want to test it without databases or HTTP
- You need to swap infrastructure (PostgreSQL → DynamoDB, REST → gRPC) without rewriting business logic
- Multiple delivery mechanisms need to share the same domain (REST API + CLI + worker)
- Team is struggling with framework-entangled code that's hard to test
- Building a long-lived system where infrastructure will evolve but domain must be stable

## Step-by-Step Workflow

### 1. Project Structure
```
src/
├── domain/                    # Pure business logic — no imports from outside
│   ├── models/                # Entities, value objects, aggregates
│   │   ├── order.py
│   │   └── product.py
│   ├── ports/                 # Interfaces (Python: abstract classes)
│   │   ├── repositories.py    # Outbound port: OrderRepository
│   │   ├── event_bus.py       # Outbound port: EventBus
│   │   └── payment.py         # Outbound port: PaymentGateway
│   └── services/              # Domain services / use cases
│       └── order_service.py
│
├── adapters/                  # Implementations of ports
│   ├── inbound/               # Entry points (call the domain)
│   │   ├── http/              # FastAPI routes
│   │   ├── cli/               # CLI commands
│   │   └── worker/            # Queue consumers
│   └── outbound/              # Infrastructure (called by domain via ports)
│       ├── postgres/          # PostgreSQL repository implementations
│       ├── redis/             # Redis cache adapter
│       ├── stripe/            # Stripe payment adapter
│       └── kafka/             # Kafka event bus adapter
│
└── composition/               # Wire everything together
    └── container.py           # Dependency injection
```

### 2. Domain Core — Pure Business Logic
```python
# domain/models/order.py — no framework imports
from dataclasses import dataclass, field
from datetime import datetime
from decimal import Decimal
from enum import Enum
from typing import Optional
import uuid

class OrderStatus(Enum):
    PENDING = "pending"
    CONFIRMED = "confirmed"
    SHIPPED = "shipped"
    DELIVERED = "delivered"
    CANCELLED = "cancelled"

@dataclass
class OrderItem:
    product_id: str
    quantity: int
    unit_price: Decimal
    
    @property
    def subtotal(self) -> Decimal:
        return self.unit_price * self.quantity

@dataclass
class Order:
    id: str
    user_id: str
    items: list[OrderItem]
    status: OrderStatus
    created_at: datetime
    updated_at: datetime
    shipping_address: Optional[str] = None
    
    @classmethod
    def create(cls, user_id: str, items: list[OrderItem]) -> "Order":
        if not items:
            raise ValueError("Order must have at least one item")
        now = datetime.utcnow()
        return cls(
            id=str(uuid.uuid4()),
            user_id=user_id,
            items=items,
            status=OrderStatus.PENDING,
            created_at=now,
            updated_at=now,
        )
    
    @property
    def total(self) -> Decimal:
        return sum(item.subtotal for item in self.items)
    
    def confirm(self) -> "Order":
        if self.status != OrderStatus.PENDING:
            raise ValueError(f"Cannot confirm order in status {self.status}")
        return Order(
            **{**self.__dict__, "status": OrderStatus.CONFIRMED, "updated_at": datetime.utcnow()}
        )
    
    def cancel(self, reason: str) -> "Order":
        if self.status in (OrderStatus.SHIPPED, OrderStatus.DELIVERED):
            raise ValueError("Cannot cancel shipped or delivered orders")
        return Order(
            **{**self.__dict__, "status": OrderStatus.CANCELLED, "updated_at": datetime.utcnow()}
        )
```

### 3. Ports — Interface Definitions
```python
# domain/ports/repositories.py — abstract interfaces only
from abc import ABC, abstractmethod
from typing import Optional
from ..models.order import Order

class OrderRepository(ABC):
    """Outbound port: storage for orders."""
    
    @abstractmethod
    async def save(self, order: Order) -> None: ...
    
    @abstractmethod
    async def find_by_id(self, order_id: str) -> Optional[Order]: ...
    
    @abstractmethod
    async def find_by_user(self, user_id: str, limit: int = 20) -> list[Order]: ...
    
    @abstractmethod
    async def update(self, order: Order) -> None: ...

# domain/ports/payment.py
class PaymentGateway(ABC):
    @abstractmethod
    async def charge(self, order_id: str, user_id: str, amount_cents: int, currency: str = "usd") -> str:
        """Returns payment_id on success, raises PaymentDeclinedError on failure."""
        ...
    
    @abstractmethod
    async def refund(self, payment_id: str, amount_cents: int) -> None: ...

# domain/ports/event_bus.py
from dataclasses import dataclass
from typing import Any

@dataclass
class DomainEvent:
    event_type: str
    aggregate_id: str
    payload: dict[str, Any]
    occurred_at: str

class EventBus(ABC):
    @abstractmethod
    async def publish(self, event: DomainEvent) -> None: ...
```

### 4. Domain Service (Use Case)
```python
# domain/services/order_service.py
from decimal import Decimal
from ..models.order import Order, OrderItem, OrderStatus
from ..ports.repositories import OrderRepository
from ..ports.payment import PaymentGateway
from ..ports.event_bus import EventBus, DomainEvent
from datetime import datetime

class OrderService:
    """Pure business logic — depends only on port interfaces, never on adapters."""
    
    def __init__(
        self,
        order_repo: OrderRepository,      # Port interface, not concrete class
        payment: PaymentGateway,
        event_bus: EventBus,
    ):
        self._orders = order_repo
        self._payment = payment
        self._events = event_bus
    
    async def place_order(self, user_id: str, items_data: list[dict]) -> Order:
        items = [
            OrderItem(
                product_id=item["product_id"],
                quantity=item["quantity"],
                unit_price=Decimal(str(item["unit_price"])),
            )
            for item in items_data
        ]
        
        order = Order.create(user_id=user_id, items=items)
        await self._orders.save(order)
        
        await self._events.publish(DomainEvent(
            event_type="order.created",
            aggregate_id=order.id,
            payload={"user_id": user_id, "total": str(order.total)},
            occurred_at=datetime.utcnow().isoformat(),
        ))
        
        return order
    
    async def confirm_and_charge(self, order_id: str) -> Order:
        order = await self._orders.find_by_id(order_id)
        if not order:
            raise ValueError(f"Order {order_id} not found")
        
        # Domain logic validates state machine
        confirmed = order.confirm()
        
        # Charge via payment port — adapter handles Stripe/PayPal details
        payment_id = await self._payment.charge(
            order_id=order.id,
            user_id=order.user_id,
            amount_cents=int(order.total * 100),
        )
        
        await self._orders.update(confirmed)
        
        await self._events.publish(DomainEvent(
            event_type="order.confirmed",
            aggregate_id=order.id,
            payload={"payment_id": payment_id, "amount": str(order.total)},
            occurred_at=datetime.utcnow().isoformat(),
        ))
        
        return confirmed
```

### 5. Outbound Adapters — Infrastructure
```python
# adapters/outbound/postgres/order_repository.py
import asyncpg
from domain.models.order import Order, OrderItem, OrderStatus
from domain.ports.repositories import OrderRepository
from decimal import Decimal
from datetime import datetime

class PostgresOrderRepository(OrderRepository):
    """Concrete implementation of OrderRepository port."""
    
    def __init__(self, pool: asyncpg.Pool):
        self._pool = pool
    
    async def save(self, order: Order) -> None:
        async with self._pool.acquire() as conn:
            async with conn.transaction():
                await conn.execute("""
                    INSERT INTO orders (id, user_id, status, total, created_at, updated_at)
                    VALUES ($1, $2, $3, $4, $5, $6)
                """, order.id, order.user_id, order.status.value,
                    float(order.total), order.created_at, order.updated_at)
                
                for item in order.items:
                    await conn.execute("""
                        INSERT INTO order_items (order_id, product_id, quantity, unit_price)
                        VALUES ($1, $2, $3, $4)
                    """, order.id, item.product_id, item.quantity, float(item.unit_price))
    
    async def find_by_id(self, order_id: str):
        async with self._pool.acquire() as conn:
            row = await conn.fetchrow("SELECT * FROM orders WHERE id = $1", order_id)
            if not row:
                return None
            items_rows = await conn.fetch("SELECT * FROM order_items WHERE order_id = $1", order_id)
            return self._to_domain(row, items_rows)
    
    def _to_domain(self, row, items_rows) -> Order:
        items = [
            OrderItem(
                product_id=r["product_id"],
                quantity=r["quantity"],
                unit_price=Decimal(str(r["unit_price"])),
            )
            for r in items_rows
        ]
        return Order(
            id=row["id"],
            user_id=row["user_id"],
            items=items,
            status=OrderStatus(row["status"]),
            created_at=row["created_at"],
            updated_at=row["updated_at"],
        )

# adapters/outbound/stripe/payment_gateway.py
import stripe
from domain.ports.payment import PaymentGateway

class StripePaymentGateway(PaymentGateway):
    def __init__(self, api_key: str):
        stripe.api_key = api_key
    
    async def charge(self, order_id: str, user_id: str, amount_cents: int, currency: str = "usd") -> str:
        intent = stripe.PaymentIntent.create(
            amount=amount_cents,
            currency=currency,
            metadata={"order_id": order_id, "user_id": user_id},
            idempotency_key=f"charge-{order_id}",
        )
        return intent.id
    
    async def refund(self, payment_id: str, amount_cents: int) -> None:
        stripe.Refund.create(payment_intent=payment_id, amount=amount_cents)
```

### 6. Inbound Adapter — HTTP
```python
# adapters/inbound/http/order_routes.py
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from domain.services.order_service import OrderService
from composition.container import get_order_service

router = APIRouter(prefix="/orders", tags=["orders"])

class PlaceOrderRequest(BaseModel):
    user_id: str
    items: list[dict]

@router.post("/")
async def place_order(
    request: PlaceOrderRequest,
    service: OrderService = Depends(get_order_service),
):
    try:
        order = await service.place_order(request.user_id, request.items)
        return {"order_id": order.id, "status": order.status.value, "total": str(order.total)}
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

# composition/container.py — wire dependencies
import asyncpg
from functools import lru_cache
from domain.services.order_service import OrderService
from adapters.outbound.postgres.order_repository import PostgresOrderRepository
from adapters.outbound.stripe.payment_gateway import StripePaymentGateway
from adapters.outbound.kafka.event_bus import KafkaEventBus

@lru_cache
def get_order_service() -> OrderService:
    pool = asyncpg.create_pool(dsn=settings.DATABASE_URL)
    return OrderService(
        order_repo=PostgresOrderRepository(pool),
        payment=StripePaymentGateway(api_key=settings.STRIPE_KEY),
        event_bus=KafkaEventBus(brokers=settings.KAFKA_BROKERS),
    )
```

## Key Commands Reference

```bash
# Project setup (Python)
python -m venv venv && source venv/bin/activate
pip install fastapi uvicorn asyncpg stripe kafka-python pytest pytest-asyncio

# Run tests (only domain, no infrastructure needed)
pytest tests/domain/ -v

# Run integration tests (requires DB/services)
pytest tests/integration/ -v --cov=domain

# Run application
uvicorn adapters.inbound.http.app:app --reload
```

## Common Patterns

### Pattern 1: In-Memory Adapter for Testing
```python
# tests/fakes/in_memory_order_repository.py
from domain.ports.repositories import OrderRepository
from domain.models.order import Order

class InMemoryOrderRepository(OrderRepository):
    """Fake adapter — no database needed for domain tests."""
    
    def __init__(self):
        self._store: dict[str, Order] = {}
    
    async def save(self, order: Order) -> None:
        self._store[order.id] = order
    
    async def find_by_id(self, order_id: str):
        return self._store.get(order_id)
    
    async def find_by_user(self, user_id: str, limit: int = 20):
        return [o for o in self._store.values() if o.user_id == user_id][:limit]
    
    async def update(self, order: Order) -> None:
        self._store[order.id] = order

# tests/domain/test_order_service.py — pure domain tests, no mocks for DB
import pytest
from domain.services.order_service import OrderService
from tests.fakes.in_memory_order_repository import InMemoryOrderRepository
from tests.fakes.fake_payment_gateway import FakePaymentGateway
from tests.fakes.in_memory_event_bus import InMemoryEventBus

@pytest.fixture
def service():
    return OrderService(
        order_repo=InMemoryOrderRepository(),
        payment=FakePaymentGateway(),
        event_bus=InMemoryEventBus(),
    )

async def test_place_order_creates_order_in_pending_status(service):
    items = [{"product_id": "p1", "quantity": 2, "unit_price": "10.00"}]
    order = await service.place_order(user_id="user-1", items_data=items)
    
    assert order.status.value == "pending"
    assert order.total == Decimal("20.00")
    assert order.user_id == "user-1"
```

### Pattern 2: Multiple Inbound Adapters (Same Domain)
```python
# adapters/inbound/cli/order_commands.py — CLI uses same domain service
import click
from composition.container import get_order_service
import asyncio

@click.command()
@click.option("--user-id", required=True)
@click.option("--product", multiple=True, help="product_id:qty:price")
def place_order(user_id, product):
    """Same OrderService as HTTP adapter — domain reused."""
    items = [{"product_id": p.split(":")[0], "quantity": int(p.split(":")[1]),
              "unit_price": p.split(":")[2]} for p in product]
    
    service = get_order_service()
    order = asyncio.run(service.place_order(user_id, items))
    click.echo(f"Order created: {order.id} — Total: ${order.total}")
```

### Pattern 3: Adapter for External API (Outbound)
```typescript
// TypeScript hexagonal implementation
// domain/ports/notification.ts — port interface
interface NotificationPort {
  sendOrderConfirmation(userId: string, orderId: string, amount: number): Promise<void>;
  sendShipmentNotification(userId: string, orderId: string, trackingNumber: string): Promise<void>;
}

// adapters/outbound/sendgrid-notification.ts — concrete adapter
class SendgridNotificationAdapter implements NotificationPort {
  constructor(private readonly apiKey: string, private readonly fromEmail: string) {}
  
  async sendOrderConfirmation(userId: string, orderId: string, amount: number): Promise<void> {
    const userEmail = await this.getUserEmail(userId);
    await this.sendEmail({
      to: userEmail,
      subject: `Order ${orderId} confirmed`,
      body: `Your order for $${amount.toFixed(2)} has been confirmed.`,
    });
  }
}
```

## Pitfalls to Avoid

1. **Domain importing from adapters**: The golden rule: domain code (models, ports, services) must never import from `adapters/`. Any violation means business logic is coupled to infrastructure. Enforce this with a linter rule or a pre-commit check: `grep -r "from adapters" src/domain/ && exit 1`. The dependency arrow always points inward — adapters depend on ports, never the reverse.

2. **Ports that are too granular or too coarse**: A port with 20 methods is hard to implement and hard to fake for tests. A port with 1 method per adapter is over-engineering. Design ports around business capabilities, not database operations. `OrderRepository` with 4 methods (save, find_by_id, find_by_user, update) is right-sized. Avoid `OrderRepository.execute_raw_sql()` — that leaks infrastructure concerns into the port.

3. **Putting orchestration logic in adapters**: An HTTP handler that does `if payment_failed: refund_inventory; send_email` is not an adapter — it's a service that belongs in the domain. Adapters should translate (HTTP request → domain call → HTTP response), not orchestrate business logic. If your adapter is more than 10-15 lines of business logic, it needs to move to a domain service.

## Related Skills

- `clean-architecture` — Related architectural style by Robert Martin
- `cqrs-patterns` — Hexagonal architecture + CQRS for scalability
- `event-driven-architecture` — Event ports and adapters for async systems
- `saga-pattern` — Orchestration within hexagonal boundaries

## GitNexus Index

```json
{
  "skill": "hexagonal-architecture",
  "category": "backend",
  "triggers": ["hexagonal architecture", "ports and adapters", "clean architecture", "domain core", "adapter pattern", "dependency inversion", "testable architecture"],
  "outputs": ["port interface", "adapter implementation", "domain service", "fake adapter", "composition root"],
  "complexity": "high",
  "tools": ["python", "typescript", "fastapi", "pytest", "asyncpg"]
}
```
