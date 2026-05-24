---
name: vector-db-production
description: Deploy and operate vector databases in production — Qdrant, Pinecone, Weaviate, and pgvector. Covers HNSW index tuning, replication, sharding, monitoring query latency, filtering strategies, batch upserts, and disaster recovery for embedding-heavy workloads.
version: 1.0.0
tags: [vector-database, qdrant, pinecone, pgvector, weaviate, hnsw, production, embeddings, ANN-search, semantic-search]
---

# Vector Database Production Operations

## Overview

Vector databases store high-dimensional embeddings and serve approximate nearest neighbor (ANN) search at scale. Production challenges include index quality (ef_construction, m parameters in HNSW), recall vs. latency tradeoffs, scalar filtering at scale (pre-filter vs post-filter), replication for HA, and monitoring for embedding drift. Qdrant is the recommended open-source choice for self-hosted workloads; Pinecone for managed convenience; pgvector for PostgreSQL shops that need vectors alongside relational data without a new infrastructure component.

## When to Use

- Running semantic search in production with >1M vectors
- Managing latency SLAs for embedding queries (p99 < 100ms)
- Handling concurrent writes + reads to a growing vector store
- Implementing filtered vector search (find similar items in a category)
- Debugging recall degradation after index grows or embeddings change
- Planning disaster recovery for a vector database that's a critical dependency

## Step-by-Step Workflow

### 1. Qdrant Production Setup

```bash
# docker-compose.yml for production Qdrant
version: "3"
services:
  qdrant:
    image: qdrant/qdrant:v1.8.3
    ports:
      - "6333:6333"
      - "6334:6334"  # gRPC port
    volumes:
      - qdrant_data:/qdrant/storage
    environment:
      QDRANT__SERVICE__HTTP_PORT: 6333
      QDRANT__SERVICE__GRPC_PORT: 6334
      QDRANT__LOG_LEVEL: INFO
      # Memory-mapped storage (better for large collections)
      QDRANT__STORAGE__ON_DISK_PAYLOAD: "true"
      QDRANT__STORAGE__VECTORS__ON_DISK: "true"

volumes:
  qdrant_data:
```

```python
# src/vector_db/qdrant_client_config.py
from qdrant_client import QdrantClient
from qdrant_client.models import (
    Distance, VectorParams, HnswConfigDiff, OptimizersConfigDiff,
    QuantizationConfig, ScalarQuantizationConfig, ScalarType,
    PointStruct, Filter, FieldCondition, MatchValue, Range
)

client = QdrantClient(
    url="http://qdrant:6333",
    prefer_grpc=True,  # gRPC is ~3x faster than REST for batch operations
    timeout=30,
)

def create_production_collection(collection_name: str, vector_size: int = 1536):
    """Create a collection with tuned HNSW parameters for production."""
    client.recreate_collection(
        collection_name=collection_name,
        vectors_config=VectorParams(
            size=vector_size,
            distance=Distance.COSINE,
            on_disk=True,               # Store vectors on disk (lower RAM usage)
        ),
        hnsw_config=HnswConfigDiff(
            m=16,                       # Connections per node (16-64 for production)
            ef_construct=200,           # Higher = better recall, slower indexing
            full_scan_threshold=10_000, # Use exact search below this count
            on_disk=True,               # HNSW graph on disk (saves RAM for large indexes)
        ),
        optimizers_config=OptimizersConfigDiff(
            default_segment_number=8,   # More segments = better concurrent write performance
            max_segment_size=200_000,   # Merge segments above this size
        ),
        quantization_config=QuantizationConfig(
            scalar=ScalarQuantizationConfig(
                type=ScalarType.INT8,   # Compress float32 to int8 (4x smaller, ~5% recall drop)
                quantile=0.99,
                always_ram=True,        # Keep quantized vectors in RAM for speed
            )
        ),
    )
```

### 2. Batch Upserts and Indexing

```python
# src/vector_db/batch_upserter.py
import asyncio
from typing import Generator
from qdrant_client.models import PointStruct, Batch

def chunk_list(lst: list, chunk_size: int) -> Generator:
    for i in range(0, len(lst), chunk_size):
        yield lst[i:i + chunk_size]

async def batch_upsert_embeddings(
    collection_name: str,
    records: list[dict],  # [{"id": str, "embedding": list[float], "payload": dict}]
    batch_size: int = 256,
    parallel: int = 4,
):
    """
    Upsert large datasets efficiently.
    - Batch size 256 is optimal for most deployments
    - Parallel workers prevent head-of-line blocking during indexing
    """
    semaphore = asyncio.Semaphore(parallel)
    chunks = list(chunk_list(records, batch_size))

    async def upsert_chunk(chunk: list):
        async with semaphore:
            points = [
                PointStruct(
                    id=r["id"],
                    vector=r["embedding"],
                    payload=r["payload"],
                )
                for r in chunk
            ]
            client.upsert(
                collection_name=collection_name,
                points=points,
                wait=False,         # Don't wait for indexing — returns immediately
            )

    await asyncio.gather(*[upsert_chunk(c) for c in chunks])

    # Wait for indexing to complete before querying
    while True:
        info = client.get_collection(collection_name)
        if info.status == "green":
            break
        await asyncio.sleep(1)
    print(f"Indexed {len(records)} vectors")
```

### 3. Production Query Patterns

```python
# src/vector_db/search.py
from qdrant_client.models import Filter, FieldCondition, MatchValue, Range, SearchParams

def search_with_filter(
    collection_name: str,
    query_vector: list[float],
    category: str = None,
    min_price: float = None,
    max_price: float = None,
    top_k: int = 10,
    ef: int = 128,           # Higher ef = better recall, more latency
) -> list[dict]:
    """
    Search with scalar pre-filtering.
    Pre-filtering (Qdrant default) applies filter BEFORE ANN search.
    This is faster than post-filtering for high selectivity filters (<20% of data).
    """
    filter_conditions = []
    if category:
        filter_conditions.append(
            FieldCondition(key="category", match=MatchValue(value=category))
        )
    if min_price is not None or max_price is not None:
        filter_conditions.append(
            FieldCondition(
                key="price",
                range=Range(gte=min_price, lte=max_price)
            )
        )

    search_filter = Filter(must=filter_conditions) if filter_conditions else None

    results = client.search(
        collection_name=collection_name,
        query_vector=query_vector,
        query_filter=search_filter,
        limit=top_k,
        search_params=SearchParams(
            hnsw_ef=ef,             # Override ef for this query
            exact=False,            # Use ANN (not brute force)
        ),
        with_payload=True,
        score_threshold=0.7,        # Reject low-quality matches
    )

    return [
        {
            "id": r.id,
            "score": r.score,
            "payload": r.payload,
        }
        for r in results
    ]


def benchmark_recall(collection_name: str, test_vectors: list, ground_truth: list):
    """Measure recall@10 to detect index quality degradation."""
    recall_sum = 0
    for qv, gt_ids in zip(test_vectors, ground_truth):
        # ANN results
        ann_results = {r.id for r in client.search(
            collection_name, qv, limit=10
        )}
        # Exact results (ground truth)
        exact_results = {r.id for r in client.search(
            collection_name, qv, limit=10,
            search_params=SearchParams(exact=True)
        )}
        recall_sum += len(ann_results & exact_results) / len(exact_results)

    recall_at_10 = recall_sum / len(test_vectors)
    print(f"Recall@10: {recall_at_10:.3f}")
    if recall_at_10 < 0.95:
        print("WARNING: Recall below 0.95 — consider increasing ef_construct or m")
    return recall_at_10
```

### 4. pgvector for PostgreSQL-Native Vector Search

```sql
-- Enable pgvector extension
CREATE EXTENSION IF NOT EXISTS vector;

-- Create table with embedding column
CREATE TABLE documents (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    content     TEXT NOT NULL,
    embedding   vector(1536),   -- OpenAI text-embedding-3-small dimension
    source      TEXT,
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- Create HNSW index (better performance than IVFFlat for most cases)
CREATE INDEX ON documents USING hnsw (embedding vector_cosine_ops)
WITH (m = 16, ef_construction = 64);

-- Or IVFFlat (better for very large datasets, requires training)
CREATE INDEX ON documents USING ivfflat (embedding vector_cosine_ops)
WITH (lists = 100);  -- lists = sqrt(row_count) is a good starting point

-- Similarity search with metadata filter
SELECT id, content, 1 - (embedding <=> $1) AS similarity
FROM documents
WHERE source = 'docs.acme.com'
  AND created_at > NOW() - INTERVAL '30 days'
ORDER BY embedding <=> $1  -- <=> is cosine distance (lower = more similar)
LIMIT 10;

-- Set ef for this session (trade recall vs speed)
SET hnsw.ef_search = 100;  -- Default is 40

-- Monitor index usage
SELECT schemaname, tablename, indexname, idx_scan, idx_tup_read
FROM pg_stat_user_indexes
WHERE tablename = 'documents';
```

## Key Commands Reference

```bash
# Qdrant collection management
curl http://localhost:6333/collections                    # List collections
curl http://localhost:6333/collections/my_collection     # Collection info
curl http://localhost:6333/collections/my_collection/points/count  # Point count

# Check collection health
python -c "
from qdrant_client import QdrantClient
c = QdrantClient('http://localhost:6333')
info = c.get_collection('my_collection')
print(f'Status: {info.status}')
print(f'Points: {info.points_count}')
print(f'Indexed: {info.indexed_vectors_count}')
print(f'RAM usage: {info.vectors_count}')
"

# pgvector: check index size
SELECT pg_size_pretty(pg_relation_size('documents_embedding_idx'));

# pgvector: explain vector query
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM documents
ORDER BY embedding <=> '[0.1, 0.2, ...]'::vector
LIMIT 10;

# Qdrant: optimize collection (trigger segment merge)
curl -X POST http://localhost:6333/collections/my_collection/index

# Monitor with Prometheus
# Qdrant exposes /metrics endpoint
curl http://localhost:6333/metrics | grep qdrant
```

## Common Patterns

### Pattern 1: Tenant Isolation with Namespaces

```python
# Multi-tenant: use payload filter to isolate tenants (no separate collections)
def tenant_search(query_vector, tenant_id: str, top_k: int = 10):
    return client.search(
        collection_name="shared_collection",
        query_vector=query_vector,
        query_filter=Filter(
            must=[FieldCondition(key="tenant_id", match=MatchValue(value=tenant_id))]
        ),
        limit=top_k,
    )

# For strict isolation (compliance), use separate collections per tenant
# But shared collection with filter is 10x cheaper to operate
```

### Pattern 2: Embedding Drift Detection

```python
# Detect when embeddings have drifted (model upgrade, distribution shift)
import numpy as np

def detect_embedding_drift(collection_name: str, sample_size: int = 1000) -> float:
    """
    Compare average cosine similarity of random sample pairs.
    Significant drop indicates embedding space has shifted.
    """
    sample = client.scroll(
        collection_name=collection_name,
        limit=sample_size,
        with_vectors=True,
    )[0]

    vectors = [p.vector for p in sample]
    # Random pairs
    pairs = [(vectors[i], vectors[j])
             for i, j in zip(range(0, 100), range(100, 200))]
    similarities = [
        np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b))
        for a, b in pairs
    ]
    avg_similarity = np.mean(similarities)
    print(f"Average inter-document similarity: {avg_similarity:.3f}")
    # Typical range: 0.1-0.4 for diverse documents
    # If much higher: possible duplicate content or embedding collapse
    # If much lower: check for embedding model changes
    return avg_similarity
```

### Pattern 3: Hybrid Search (BM25 + Vector)

```python
# Combine keyword search with vector search for better results
from qdrant_client.models import SparseVector, NamedSparseVector, NamedVector

# Create collection with both dense (semantic) and sparse (keyword) vectors
client.recreate_collection(
    collection_name="hybrid_search",
    vectors_config={
        "dense": VectorParams(size=1536, distance=Distance.COSINE),
    },
    sparse_vectors_config={
        "sparse": SparseVectorParams(),  # For BM25/SPLADE embeddings
    },
)

# Query with both vectors, Qdrant RRF-merges the results
results = client.query_points(
    collection_name="hybrid_search",
    prefetch=[
        Prefetch(query=dense_vector, using="dense", limit=20),
        Prefetch(query=sparse_vector, using="sparse", limit=20),
    ],
    query=FusionQuery(fusion=Fusion.RRF),  # Reciprocal Rank Fusion
    limit=10,
)
```

## Pitfalls to Avoid

1. **Using default HNSW parameters for large collections**: Default `m=16, ef_construct=100` degrades recall below 0.9 for collections over 5M vectors. For production, benchmark recall@10 with exact search as ground truth. If recall drops below 0.95, increase `ef_construct` (up to 500) or `m` (up to 64) — at the cost of slower indexing and more RAM. Do this tuning before launch; changing HNSW parameters requires full reindex.

2. **Loading all vectors into RAM**: Full in-memory mode costs ~6GB RAM per 1M 1536-dim float32 vectors. For large collections, enable `on_disk=True` for both vectors and HNSW graph, and use int8 quantization. Queries are ~2x slower than full-RAM but 5-10x cheaper to run. Profile your actual query latency requirements — most applications tolerate 20-50ms, which disk-based HNSW handles easily.

3. **Not monitoring recall over time**: As data grows or embedding models change, recall degrades silently. Implement nightly recall benchmarks using a fixed test set with exact search as ground truth. Alert when recall@10 drops below 0.90. Common causes: HNSW not yet fully indexed after bulk upserts (check `indexed_vectors_count < points_count`), or embedding model version mismatch in different pipeline stages.

## Related Skills

- `rag-pipeline` — Building retrieval systems on top of vector databases
- `embedding-pipeline` — Creating and managing embeddings
- `qdrant` — Qdrant-specific patterns and client usage
- `pinecone` — Pinecone managed vector service

## GitNexus Index

```json
{
  "skill": "vector-db-production",
  "category": "infrastructure",
  "triggers": ["vector database production", "Qdrant operations", "pgvector production", "HNSW tuning", "vector search latency", "recall@10", "embedding drift", "vector db monitoring", "batch upsert vectors", "scalar quantization", "hybrid search"],
  "outputs": ["create_production_collection()", "HnswConfigDiff m ef_construct", "ScalarQuantizationConfig INT8", "batch_upsert_embeddings()", "benchmark_recall()", "tenant_search()", "detect_embedding_drift()"],
  "complexity": "high",
  "tools": ["qdrant", "pgvector", "pinecone", "python", "postgresql", "docker", "prometheus"]
}
```
