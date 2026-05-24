---
name: clean-architecture
description: Apply Robert C. Martin's Clean Architecture to build systems where business rules are independent of frameworks, databases, and UIs. Covers the dependency rule, use cases, entities, interface adapters, and frameworks/drivers layers with TypeScript and Python examples.
version: 1.0.0
tags: [clean-architecture, architecture, use-cases, entities, dependency-rule, solid, ddd, python, typescript]
---

# Clean Architecture

## Overview

Clean Architecture organizes code into concentric circles — Entities, Use Cases, Interface Adapters, and Frameworks/Drivers — where source-code dependencies point only inward. The fundamental rule: inner circles know nothing about outer circles. Business rules (entities and use cases) are completely isolated from I/O details like databases, HTTP, or UI frameworks, making them testable, swappable, and long-lived.

## When to Use

- Building applications where the business logic must outlive any particular framework
- Teams frequently switch databases, ORMs, or HTTP libraries and want zero business-rule changes
- Codebases that are painful to unit test because domain logic is entangled with framework code
- Microservices or monoliths where you want clear boundaries between business and infrastructure
- Replacing one data source (e.g., REST → GraphQL, Postgres → DynamoDB) without touching use cases
- Projects following Domain-Driven Design that need a clear layering strategy

## Step-by-Step Workflow

### 1. Directory Structure

```
src/
├── domain/                  # Entities — enterprise business rules
│   ├── entities/
│   │   ├── Order.ts
│   │   └── User.ts
│   └── value-objects/
│       └── Money.ts
├── application/             # Use Cases — application business rules
│   ├── ports/               # Abstract interfaces (ports)
│   │   ├── OrderRepository.ts
│   │   └── PaymentGateway.ts
│   └── use-cases/
│       ├── CreateOrder.ts
│       └── ProcessPayment.ts
├── adapters/                # Interface Adapters — controllers, presenters, gateways
│   ├── controllers/
│   │   └── OrderController.ts
│   ├── presenters/
│   │   └── OrderPresenter.ts
│   └── gateways/
│       ├── PostgresOrderRepository.ts
│       └── StripePaymentGateway.ts
└── infrastructure/          # Frameworks & Drivers — Express, Prisma, etc.
    ├── http/
    │   └── server.ts
    └── database/
        └── prisma-client.ts
```

### 2. Entities — Enterprise Business Rules

```typescript
// domain/entities/Order.ts
// Pure business objects with enterprise-wide rules — no framework imports

export type OrderStatus = "pending" | "confirmed" | "shipped" | "cancelled";

export class Order {
  readonly id: string;
  readonly customerId: string;
  readonly items: readonly OrderItem[];
  readonly status: OrderStatus;
  readonly createdAt: Date;

  constructor(props: {
    id: string;
    customerId: string;
    items: OrderItem[];
    status?: OrderStatus;
    createdAt?: Date;
  }) {
    this.id = props.id;
    this.customerId = props.customerId;
    this.items = Object.freeze([...props.items]);
    this.status = props.status ?? "pending";
    this.createdAt = props.createdAt ?? new Date();
  }

  get total(): Money {
    return this.items.reduce(
      (sum, item) => sum.add(item.unitPrice.multiply(item.quantity)),
      Money.zero("USD")
    );
  }

  confirm(): Order {
    if (this.status !== "pending") {
      throw new Error(`Cannot confirm order in status: ${this.status}`);
    }
    return new Order({ ...this, status: "confirmed" });
  }

  cancel(): Order {
    if (this.status === "shipped") {
      throw new Error("Cannot cancel a shipped order");
    }
    return new Order({ ...this, status: "cancelled" });
  }
}

export class OrderItem {
  constructor(
    readonly productId: string,
    readonly name: string,
    readonly quantity: number,
    readonly unitPrice: Money
  ) {
    if (quantity <= 0) throw new Error("Quantity must be positive");
  }
}

// domain/value-objects/Money.ts
export class Money {
  constructor(
    readonly amount: number,  // in cents
    readonly currency: string
  ) {}

  static zero(currency: string): Money {
    return new Money(0, currency);
  }

  add(other: Money): Money {
    if (other.currency !== this.currency) throw new Error("Currency mismatch");
    return new Money(this.amount + other.amount, this.currency);
  }

  multiply(factor: number): Money {
    return new Money(Math.round(this.amount * factor), this.currency);
  }

  equals(other: Money): boolean {
    return this.amount === other.amount && this.currency === other.currency;
  }

  toString(): string {
    return `${(this.amount / 100).toFixed(2)} ${this.currency}`;
  }
}
```

### 3. Use Cases — Application Business Rules

```typescript
// application/ports/OrderRepository.ts
// Abstract interface — use cases depend on this, not on Prisma/Postgres
export interface OrderRepository {
  findById(id: string): Promise<Order | null>;
  findByCustomerId(customerId: string): Promise<Order[]>;
  save(order: Order): Promise<void>;
  delete(id: string): Promise<void>;
}

// application/ports/PaymentGateway.ts
export interface PaymentGateway {
  charge(orderId: string, amount: Money, customerId: string): Promise<PaymentResult>;
  refund(paymentId: string, amount: Money): Promise<void>;
}

export type PaymentResult =
  | { success: true; paymentId: string }
  | { success: false; reason: string };

// application/ports/EventBus.ts
export interface EventBus {
  publish(event: DomainEvent): Promise<void>;
}

// application/use-cases/CreateOrder.ts
import { Order, OrderItem } from "../../domain/entities/Order";
import { Money } from "../../domain/value-objects/Money";
import { OrderRepository } from "../ports/OrderRepository";
import { EventBus } from "../ports/EventBus";
import { randomUUID } from "crypto";

export interface CreateOrderInput {
  customerId: string;
  items: Array<{
    productId: string;
    name: string;
    quantity: number;
    unitPriceCents: number;
    currency: string;
  }>;
}

export interface CreateOrderOutput {
  orderId: string;
  total: string;
  status: string;
}

export class CreateOrderUseCase {
  // Depends only on abstractions (ports) — never on Prisma, Express, etc.
  constructor(
    private readonly orderRepo: OrderRepository,
    private readonly eventBus: EventBus
  ) {}

  async execute(input: CreateOrderInput): Promise<CreateOrderOutput> {
    const items = input.items.map(
      (i) =>
        new OrderItem(i.productId, i.name, i.quantity, new Money(i.unitPriceCents, i.currency))
    );

    const order = new Order({
      id: randomUUID(),
      customerId: input.customerId,
      items,
    });

    await this.orderRepo.save(order);
    await this.eventBus.publish({
      type: "OrderCreated",
      payload: { orderId: order.id, customerId: order.customerId },
      occurredAt: new Date(),
    });

    return {
      orderId: order.id,
      total: order.total.toString(),
      status: order.status,
    };
  }
}

// application/use-cases/ProcessPayment.ts
export class ProcessPaymentUseCase {
  constructor(
    private readonly orderRepo: OrderRepository,
    private readonly paymentGateway: PaymentGateway,
    private readonly eventBus: EventBus
  ) {}

  async execute(orderId: string, customerId: string): Promise<{ paymentId: string }> {
    const order = await this.orderRepo.findById(orderId);
    if (!order) throw new Error(`Order not found: ${orderId}`);

    const confirmed = order.confirm();
    const result = await this.paymentGateway.charge(orderId, order.total, customerId);

    if (!result.success) {
      throw new Error(`Payment failed: ${result.reason}`);
    }

    await this.orderRepo.save(confirmed);
    await this.eventBus.publish({
      type: "PaymentProcessed",
      payload: { orderId, paymentId: result.paymentId },
      occurredAt: new Date(),
    });

    return { paymentId: result.paymentId };
  }
}
```

### 4. Interface Adapters — Controllers and Gateways

```typescript
// adapters/controllers/OrderController.ts
// Translates HTTP into use-case DTOs — no business logic here
import { Request, Response } from "express";
import { CreateOrderUseCase } from "../../application/use-cases/CreateOrder";

export class OrderController {
  constructor(private readonly createOrder: CreateOrderUseCase) {}

  async create(req: Request, res: Response): Promise<void> {
    try {
      const result = await this.createOrder.execute({
        customerId: req.body.customerId,
        items: req.body.items,
      });
      res.status(201).json(result);
    } catch (err) {
      res.status(400).json({ error: (err as Error).message });
    }
  }
}

// adapters/gateways/PostgresOrderRepository.ts
// Implements the port — isolated in the adapter ring
import { PrismaClient } from "@prisma/client";
import { Order, OrderItem } from "../../domain/entities/Order";
import { Money } from "../../domain/value-objects/Money";
import { OrderRepository } from "../../application/ports/OrderRepository";

export class PostgresOrderRepository implements OrderRepository {
  constructor(private readonly prisma: PrismaClient) {}

  async findById(id: string): Promise<Order | null> {
    const row = await this.prisma.order.findUnique({
      where: { id },
      include: { items: true },
    });
    if (!row) return null;
    return this.toDomain(row);
  }

  async save(order: Order): Promise<void> {
    await this.prisma.order.upsert({
      where: { id: order.id },
      create: this.toPersistence(order),
      update: this.toPersistence(order),
    });
  }

  async findByCustomerId(customerId: string): Promise<Order[]> {
    const rows = await this.prisma.order.findMany({
      where: { customerId },
      include: { items: true },
    });
    return rows.map((r) => this.toDomain(r));
  }

  async delete(id: string): Promise<void> {
    await this.prisma.order.delete({ where: { id } });
  }

  private toDomain(row: any): Order {
    return new Order({
      id: row.id,
      customerId: row.customerId,
      status: row.status,
      createdAt: row.createdAt,
      items: row.items.map(
        (i: any) =>
          new OrderItem(i.productId, i.name, i.quantity, new Money(i.unitPriceCents, i.currency))
      ),
    });
  }

  private toPersistence(order: Order) {
    return {
      id: order.id,
      customerId: order.customerId,
      status: order.status,
      createdAt: order.createdAt,
      items: {
        deleteMany: {},
        create: order.items.map((i) => ({
          productId: i.productId,
          name: i.name,
          quantity: i.quantity,
          unitPriceCents: i.unitPrice.amount,
          currency: i.unitPrice.currency,
        })),
      },
    };
  }
}
```

### 5. Composition Root — Wiring Everything Together

```typescript
// infrastructure/http/server.ts
// The ONLY place where concrete implementations are instantiated
import express from "express";
import { PrismaClient } from "@prisma/client";
import { PostgresOrderRepository } from "../../adapters/gateways/PostgresOrderRepository";
import { StripePaymentGateway } from "../../adapters/gateways/StripePaymentGateway";
import { InMemoryEventBus } from "../../adapters/gateways/InMemoryEventBus";
import { CreateOrderUseCase } from "../../application/use-cases/CreateOrder";
import { ProcessPaymentUseCase } from "../../application/use-cases/ProcessPayment";
import { OrderController } from "../../adapters/controllers/OrderController";

const prisma = new PrismaClient();
const orderRepo = new PostgresOrderRepository(prisma);
const paymentGateway = new StripePaymentGateway(process.env.STRIPE_KEY!);
const eventBus = new InMemoryEventBus();

const createOrderUseCase = new CreateOrderUseCase(orderRepo, eventBus);
const processPaymentUseCase = new ProcessPaymentUseCase(orderRepo, paymentGateway, eventBus);

const orderController = new OrderController(createOrderUseCase);

const app = express();
app.use(express.json());
app.post("/orders", (req, res) => orderController.create(req, res));
app.post("/orders/:id/pay", async (req, res) => {
  try {
    const result = await processPaymentUseCase.execute(req.params.id, req.body.customerId);
    res.json(result);
  } catch (err) {
    res.status(400).json({ error: (err as Error).message });
  }
});

app.listen(3000, () => console.log("Server running on :3000"));
```

### 6. Testing — Use Cases in Full Isolation

```typescript
// tests/use-cases/CreateOrder.test.ts
import { CreateOrderUseCase } from "../../src/application/use-cases/CreateOrder";

// In-memory fakes — no database, no Stripe, no HTTP
class InMemoryOrderRepository {
  private orders = new Map<string, any>();
  async findById(id: string) { return this.orders.get(id) ?? null; }
  async findByCustomerId(cid: string) {
    return [...this.orders.values()].filter(o => o.customerId === cid);
  }
  async save(order: any) { this.orders.set(order.id, order); }
  async delete(id: string) { this.orders.delete(id); }
}

class InMemoryEventBus {
  events: any[] = [];
  async publish(event: any) { this.events.push(event); }
}

describe("CreateOrderUseCase", () => {
  let repo: InMemoryOrderRepository;
  let bus: InMemoryEventBus;
  let useCase: CreateOrderUseCase;

  beforeEach(() => {
    repo = new InMemoryOrderRepository();
    bus = new InMemoryEventBus();
    useCase = new CreateOrderUseCase(repo, bus);
  });

  it("creates an order and publishes OrderCreated event", async () => {
    const result = await useCase.execute({
      customerId: "cust_1",
      items: [{ productId: "prod_1", name: "Widget", quantity: 2, unitPriceCents: 999, currency: "USD" }],
    });

    expect(result.status).toBe("pending");
    expect(result.total).toBe("19.98 USD");
    expect(bus.events).toHaveLength(1);
    expect(bus.events[0].type).toBe("OrderCreated");
  });
});
```

## Key Commands Reference

```bash
# Install dependencies (TypeScript project)
npm install --save-dev typescript ts-node @types/node

# Prisma setup for the gateway adapter
npm install @prisma/client prisma
npx prisma init
npx prisma generate

# Python clean architecture scaffolding
pip install injector fastapi sqlalchemy

# Lint for circular imports (catches dependency-rule violations)
npx madge --circular --extensions ts src/
# If clean-architecture is violated, madge will show domain → adapter cycles

# Run only domain+application tests (zero I/O)
npx jest src/domain src/application --coverage

# Architecture fitness function with deptry
pip install deptry
deptry src/

# Enforce layer boundaries with eslint-plugin-boundaries
npm install --save-dev eslint-plugin-boundaries
# Add to .eslintrc.json:
# "plugins": ["boundaries"],
# "rules": { "boundaries/element-types": ["error", { ... }] }
```

## Common Patterns

### Pattern 1: Repository + Fake for Integration-Free Testing

```typescript
// Use a fake repository to test use cases without a real database
// This is faster, deterministic, and CI-friendly

class FakeOrderRepository implements OrderRepository {
  public orders: Map<string, Order> = new Map();

  async findById(id: string): Promise<Order | null> {
    return this.orders.get(id) ?? null;
  }

  async findByCustomerId(cid: string): Promise<Order[]> {
    return [...this.orders.values()].filter(o => o.customerId === cid);
  }

  async save(order: Order): Promise<void> {
    this.orders.set(order.id, order);
  }

  async delete(id: string): Promise<void> {
    this.orders.delete(id);
  }
}

// In tests — no Prisma, no DB migrations needed
const repo = new FakeOrderRepository();
const useCase = new CreateOrderUseCase(repo, new InMemoryEventBus());
```

### Pattern 2: Presenter Pattern for Output Formatting

```typescript
// Interface adapters contain presenters that format use-case output for the UI
// Use case returns a domain object; presenter transforms it for the HTTP response

export interface OrderPresenter<T> {
  present(order: Order): T;
}

export class JsonOrderPresenter implements OrderPresenter<object> {
  present(order: Order) {
    return {
      id: order.id,
      status: order.status,
      total: {
        amount: order.total.amount / 100,
        currency: order.total.currency,
        formatted: order.total.toString(),
      },
      itemCount: order.items.length,
      createdAt: order.createdAt.toISOString(),
    };
  }
}

// Use case returns Order; controller uses presenter for output
async create(req: Request, res: Response) {
  const order = await this.createOrder.executeForDomain(input);
  res.json(this.presenter.present(order));
}
```

### Pattern 3: Python Clean Architecture with Dataclasses

```python
# domain/entities.py — pure Python, zero framework imports
from dataclasses import dataclass, field, replace
from typing import Tuple
from decimal import Decimal
from enum import Enum

class OrderStatus(Enum):
    PENDING = "pending"
    CONFIRMED = "confirmed"
    CANCELLED = "cancelled"

@dataclass(frozen=True)
class Money:
    amount: Decimal  # in major units
    currency: str

    def add(self, other: "Money") -> "Money":
        assert self.currency == other.currency, "Currency mismatch"
        return Money(self.amount + other.amount, self.currency)

@dataclass(frozen=True)
class OrderItem:
    product_id: str
    name: str
    quantity: int
    unit_price: Money

    @property
    def subtotal(self) -> Money:
        return Money(self.unit_price.amount * self.quantity, self.unit_price.currency)

@dataclass(frozen=True)
class Order:
    id: str
    customer_id: str
    items: Tuple[OrderItem, ...]
    status: OrderStatus = OrderStatus.PENDING

    @property
    def total(self) -> Money:
        return sum(
            (i.subtotal for i in self.items),
            Money(Decimal("0"), self.items[0].unit_price.currency if self.items else "USD")
        )

    def confirm(self) -> "Order":
        if self.status != OrderStatus.PENDING:
            raise ValueError(f"Cannot confirm order in {self.status}")
        return replace(self, status=OrderStatus.CONFIRMED)

# application/ports.py — abstract interfaces only
from abc import ABC, abstractmethod

class OrderRepository(ABC):
    @abstractmethod
    def find_by_id(self, order_id: str) -> Order | None: ...

    @abstractmethod
    def save(self, order: Order) -> None: ...

# application/use_cases.py
from dataclasses import dataclass

@dataclass
class CreateOrderInput:
    customer_id: str
    items: list[dict]

class CreateOrderUseCase:
    def __init__(self, repo: OrderRepository):
        self.repo = repo

    def execute(self, inp: CreateOrderInput) -> dict:
        import uuid
        items = tuple(
            OrderItem(
                product_id=i["product_id"],
                name=i["name"],
                quantity=i["quantity"],
                unit_price=Money(Decimal(str(i["unit_price"])), i.get("currency", "USD")),
            )
            for i in inp.items
        )
        order = Order(id=str(uuid.uuid4()), customer_id=inp.customer_id, items=items)
        self.repo.save(order)
        return {"order_id": order.id, "total": str(order.total.amount), "status": order.status.value}
```

## Pitfalls to Avoid

1. **Importing framework types into entities or use cases**: Adding `from sqlalchemy import Column` or `import express from "express"` inside the domain or application layers violates the dependency rule immediately. Use interfaces/abstract classes as ports; import only in adapters. Use a linter (madge, eslint-plugin-boundaries) to catch violations automatically in CI.

2. **Anemic domain model**: Entities that are just data bags with no behavior (pure DTOs with no `confirm()`, `cancel()`, validation) force business logic to leak into use cases or, worse, into controllers. Put enterprise-wide rules directly on entities — an entity should reject invalid state transitions itself.

3. **Treating the repository as a query engine**: Repositories should return domain objects, not raw rows or query builders. If you need complex queries, add a dedicated read model or query service instead of adding `findOrdersByStatusAndDateRange` as a repository method that returns SQL-shaped data.

## Related Skills

- `hexagonal-architecture` — Ports and adapters as a complementary architectural style
- `functional-python` — Immutable entities and pure functions within the domain layer
- `saga-pattern` — Distributed use-case coordination across service boundaries
- `cqrs-patterns` — Command/query responsibility segregation, naturally aligned with clean architecture use cases

## GitNexus Index

```json
{
  "skill": "clean-architecture",
  "category": "backend",
  "triggers": ["clean architecture", "use case layer", "dependency rule", "entities use cases", "ports adapters clean", "uncle bob architecture", "framework independent business logic"],
  "outputs": ["entity class", "use case class", "port interface", "adapter implementation", "composition root"],
  "complexity": "high",
  "tools": ["typescript", "python", "prisma", "express", "fastapi", "madge", "eslint-plugin-boundaries"]
}
```
