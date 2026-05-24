---
name: postgres-sharding
description: Scale PostgreSQL horizontally using sharding strategies — Citus for distributed tables, pg_partman for declarative partitioning, logical replication for read replicas, and custom shard routing. Covers consistent hashing, range sharding, rebalancing, and cross-shard queries.
version: 1.0.0
tags: [postgresql, sharding, citus, partitioning, horizontal-scaling, pg_partman, distributed-database, database]
---

# PostgreSQL Sharding

## Overview

PostgreSQL sharding distributes data across multiple nodes to overcome single-instance limits for write throughput and storage. Three main approaches exist: native table partitioning (splits one table across filesystems), Citus (distributes tables across worker nodes transparently), and application-level sharding (routes queries in code based on shard key). Each approach trades operational simplicity against query flexibility — Citus handles most SQL transparently; application sharding gives maximum control but requires sharding-aware code.

## When to Use

- Write throughput exceeds what a single PostgreSQL instance can handle (>50k writes/sec)
- Table size exceeds practical limits for VACUUM, backups, or index maintenance (>500GB)
- Need to distribute data geographically for latency or data residency compliance
- Time-series data where old partitions should be archived or dropped automatically
- Multi-tenant SaaS where each tenant's data should be isolated on separate shards
- Read replicas are insufficient — you need distributed writes, not just read scaling

## Step-by-Step Workflow

### 1. Native Partitioning with pg_partman

```sql
-- Declarative partitioning: partition orders by month
CREATE TABLE orders (
    id          BIGSERIAL,
    customer_id UUID        NOT NULL,
    amount      DECIMAL(18,2),
    status      TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (id, created_at)  -- Partition key must be in primary key
) PARTITION BY RANGE (created_at);

-- Create monthly partitions manually (or use pg_partman to automate)
CREATE TABLE orders_2024_01 PARTITION OF orders
    FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');

CREATE TABLE orders_2024_02 PARTITION OF orders
    FOR VALUES FROM ('2024-02-01') TO ('2024-03-01');

-- Default partition catches out-of-range data (prevents insert errors)
CREATE TABLE orders_default PARTITION OF orders DEFAULT;

-- Index each partition (indexes are per-partition in declarative partitioning)
CREATE INDEX ON orders_2024_01 (customer_id);
CREATE INDEX ON orders_2024_02 (customer_id);
```

```sql
-- pg_partman: automate partition creation and retention
-- Install: CREATE EXTENSION pg_partman;

-- Configure automated monthly partitioning
SELECT partman.create_parent(
    p_parent_table  => 'public.orders',
    p_control       => 'created_at',
    p_interval      => '1 month',
    p_premake       => 3,               -- Pre-create 3 future partitions
    p_start_partition => '2024-01-01'
);

-- Run maintenance (add new partitions, drop old ones beyond retention)
-- Schedule this in cron or pg_cron:
SELECT partman.run_maintenance('public.orders');

-- Configure retention policy (drop partitions older than 12 months)
UPDATE partman.part_config
SET retention = '12 months',
    retention_keep_table = false,  -- Actually drop, don't just detach
    infinite_time_partitions = true
WHERE parent_table = 'public.orders';

-- List existing partitions
SELECT inhrelid::regclass AS partition, pg_size_pretty(pg_relation_size(inhrelid)) AS size
FROM pg_inherits
WHERE inhparent = 'orders'::regclass
ORDER BY inhrelid::regclass::text;
```

### 2. Citus — Distributed Sharding

```bash
# Install Citus (Postgres extension)
docker run -p 5432:5432 -e POSTGRES_PASSWORD=pass citusdata/citus:latest

# Or on existing Postgres (Amazon RDS, Supabase, self-hosted)
# psql -c "CREATE EXTENSION citus;"
```

```sql
-- Citus: set up coordinator + worker nodes
-- Run on coordinator node:
SELECT master_add_node('worker-1.internal', 5432);
SELECT master_add_node('worker-2.internal', 5432);
SELECT master_add_node('worker-3.internal', 5432);

-- Verify workers
SELECT * FROM master_get_active_worker_nodes();

-- Distribute a table (shards by hash of customer_id across workers)
-- Each worker gets 32 shards by default (total 32 shards across 3 workers)
SELECT create_distributed_table('orders', 'customer_id');

-- Reference table: replicated to ALL workers (for small lookup tables)
SELECT create_reference_table('products');  -- Joins work on any worker

-- Check shard placement
SELECT shardid, nodename, nodeport
FROM pg_dist_shard_placement
JOIN pg_dist_shard USING (shardid)
WHERE logicalrelid = 'orders'::regclass
LIMIT 10;

-- Collocate related tables on same shards (enables shard-local JOINs)
-- Both tables must be distributed on the same key (customer_id)
SELECT create_distributed_table('order_items', 'customer_id',
    colocate_with => 'orders');

-- After this, queries like:
SELECT o.id, oi.product_id
FROM orders o JOIN order_items oi ON o.id = oi.order_id
WHERE o.customer_id = 'cust_123'
-- ...are routed to a SINGLE worker — no cross-node data transfer
```

```sql
-- Citus query execution: understand how queries are distributed

-- This query hits ONE shard (shard key = customer_id is in WHERE)
EXPLAIN SELECT * FROM orders WHERE customer_id = 'cust_abc';
-- Task Count: 1, Placement Count: 1 — efficient

-- This query hits ALL shards (no shard key filter — full scatter)
EXPLAIN SELECT COUNT(*) FROM orders WHERE status = 'pending';
-- Task Count: 32 — aggregates on workers, merges on coordinator

-- Rebalance shards after adding new workers
SELECT rebalance_table_shards('orders');
-- Monitor progress:
SELECT * FROM get_rebalance_progress();
```

### 3. Application-Level Shard Routing

```python
# src/database/shard_router.py
import hashlib
from typing import Any
from sqlalchemy import create_engine
from sqlalchemy.orm import Session

class ShardRouter:
    """Route database queries to the correct shard based on shard key."""

    def __init__(self, shard_configs: list[dict]):
        """
        shard_configs: [{"dsn": "postgresql://host1/db", "shard_ids": [0, 1, 2, 3]}, ...]
        """
        self.shards = {}
        self.shard_count = sum(len(c["shard_ids"]) for c in shard_configs)

        for config in shard_configs:
            engine = create_engine(config["dsn"], pool_size=10, max_overflow=20)
            for shard_id in config["shard_ids"]:
                self.shards[shard_id] = engine

    def get_shard_id(self, shard_key: str) -> int:
        """Consistent hashing — shard_key always maps to same shard."""
        hash_value = int(hashlib.md5(str(shard_key).encode()).hexdigest(), 16)
        return hash_value % self.shard_count

    def get_session(self, shard_key: str) -> tuple[Session, int]:
        """Get a database session for the shard corresponding to shard_key."""
        shard_id = self.get_shard_id(shard_key)
        engine = self.shards[shard_id]
        return Session(engine), shard_id

    def execute_on_all_shards(self, query_fn) -> list[Any]:
        """Execute a function on every shard (for aggregation queries)."""
        results = []
        for shard_id, engine in self.shards.items():
            with Session(engine) as session:
                results.extend(query_fn(session, shard_id))
        return results


# Usage: order service with sharding
router = ShardRouter([
    {"dsn": "postgresql://shard0.db/orders", "shard_ids": [0, 1, 2, 3, 4, 5, 6, 7]},
    {"dsn": "postgresql://shard1.db/orders", "shard_ids": [8, 9, 10, 11, 12, 13, 14, 15]},
])

def create_order(customer_id: str, amount: float) -> dict:
    """Write goes to the shard for this customer."""
    session, shard_id = router.get_session(customer_id)
    with session:
        order = Order(customer_id=customer_id, amount=amount)
        session.add(order)
        session.commit()
        return {"id": order.id, "shard_id": shard_id}

def get_orders_for_customer(customer_id: str) -> list:
    """Read goes to same shard — no cross-shard needed."""
    session, _ = router.get_session(customer_id)
    with session:
        return session.query(Order).filter_by(customer_id=customer_id).all()

def count_total_orders() -> int:
    """Aggregate across all shards — scatter-gather."""
    counts = router.execute_on_all_shards(
        lambda session, _: [session.query(Order).count()]
    )
    return sum(counts)
```

## Key Commands Reference

```sql
-- Partition inspection
\d+ orders                        -- Show partition structure
SELECT * FROM pg_partitions WHERE tablename = 'orders';

-- Detach old partition for archival (fast — doesn't copy data)
ALTER TABLE orders DETACH PARTITION orders_2023_01;
-- Re-attach later if needed:
ALTER TABLE orders ATTACH PARTITION orders_2023_01
    FOR VALUES FROM ('2023-01-01') TO ('2023-02-01');

-- Move partition data to cold storage tablespace
ALTER TABLE orders_2023_01 SET TABLESPACE cold_storage;

-- Citus: check shard count and distribution
SELECT logicalrelid, shardcount FROM pg_dist_table;
SELECT nodename, count(*) as shard_count
FROM pg_dist_shard_placement
GROUP BY nodename;

-- Citus: worker node management
SELECT master_add_node('new-worker.internal', 5432);
SELECT rebalance_table_shards();

-- pg_partman maintenance
SELECT partman.check_parent();      -- Verify partitions exist for future dates
SELECT partman.run_maintenance_proc('public.orders');  -- Create new partitions

-- Find which partition contains a specific row
SELECT tableoid::regclass as partition
FROM orders WHERE created_at = '2024-01-15';
```

## Common Patterns

### Pattern 1: Multi-Tenant Sharding by Tenant ID

```sql
-- In Citus: shard by tenant_id — all tenant data on one worker
SELECT create_distributed_table('events', 'tenant_id');
SELECT create_distributed_table('users', 'tenant_id', colocate_with => 'events');
SELECT create_distributed_table('sessions', 'tenant_id', colocate_with => 'events');

-- All queries with tenant_id = X go to one worker — perfect isolation
SELECT e.*, u.email
FROM events e JOIN users u ON e.user_id = u.id
WHERE e.tenant_id = 'tenant_acme'
  AND e.created_at > NOW() - INTERVAL '7 days';

-- In application code: add tenant_id to every query (row-level isolation)
-- Use RLS + a tenant context function to enforce automatically:
CREATE POLICY tenant_isolation ON events
    USING (tenant_id = current_setting('app.current_tenant_id'));
```

### Pattern 2: Time-Series Partitioning with Automatic Archival

```sql
-- Orders partitioned by week, old partitions moved to S3 via pg_partman + pg_cron
-- Step 1: Partition by week
SELECT partman.create_parent('public.metrics', 'recorded_at', '1 week',
    p_premake := 4);

-- Step 2: pg_cron job to run maintenance weekly
SELECT cron.schedule('partman-maintenance', '0 2 * * 0',
    $$SELECT partman.run_maintenance_proc('public.metrics')$$);

-- Step 3: Export old partitions to S3 before dropping (via pg_cron + aws cli)
-- Or use pg_partman's retention_keep_table=true + custom archival script
```

### Pattern 3: Read-Write Splitting with Logical Replication

```python
# Direct writes to primary, reads to replicas
import random
from sqlalchemy import create_engine

PRIMARY = create_engine("postgresql://primary:5432/db", pool_size=20)
REPLICAS = [
    create_engine("postgresql://replica1:5432/db", pool_size=10),
    create_engine("postgresql://replica2:5432/db", pool_size=10),
]

def get_read_engine():
    return random.choice(REPLICAS)  # Round-robin or use pgBouncer

def get_write_engine():
    return PRIMARY

# In ORM layer
with Session(get_read_engine()) as session:
    products = session.query(Product).filter_by(active=True).all()

with Session(get_write_engine()) as session:
    session.add(Order(...))
    session.commit()
```

## Pitfalls to Avoid

1. **Choosing a low-cardinality shard key**: Sharding by `country` (200 values) or `status` (5 values) creates unbalanced shards — one "US" shard holds 40% of the data. Choose a high-cardinality key like `customer_id` or `user_id` (millions of distinct values). With Citus, each shard ideally holds <1% of total data for even distribution.

2. **Running cross-shard JOINs in application code**: Joining across shards in application code (fetch from shard A, fetch from shard B, join in Python) is extremely slow at scale. In Citus, use `colocate_with` to put related tables on the same shards — the JOIN happens on the worker. In application sharding, design around single-shard access patterns; cross-shard queries should be rare async operations, not hot paths.

3. **Not accounting for shard key selection in queries**: Every query that doesn't include the shard key must scatter to all shards. If you shard by `customer_id` but frequently query by `order_id`, you need a secondary index across all shards (expensive) or a lookup table mapping `order_id` → `customer_id`. Design access patterns first, then choose shard key — not the reverse.

## Related Skills

- `postgres-advanced` — PostgreSQL internals, indexes, VACUUM
- `database-migration-strategies` — Migrating to sharded schema
- `database-cdc-patterns` — CDC across sharded databases
- `data-lakehouse-architecture` — When to move off OLTP sharding to OLAP

## GitNexus Index

```json
{
  "skill": "postgres-sharding",
  "category": "database",
  "triggers": ["postgres sharding", "postgresql horizontal scaling", "Citus", "table partitioning", "pg_partman", "shard routing", "distributed postgres", "read replicas postgres", "rebalance shards", "partition by range"],
  "outputs": ["create_distributed_table()", "create_reference_table()", "partman.create_parent()", "ShardRouter", "get_shard_id()", "execute_on_all_shards()", "ALTER TABLE DETACH PARTITION"],
  "complexity": "high",
  "tools": ["postgresql", "citus", "pg_partman", "pg_cron", "sqlalchemy", "python", "pgBouncer"]
}
```
