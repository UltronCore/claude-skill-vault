---
name: vector-db-integration
description: Integrate vector databases (Chroma, Qdrant, Weaviate) into Claude Code projects for semantic search and embedding storage. Use when building RAG systems, semantic memory, or similarity search features. Trigger when users mention vector database, embeddings storage, semantic search, Chroma, Qdrant, Weaviate, or similarity retrieval.
---

# Vector DB Integration

Quick setup patterns for the three most common vector databases in Claude Code projects.

## Chroma (local dev)
Best for: prototyping, local development, no server needed
```python
pip install chromadb

import chromadb
client = chromadb.Client()  # in-memory
# OR: chromadb.PersistentClient(path="./chroma_data")

collection = client.create_collection("knowledge")

# Add documents
collection.add(
    documents=["doc text here", "another doc"],
    ids=["id1", "id2"]
)

# Query
results = collection.query(query_texts=["search query"], n_results=3)
print(results["documents"])
```

## Qdrant (production)
Best for: high-performance production, filtering, payload storage
```python
pip install qdrant-client

from qdrant_client import QdrantClient
from qdrant_client.models import Distance, VectorParams, PointStruct

client = QdrantClient(":memory:")  # or QdrantClient(url="http://localhost:6333")

client.create_collection(
    collection_name="docs",
    vectors_config=VectorParams(size=384, distance=Distance.COSINE)
)

# Upsert vectors
client.upsert(
    collection_name="docs",
    points=[PointStruct(id=1, vector=[0.1]*384, payload={"text": "doc content"})]
)

# Search
results = client.search(collection_name="docs", query_vector=[0.1]*384, limit=3)
```

## Weaviate (hybrid search)
Best for: combining keyword + semantic search, GraphQL queries
```python
pip install weaviate-client

import weaviate
client = weaviate.connect_to_local()

collection = client.collections.create(
    name="Document",
    vectorizer_config=weaviate.classes.config.Configure.Vectorizer.text2vec_openai()
)

# Hybrid search
results = collection.query.hybrid(
    query="search text",
    limit=3
)
```

## Choosing a vector DB
| Need | Recommended |
|---|---|
| Local dev / quick prototype | Chroma |
| Production, high throughput | Qdrant |
| Hybrid keyword+vector search | Weaviate |
| Already on Supabase | pgvector via supabase-prisma-database-management skill |
| Maximum scale | Milvus |

## Related skills
rag-pipeline-setup, supabase-prisma-database-management
