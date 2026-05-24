---
name: database-cdc-patterns
description: Implement Change Data Capture (CDC) to stream database changes as events. Covers Debezium with Kafka, PostgreSQL logical replication, Supabase Realtime, event sourcing via CDC, and building downstream read models from database change streams.
version: 1.0.0
tags: [cdc, change-data-capture, debezium, kafka, postgresql, logical-replication, event-sourcing, supabase-realtime]
---

# Database CDC Patterns

## Overview

Change Data Capture (CDC) turns your database's write-ahead log (WAL) into a reliable event stream — every INSERT, UPDATE, and DELETE becomes a structured event that downstream consumers can react to in real time. CDC solves the dual-write problem (updating DB and publishing events atomically), enables cache invalidation, powers read model updates in CQRS, and drives data pipelines without polling. Debezium is the standard open-source CDC connector; PostgreSQL supports it natively via logical replication.

## When to Use

- Keeping a search index (Elasticsearch, Typesense) in sync with your database without dual-writes
- Invalidating Redis cache entries exactly when the underlying data changes
- Building real-time analytics read models from OLTP database changes
- Event sourcing: treat the WAL as your event log and derive aggregate state
- Microservices that need to react to data changes in another service's database
- Audit logging: capture every change to sensitive tables without application-level hooks
- Cross-region database replication for disaster recovery

## Step-by-Step Workflow

### 1. PostgreSQL Logical Replication Setup

```sql
-- Enable logical replication in postgresql.conf
-- wal_level = logical
-- max_replication_slots = 10
-- max_wal_senders = 10

-- Create a replication slot (Debezium will use this)
SELECT pg_create_logical_replication_slot('debezium_slot', 'pgoutput');

-- Create a publication for the tables you want to capture
CREATE PUBLICATION my_publication FOR TABLE orders, products, users;
-- Or capture all tables:
-- CREATE PUBLICATION my_publication FOR ALL TABLES;

-- Grant replication privileges to the Debezium user
CREATE ROLE debezium_user WITH LOGIN REPLICATION PASSWORD 'strong_password';
GRANT SELECT ON ALL TABLES IN SCHEMA public TO debezium_user;
GRANT USAGE ON SCHEMA public TO debezium_user;

-- Verify replication slot
SELECT slot_name, plugin, slot_type, active FROM pg_replication_slots;

-- Monitor WAL lag (if this grows, consumers aren't keeping up)
SELECT
  slot_name,
  pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn) AS lag_bytes,
  pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)) AS lag
FROM pg_replication_slots;
```

### 2. Debezium PostgreSQL Connector

```json
// POST to Kafka Connect REST API: http://localhost:8083/connectors
{
  "name": "orders-cdc-connector",
  "config": {
    "connector.class": "io.debezium.connector.postgresql.PostgresConnector",
    "database.hostname": "postgres",
    "database.port": "5432",
    "database.user": "debezium_user",
    "database.password": "strong_password",
    "database.dbname": "myapp",
    "database.server.name": "myapp",
    "plugin.name": "pgoutput",
    "slot.name": "debezium_slot",
    "publication.name": "my_publication",
    "table.include.list": "public.orders,public.products",
    "transforms": "unwrap",
    "transforms.unwrap.type": "io.debezium.transforms.ExtractNewRecordState",
    "transforms.unwrap.drop.tombstones": "false",
    "transforms.unwrap.add.fields": "op,table,source.ts_ms",
    "key.converter": "org.apache.kafka.connect.json.JsonConverter",
    "value.converter": "org.apache.kafka.connect.json.JsonConverter",
    "key.converter.schemas.enable": "false",
    "value.converter.schemas.enable": "false",
    "heartbeat.interval.ms": "5000",
    "topic.prefix": "cdc"
  }
}
```

```yaml
# docker-compose.yml for local CDC stack
version: "3.8"
services:
  postgres:
    image: postgres:16
    environment:
      POSTGRES_DB: myapp
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
    command: >
      postgres
        -c wal_level=logical
        -c max_replication_slots=10
        -c max_wal_senders=10
    ports:
      - "5432:5432"

  zookeeper:
    image: confluentinc/cp-zookeeper:7.6.0
    environment:
      ZOOKEEPER_CLIENT_PORT: 2181

  kafka:
    image: confluentinc/cp-kafka:7.6.0
    depends_on: [zookeeper]
    environment:
      KAFKA_BROKER_ID: 1
      KAFKA_ZOOKEEPER_CONNECT: zookeeper:2181
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://kafka:9092
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 1
    ports:
      - "9092:9092"

  connect:
    image: debezium/connect:2.6
    depends_on: [kafka, postgres]
    environment:
      BOOTSTRAP_SERVERS: kafka:9092
      GROUP_ID: 1
      CONFIG_STORAGE_TOPIC: connect-configs
      OFFSET_STORAGE_TOPIC: connect-offsets
      STATUS_STORAGE_TOPIC: connect-status
    ports:
      - "8083:8083"
```

### 3. Python CDC Consumer

```python
# pip install confluent-kafka pydantic
from confluent_kafka import Consumer, KafkaError
from pydantic import BaseModel
from typing import Callable, Any
import json
import logging

class CDCEvent(BaseModel):
    operation: str  # "c" (create), "u" (update), "d" (delete), "r" (read/snapshot)
    table: str
    before: dict | None = None
    after: dict | None = None
    timestamp_ms: int

    @property
    def is_create(self) -> bool: return self.operation == "c"
    @property
    def is_update(self) -> bool: return self.operation == "u"
    @property
    def is_delete(self) -> bool: return self.operation == "d"

def parse_debezium_event(message_value: dict) -> CDCEvent | None:
    """Parse a Debezium CDC message into a typed event."""
    op = message_value.get("__op") or message_value.get("op")
    if not op:
        return None
    return CDCEvent(
        operation=op,
        table=message_value.get("__table") or message_value.get("source", {}).get("table", "unknown"),
        before=message_value.get("before"),
        after=message_value.get("after"),
        timestamp_ms=message_value.get("__source_ts_ms") or message_value.get("ts_ms", 0),
    )

class CDCConsumer:
    def __init__(self, bootstrap_servers: str, group_id: str, topics: list[str]):
        self.consumer = Consumer({
            "bootstrap.servers": bootstrap_servers,
            "group.id": group_id,
            "auto.offset.reset": "earliest",
            "enable.auto.commit": False,  # Manual commit for at-least-once guarantee
        })
        self.consumer.subscribe(topics)
        self.handlers: dict[str, list[Callable]] = {}

    def on(self, table: str):
        """Decorator to register a handler for a specific table."""
        def decorator(fn: Callable):
            self.handlers.setdefault(table, []).append(fn)
            return fn
        return decorator

    def run(self, max_messages: int | None = None):
        count = 0
        try:
            while max_messages is None or count < max_messages:
                msg = self.consumer.poll(timeout=1.0)
                if msg is None:
                    continue
                if msg.error():
                    if msg.error().code() != KafkaError._PARTITION_EOF:
                        logging.error(f"Kafka error: {msg.error()}")
                    continue

                try:
                    value = json.loads(msg.value())
                    event = parse_debezium_event(value)
                    if event and event.table in self.handlers:
                        for handler in self.handlers[event.table]:
                            handler(event)
                    self.consumer.commit(asynchronous=False)
                    count += 1
                except Exception as e:
                    logging.error(f"Error processing message: {e}")
        finally:
            self.consumer.close()

# Usage: sync orders to Elasticsearch
import httpx

consumer = CDCConsumer(
    bootstrap_servers="localhost:9092",
    group_id="search-indexer",
    topics=["cdc.public.orders"],
)

@consumer.on("orders")
def sync_order_to_search(event: CDCEvent):
    if event.is_delete:
        httpx.delete(f"http://localhost:9200/orders/_doc/{event.before['id']}")
    elif event.is_create or event.is_update:
        doc = event.after
        httpx.put(f"http://localhost:9200/orders/_doc/{doc['id']}", json=doc)

consumer.run()
```

### 4. Supabase Realtime CDC

```typescript
// npm install @supabase/supabase-js
import { createClient } from "@supabase/supabase-js";

const supabase = createClient(
  process.env.SUPABASE_URL!,
  process.env.SUPABASE_ANON_KEY!
);

// Listen for changes on a specific table
const channel = supabase
  .channel("orders-changes")
  .on(
    "postgres_changes",
    {
      event: "*",   // INSERT | UPDATE | DELETE | *
      schema: "public",
      table: "orders",
      filter: "status=eq.pending", // Optional: only get pending orders
    },
    (payload) => {
      const { eventType, old: before, new: after } = payload;
      switch (eventType) {
        case "INSERT":
          console.log("New order:", after);
          invalidateOrdersCache();
          break;
        case "UPDATE":
          console.log("Order updated:", { before, after });
          if (after.status === "shipped") notifyCustomer(after);
          break;
        case "DELETE":
          console.log("Order deleted:", before);
          break;
      }
    }
  )
  .subscribe((status) => {
    console.log("Subscription status:", status);
  });

// Cleanup on component unmount
// supabase.removeChannel(channel);

// Enable Realtime for a table via SQL (in Supabase Dashboard or migration)
// ALTER PUBLICATION supabase_realtime ADD TABLE orders;
```

### 5. Building a Read Model from CDC Events

```python
# CQRS read model: maintain a denormalized "order summary" table
# updated by CDC events from the orders and order_items tables

import psycopg2
from dataclasses import dataclass

@dataclass
class OrderSummary:
    order_id: str
    customer_name: str
    item_count: int
    total_amount: float
    status: str

class OrderSummaryProjection:
    def __init__(self, db_url: str):
        self.conn = psycopg2.connect(db_url)
        self._ensure_table()

    def _ensure_table(self):
        with self.conn.cursor() as cur:
            cur.execute("""
                CREATE TABLE IF NOT EXISTS order_summaries (
                    order_id UUID PRIMARY KEY,
                    customer_name TEXT,
                    item_count INTEGER DEFAULT 0,
                    total_amount DECIMAL(10,2) DEFAULT 0,
                    status TEXT,
                    updated_at TIMESTAMPTZ DEFAULT NOW()
                )
            """)
        self.conn.commit()

    def handle_order_event(self, event: CDCEvent):
        if event.is_create or event.is_update:
            order = event.after
            with self.conn.cursor() as cur:
                cur.execute("""
                    INSERT INTO order_summaries (order_id, customer_name, status)
                    VALUES (%s, %s, %s)
                    ON CONFLICT (order_id) DO UPDATE SET
                        status = EXCLUDED.status,
                        customer_name = EXCLUDED.customer_name,
                        updated_at = NOW()
                """, (order["id"], order.get("customer_name", ""), order["status"]))
            self.conn.commit()

    def handle_order_item_event(self, event: CDCEvent):
        """Update item count and total when order items change."""
        order_id = (event.after or event.before or {}).get("order_id")
        if not order_id:
            return

        with self.conn.cursor() as cur:
            cur.execute("""
                UPDATE order_summaries
                SET
                    item_count = (SELECT COUNT(*) FROM order_items WHERE order_id = %s),
                    total_amount = (SELECT COALESCE(SUM(price * quantity), 0) FROM order_items WHERE order_id = %s),
                    updated_at = NOW()
                WHERE order_id = %s
            """, (order_id, order_id, order_id))
        self.conn.commit()
```

### 6. CDC Dead Letter Queue and Error Handling

```python
import json
from confluent_kafka import Producer

class CDCConsumerWithDLQ(CDCConsumer):
    def __init__(self, *args, dlq_topic: str, **kwargs):
        super().__init__(*args, **kwargs)
        self.dlq_topic = dlq_topic
        self.producer = Producer({"bootstrap.servers": args[0]})

    def _send_to_dlq(self, msg_value: str, error: str, topic: str):
        """Send failed messages to DLQ for manual inspection/retry."""
        dlq_payload = {
            "original_topic": topic,
            "payload": msg_value,
            "error": error,
            "timestamp": __import__("time").time(),
        }
        self.producer.produce(self.dlq_topic, json.dumps(dlq_payload).encode())
        self.producer.flush()
        import logging
        logging.error(f"Sent to DLQ: {error[:100]}")
```

## Key Commands Reference

```bash
# Start local CDC stack
docker-compose up -d postgres zookeeper kafka connect

# Register Debezium connector
curl -X POST http://localhost:8083/connectors \
  -H "Content-Type: application/json" \
  -d @connector-config.json

# Check connector status
curl http://localhost:8083/connectors/orders-cdc-connector/status | jq .

# List Kafka topics created by Debezium
kafka-topics --bootstrap-server localhost:9092 --list | grep cdc

# Monitor CDC events in real-time
kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic cdc.public.orders \
  --from-beginning \
  | jq .

# Check PostgreSQL replication slot lag
psql -c "SELECT slot_name, pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)) FROM pg_replication_slots;"

# Python CDC consumer
pip install confluent-kafka pydantic psycopg2-binary httpx

# Supabase Realtime
npm install @supabase/supabase-js
```

## Common Patterns

### Pattern 1: Outbox Pattern via CDC

```sql
-- The outbox pattern: write to outbox table in same transaction as domain change
-- CDC picks up outbox events and delivers them exactly once

CREATE TABLE outbox (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    aggregate_type TEXT NOT NULL,
    aggregate_id UUID NOT NULL,
    event_type TEXT NOT NULL,
    payload JSONB NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    processed BOOLEAN DEFAULT FALSE
);

-- Application code (same transaction as domain write):
BEGIN;
  INSERT INTO orders (id, customer_id, status) VALUES ($1, $2, 'pending');
  INSERT INTO outbox (aggregate_type, aggregate_id, event_type, payload)
    VALUES ('Order', $1, 'OrderCreated', jsonb_build_object('order_id', $1, 'customer_id', $2));
COMMIT;

-- Debezium captures outbox table changes and routes them by event_type
```

### Pattern 2: Idempotent CDC Consumer

```python
# Track processed event offsets to handle redelivery safely
import redis

r = redis.from_url("redis://localhost:6379")

def process_idempotent(event: CDCEvent, handler: Callable):
    # Use table + PK + timestamp as idempotency key
    key = f"cdc:{event.table}:{(event.after or event.before or {}).get('id')}:{event.timestamp_ms}"
    if r.set(key, "1", ex=3600, nx=True):  # nx=True: only set if not exists
        handler(event)
    # else: already processed, skip
```

### Pattern 3: Schema Evolution with Avro

```python
# Use Avro schemas to handle schema evolution gracefully
# pip install confluent-kafka[avro] fastavro
from confluent_kafka.avro import AvroConsumer
from confluent_kafka.avro.serializer import SerializerError

avro_consumer = AvroConsumer({
    "bootstrap.servers": "localhost:9092",
    "group.id": "avro-group",
    "schema.registry.url": "http://localhost:8081",
})
avro_consumer.subscribe(["cdc.public.orders-value"])

msg = avro_consumer.poll(10)
if msg and not msg.error():
    print(msg.value())  # Automatically deserialized using registered schema
```

## Pitfalls to Avoid

1. **Not monitoring WAL lag**: Debezium's replication slot holds WAL segments until consumed. If the consumer falls behind or crashes, Postgres can't reclaim WAL disk space, causing disk exhaustion. Always monitor `pg_replication_slots` lag and set `max_slot_wal_keep_size` in postgresql.conf to cap WAL retention.

2. **Processing CDC events non-idempotently**: Kafka guarantees at-least-once delivery, so your consumer will see duplicate events after restarts. Every handler must be idempotent — track processed event IDs in Redis or use UPSERT instead of INSERT in downstream databases.

3. **Capturing all tables without filtering**: CDC generates an event for every single row change across all tables. Without filtering to only the tables you care about, you'll flood Kafka with irrelevant events and waste storage. Always configure `table.include.list` in Debezium and only subscribe to the topics you actually need.

## Related Skills

- `kafka-event-streaming` — Kafka producers, consumers, partitioning, and consumer groups
- `event-driven-architecture` — Event-driven design patterns that CDC enables
- `cqrs-patterns` — CQRS read models built from CDC event streams
- `postgres-advanced` — PostgreSQL WAL, replication, and performance tuning

## GitNexus Index

```json
{
  "skill": "database-cdc-patterns",
  "category": "data-engineering",
  "triggers": ["change data capture", "cdc", "debezium", "postgresql replication", "supabase realtime", "outbox pattern", "database events", "wal streaming"],
  "outputs": ["Debezium connector config", "CDCEvent", "CDCConsumer", "Supabase channel subscription", "outbox table"],
  "complexity": "high",
  "tools": ["debezium", "kafka", "postgresql", "supabase", "confluent-kafka", "python", "docker-compose"]
}
```
