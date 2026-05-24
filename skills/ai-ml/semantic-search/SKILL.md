---
name: semantic-search
description: Build semantic search systems using dense embeddings, vector databases, hybrid search (BM25 + dense), re-ranking, and RAG. Covers sentence-transformers, OpenAI embeddings, and production deployment patterns.
version: 1.0.0
tags: [semantic-search, embeddings, vector-search, rag, hybrid-search, sentence-transformers, reranking]
---

# Semantic Search

## Overview

This skill covers building production semantic search systems: generating embeddings, storing and querying vectors at scale, implementing hybrid search (keyword + semantic), and applying cross-encoder re-ranking for precision. It integrates sentence-transformers for local models, OpenAI/Cohere embeddings for cloud, and vector databases (Qdrant, Weaviate, pgvector) for storage. Designed to go beyond keyword search to understand user intent.

## When to Use

- Product search that needs to understand "winter jacket" → "parka", "coat", "fleece"
- Document search where exact keyword match fails (FAQ, knowledge base, code search)
- Building RAG (Retrieval-Augmented Generation) pipelines for LLMs
- Replacing Elasticsearch with semantic understanding for long-tail queries
- Recommendation systems based on content similarity

## Step-by-Step Workflow

### 1. Generate Embeddings
```python
# Option A: Local (faster for bulk, private data)
from sentence_transformers import SentenceTransformer

model = SentenceTransformer("BAAI/bge-small-en-v1.5")  # 33M params, fast, high quality
# Or: "BAAI/bge-large-en-v1.5"  # Better quality, slower
# Or: "thenlper/gte-small"       # Alternative architecture

texts = [
    "How do I reset my password?",
    "Steps to recover account access",
    "I forgot my login credentials",
]

# Batch encode for efficiency
embeddings = model.encode(
    texts,
    batch_size=32,
    show_progress_bar=True,
    normalize_embeddings=True,  # Cosine similarity via dot product
)
print(embeddings.shape)  # (3, 384) for bge-small

# Option B: OpenAI (best quality, pay-per-token)
from openai import OpenAI

client = OpenAI()

def embed_texts(texts: list[str], model="text-embedding-3-small") -> list[list[float]]:
    response = client.embeddings.create(input=texts, model=model)
    return [item.embedding for item in response.data]

# Option C: Cohere (good multilingual support)
import cohere
co = cohere.Client()
response = co.embed(texts=texts, model="embed-english-v3.0", input_type="search_document")
```

### 2. Vector Database Setup (Qdrant)
```python
from qdrant_client import QdrantClient
from qdrant_client.models import (
    Distance, VectorParams, PointStruct,
    Filter, FieldCondition, MatchValue, Range
)

client = QdrantClient("localhost", port=6333)

# Create collection
client.recreate_collection(
    collection_name="documents",
    vectors_config=VectorParams(size=384, distance=Distance.COSINE),
    on_disk_payload=True,  # Store payload on disk, vectors in RAM
)

# Add payload index for filtered search
client.create_payload_index("documents", "category", "keyword")
client.create_payload_index("documents", "created_at", "float")

# Index documents
def index_documents(docs: list[dict], batch_size: int = 100):
    for i in range(0, len(docs), batch_size):
        batch = docs[i:i + batch_size]
        texts = [d["content"] for d in batch]
        vectors = model.encode(texts, normalize_embeddings=True).tolist()
        
        points = [
            PointStruct(
                id=doc["id"],
                vector=vector,
                payload={
                    "title": doc["title"],
                    "content": doc["content"][:500],  # Truncate payload
                    "category": doc["category"],
                    "created_at": doc["created_at"].timestamp(),
                    "url": doc["url"],
                },
            )
            for doc, vector in zip(batch, vectors)
        ]
        client.upsert(collection_name="documents", points=points)

# Search
def semantic_search(
    query: str,
    limit: int = 10,
    category: str | None = None,
) -> list[dict]:
    query_vector = model.encode(query, normalize_embeddings=True).tolist()
    
    filter_condition = None
    if category:
        filter_condition = Filter(
            must=[FieldCondition(key="category", match=MatchValue(value=category))]
        )
    
    results = client.search(
        collection_name="documents",
        query_vector=query_vector,
        query_filter=filter_condition,
        limit=limit,
        with_payload=True,
        score_threshold=0.7,  # Only return high-confidence results
    )
    
    return [
        {**hit.payload, "score": hit.score, "id": hit.id}
        for hit in results
    ]
```

### 3. pgvector (PostgreSQL)
```sql
-- Enable extension
CREATE EXTENSION IF NOT EXISTS vector;

-- Add embedding column to existing table
ALTER TABLE documents ADD COLUMN embedding vector(384);

-- Create IVFFlat index (approximate, faster)
CREATE INDEX ON documents USING ivfflat (embedding vector_cosine_ops)
WITH (lists = 100);  -- lists ≈ sqrt(num_rows)

-- Or HNSW (better recall, more memory)
CREATE INDEX ON documents USING hnsw (embedding vector_cosine_ops)
WITH (m = 16, ef_construction = 64);
```

```python
import psycopg2
import numpy as np

# Store embedding
def store_embedding(doc_id: str, embedding: list[float], content: str):
    conn.execute(
        "UPDATE documents SET embedding = %s WHERE id = %s",
        (embedding, doc_id)
    )

# Semantic search with SQL
def pgvector_search(query: str, limit: int = 10):
    query_embedding = model.encode(query, normalize_embeddings=True).tolist()
    
    results = conn.execute("""
        SELECT id, title, content,
               1 - (embedding <=> %s::vector) AS similarity
        FROM documents
        WHERE embedding IS NOT NULL
        ORDER BY embedding <=> %s::vector
        LIMIT %s
    """, (query_embedding, query_embedding, limit)).fetchall()
    
    return results
```

### 4. Hybrid Search (BM25 + Dense)
```python
from rank_bm25 import BM25Okapi
import numpy as np

class HybridSearcher:
    def __init__(self, documents: list[dict], dense_model):
        self.documents = documents
        self.model = dense_model
        
        # BM25 index
        tokenized = [doc["content"].lower().split() for doc in documents]
        self.bm25 = BM25Okapi(tokenized)
        
        # Dense index
        self.embeddings = dense_model.encode(
            [doc["content"] for doc in documents],
            normalize_embeddings=True,
        )
    
    def search(
        self,
        query: str,
        k: int = 10,
        alpha: float = 0.5,  # 0=pure BM25, 1=pure dense
    ) -> list[dict]:
        # BM25 scores
        bm25_scores = self.bm25.get_scores(query.lower().split())
        bm25_norm = bm25_scores / (bm25_scores.max() + 1e-10)
        
        # Dense scores
        query_emb = self.model.encode(query, normalize_embeddings=True)
        dense_scores = self.embeddings @ query_emb
        
        # Reciprocal Rank Fusion (better than linear combination)
        def rrf(scores, k=60):
            ranks = len(scores) - np.argsort(np.argsort(scores))
            return 1 / (k + ranks)
        
        combined = rrf(bm25_norm) + rrf(dense_scores)
        top_k = np.argsort(combined)[::-1][:k]
        
        return [
            {**self.documents[i], "score": float(combined[i])}
            for i in top_k
        ]
```

### 5. Cross-Encoder Re-ranking
```python
from sentence_transformers.cross_encoder import CrossEncoder

# Re-ranker: more accurate but slower (run on top-K candidates only)
reranker = CrossEncoder("cross-encoder/ms-marco-MiniLM-L-6-v2")

def rerank_results(query: str, candidates: list[dict], top_n: int = 5) -> list[dict]:
    pairs = [(query, doc["content"]) for doc in candidates]
    scores = reranker.predict(pairs)
    
    ranked = sorted(
        zip(candidates, scores),
        key=lambda x: x[1],
        reverse=True
    )
    return [doc for doc, _ in ranked[:top_n]]

# Two-stage pipeline
def search_with_rerank(query: str) -> list[dict]:
    # Stage 1: Fast retrieval (100 candidates)
    candidates = semantic_search(query, limit=100)
    # Stage 2: Precise re-ranking (top 5)
    return rerank_results(query, candidates, top_n=5)
```

## Key Commands Reference

```bash
# Start Qdrant
docker run -p 6333:6333 qdrant/qdrant

# Install dependencies
pip install sentence-transformers qdrant-client rank-bm25 openai cohere

# Benchmark retrieval quality
python -c "
from beir import util, LoggingHandler
from beir.retrieval.evaluation import EvaluateRetrieval
# Run BEIR benchmark on your search system
"

# pgvector setup
psql -c 'CREATE EXTENSION vector;'
pip install pgvector psycopg[binary]
```

## Common Patterns

### Pattern 1: Chunking Strategy for Long Documents
```python
from langchain.text_splitter import RecursiveCharacterTextSplitter

splitter = RecursiveCharacterTextSplitter(
    chunk_size=512,
    chunk_overlap=50,
    separators=["\n\n", "\n", ". ", " ", ""],
)

def chunk_and_index(document: dict) -> list[dict]:
    chunks = splitter.create_documents(
        [document["content"]],
        metadatas=[{"doc_id": document["id"], "source": document["url"]}],
    )
    return [
        {
            "id": f"{document['id']}_chunk_{i}",
            "content": chunk.page_content,
            "doc_id": document["id"],
            **chunk.metadata,
        }
        for i, chunk in enumerate(chunks)
    ]
```

### Pattern 2: Query Expansion
```python
def expand_query(query: str, n_expansions: int = 3) -> list[str]:
    """Use LLM to generate related queries for better recall."""
    response = client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[{
            "role": "user",
            "content": f"Generate {n_expansions} alternative phrasings for this search query:\n{query}\nReturn as JSON list."
        }],
        response_format={"type": "json_object"},
    )
    alternatives = json.loads(response.choices[0].message.content)["queries"]
    return [query] + alternatives  # Include original
```

### Pattern 3: RAG Pipeline
```python
def rag_answer(question: str, n_docs: int = 5) -> str:
    # Retrieve relevant docs
    docs = search_with_rerank(question)
    context = "\n\n".join([f"[{i+1}] {d['content']}" for i, d in enumerate(docs)])
    
    # Generate answer grounded in retrieved docs
    response = client.chat.completions.create(
        model="claude-sonnet-4-6",
        messages=[
            {"role": "system", "content": "Answer based only on the provided context. Cite sources with [n]."},
            {"role": "user", "content": f"Context:\n{context}\n\nQuestion: {question}"}
        ],
    )
    return response.choices[0].message.content
```

## Pitfalls to Avoid

1. **Embedding full documents without chunking**: Embedding a 50-page document produces one vector representing everything — the signal is diluted. Chunk at semantic boundaries (paragraphs, sections) at 256-512 tokens. Too-short chunks lose context; too-long chunks lose specificity.

2. **Using cosine similarity threshold as quality gate without calibration**: A threshold of 0.7 on one embedding model may mean "highly relevant," but on another model might capture only 20% of relevant results. Calibrate thresholds by measuring precision/recall on a held-out evaluation set before deploying.

3. **Skipping re-ranking for production**: Bi-encoder retrieval (cosine similarity) is fast but imprecise — it can't compare query and document tokens together. For precision-sensitive use cases, always add a cross-encoder re-ranker on top-50 candidates. The latency cost (~50ms) is worth the precision gain.

## Related Skills

- `vector-rag-advanced` — Advanced RAG patterns and evaluation
- `embedding-pipeline` — Building embedding pipelines at scale
- `elasticsearch-search` — Hybrid search combining ES BM25 with dense vectors
- `knowledge-graph` — Graph-enhanced semantic search

## GitNexus Index

```json
{
  "skill": "semantic-search",
  "category": "ai-ml",
  "triggers": ["semantic search", "vector search", "embeddings search", "hybrid search", "BM25 dense", "sentence transformers search", "pgvector", "qdrant search"],
  "outputs": ["search system", "embedding pipeline", "hybrid searcher", "rag retriever"],
  "complexity": "medium",
  "tools": ["sentence-transformers", "qdrant", "pgvector", "openai-embeddings", "rank-bm25"]
}
```
