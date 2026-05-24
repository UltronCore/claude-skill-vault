---
name: embedding-pipeline
description: Build production embedding pipelines for semantic search, RAG, and recommendation systems. Covers text chunking strategies, batch embedding with OpenAI/Anthropic/HuggingFace, vector storage, embedding updates, and monitoring embedding quality.
version: 1.0.0
tags: [embeddings, vector-search, rag, semantic-search, openai, huggingface, chunking, pipeline]
---

# Embedding Pipeline

## Overview

An embedding pipeline converts text into dense vector representations that capture semantic meaning, enabling similarity search, RAG (Retrieval-Augmented Generation), recommendation systems, and clustering. This skill covers the full pipeline: text preprocessing and chunking, batched embedding generation with multiple providers, vector database storage, incremental updates for new content, and monitoring for embedding drift and quality degradation.

## When to Use

- Building a RAG system that needs to retrieve relevant context for LLM prompts
- Implementing semantic search over a document corpus (not just keyword matching)
- Recommendation systems based on content similarity
- Deduplication of large document sets using embedding similarity
- Clustering and categorizing unstructured text at scale

## Step-by-Step Workflow

### 1. Text Chunking — Critical Foundation
```python
from typing import List, Iterator
import re

def chunk_by_tokens(text: str, max_tokens: int = 512, overlap: int = 50) -> List[str]:
    """
    Sliding window chunking with token overlap.
    Overlap preserves context across chunk boundaries.
    Rough estimate: 1 token ≈ 4 chars for English.
    """
    words = text.split()
    chunk_size_words = max_tokens  # 1 token ≈ 1 word (rough)
    overlap_words = overlap
    
    chunks = []
    start = 0
    while start < len(words):
        end = min(start + chunk_size_words, len(words))
        chunk = " ".join(words[start:end])
        chunks.append(chunk)
        start += chunk_size_words - overlap_words
    
    return chunks

def chunk_by_sentences(text: str, max_chars: int = 2000, overlap_sentences: int = 2) -> List[str]:
    """
    Sentence-aware chunking — never splits mid-sentence.
    Better for documents where sentence boundaries matter.
    """
    # Split on sentence boundaries
    sentences = re.split(r'(?<=[.!?])\s+', text.strip())
    
    chunks = []
    current_chunk = []
    current_length = 0
    
    for sentence in sentences:
        if current_length + len(sentence) > max_chars and current_chunk:
            chunks.append(" ".join(current_chunk))
            # Overlap: keep last N sentences for context
            current_chunk = current_chunk[-overlap_sentences:]
            current_length = sum(len(s) for s in current_chunk)
        
        current_chunk.append(sentence)
        current_length += len(sentence)
    
    if current_chunk:
        chunks.append(" ".join(current_chunk))
    
    return chunks

def chunk_markdown(text: str, max_chars: int = 2000) -> List[dict]:
    """
    Structure-aware chunking for markdown documents.
    Respects heading hierarchy for better retrieval context.
    """
    chunks = []
    current_section = {"heading": "", "content": [], "level": 0}
    
    for line in text.split("\n"):
        heading_match = re.match(r"^(#{1,6})\s+(.+)", line)
        
        if heading_match:
            # Save current section before starting new one
            if current_section["content"]:
                content = "\n".join(current_section["content"])
                if content.strip():
                    chunks.append({
                        "heading": current_section["heading"],
                        "content": content,
                        "full_text": f"{current_section['heading']}\n{content}",
                    })
            
            level = len(heading_match.group(1))
            heading_text = heading_match.group(2)
            current_section = {"heading": f"{'#' * level} {heading_text}", "content": [], "level": level}
        else:
            current_section["content"].append(line)
    
    # Don't forget the last section
    if current_section["content"]:
        content = "\n".join(current_section["content"])
        if content.strip():
            chunks.append({
                "heading": current_section["heading"],
                "content": content,
                "full_text": f"{current_section['heading']}\n{content}",
            })
    
    return chunks
```

### 2. Batch Embedding Generation
```python
import asyncio
import time
from typing import List, Optional
import numpy as np
from openai import AsyncOpenAI

client = AsyncOpenAI()

async def embed_texts_openai(
    texts: List[str],
    model: str = "text-embedding-3-small",  # 1536 dims, cheaper
    batch_size: int = 100,
    max_retries: int = 3,
) -> List[List[float]]:
    """
    Batch embed with rate limit handling.
    text-embedding-3-small: $0.02/1M tokens
    text-embedding-3-large: $0.13/1M tokens, 3072 dims
    """
    all_embeddings = []
    
    for i in range(0, len(texts), batch_size):
        batch = texts[i:i + batch_size]
        
        for attempt in range(max_retries):
            try:
                response = await client.embeddings.create(
                    model=model,
                    input=batch,
                    encoding_format="float",  # or "base64" for efficiency
                )
                embeddings = [e.embedding for e in response.data]
                all_embeddings.extend(embeddings)
                print(f"Embedded batch {i//batch_size + 1}: {len(batch)} texts")
                break
            except Exception as e:
                if attempt == max_retries - 1:
                    raise
                wait = 2 ** attempt
                print(f"Retrying batch {i//batch_size + 1} after {wait}s: {e}")
                await asyncio.sleep(wait)
    
    return all_embeddings

# HuggingFace local embeddings (no API cost)
from sentence_transformers import SentenceTransformer
import torch

def embed_texts_local(
    texts: List[str],
    model_name: str = "BAAI/bge-small-en-v1.5",  # 384 dims, fast
    batch_size: int = 256,
    normalize: bool = True,
) -> np.ndarray:
    """
    Local embedding — no API cost.
    BAAI/bge-small-en-v1.5: best quality/speed for English
    nomic-ai/nomic-embed-text-v1.5: best for longer documents
    """
    device = "cuda" if torch.cuda.is_available() else "mps" if torch.backends.mps.is_available() else "cpu"
    model = SentenceTransformer(model_name, device=device)
    
    embeddings = model.encode(
        texts,
        batch_size=batch_size,
        normalize_embeddings=normalize,  # Normalize for cosine similarity
        show_progress_bar=True,
        convert_to_numpy=True,
    )
    
    return embeddings
```

### 3. Storing Embeddings in pgvector
```python
import asyncpg
import numpy as np
from typing import List, Optional
import json

async def setup_pgvector(pool: asyncpg.Pool, dims: int = 1536):
    """Set up pgvector extension and documents table."""
    async with pool.acquire() as conn:
        await conn.execute("CREATE EXTENSION IF NOT EXISTS vector")
        await conn.execute(f"""
            CREATE TABLE IF NOT EXISTS document_chunks (
                id          BIGSERIAL PRIMARY KEY,
                doc_id      TEXT NOT NULL,
                chunk_index INT NOT NULL,
                content     TEXT NOT NULL,
                metadata    JSONB NOT NULL DEFAULT '{{}}',
                embedding   vector({dims}),
                created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                UNIQUE(doc_id, chunk_index)
            )
        """)
        # HNSW index for approximate nearest neighbor (fast but memory-heavy)
        await conn.execute("""
            CREATE INDEX IF NOT EXISTS idx_chunks_embedding_hnsw
            ON document_chunks USING hnsw (embedding vector_cosine_ops)
            WITH (m = 16, ef_construction = 64)
        """)
        # Or IVFFlat (less memory, slightly slower queries)
        # CREATE INDEX ... USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100)

async def upsert_chunks(
    pool: asyncpg.Pool,
    doc_id: str,
    chunks: List[str],
    embeddings: List[List[float]],
    metadata: dict = {},
):
    """Insert or update document chunks with their embeddings."""
    async with pool.acquire() as conn:
        async with conn.transaction():
            # Remove old chunks for this document
            await conn.execute("DELETE FROM document_chunks WHERE doc_id = $1", doc_id)
            
            # Bulk insert new chunks
            await conn.executemany("""
                INSERT INTO document_chunks (doc_id, chunk_index, content, metadata, embedding)
                VALUES ($1, $2, $3, $4, $5)
            """, [
                (doc_id, i, chunk, json.dumps(metadata), str(emb))
                for i, (chunk, emb) in enumerate(zip(chunks, embeddings))
            ])

async def semantic_search(
    pool: asyncpg.Pool,
    query_embedding: List[float],
    limit: int = 5,
    similarity_threshold: float = 0.7,
    filter_metadata: Optional[dict] = None,
) -> List[dict]:
    """Find semantically similar chunks using cosine similarity."""
    async with pool.acquire() as conn:
        where_clause = ""
        params = [str(query_embedding), limit, 1 - similarity_threshold]
        
        if filter_metadata:
            where_clause = "AND metadata @> $4"
            params.append(json.dumps(filter_metadata))
        
        rows = await conn.fetch(f"""
            SELECT
                doc_id,
                chunk_index,
                content,
                metadata,
                1 - (embedding <=> $1::vector) AS similarity
            FROM document_chunks
            WHERE 1 - (embedding <=> $1::vector) > $3
            {where_clause}
            ORDER BY embedding <=> $1::vector
            LIMIT $2
        """, *params)
        
        return [dict(row) for row in rows]
```

### 4. Full Embedding Pipeline
```python
import asyncio
from pathlib import Path

class EmbeddingPipeline:
    """End-to-end pipeline: documents → chunks → embeddings → vector store."""
    
    def __init__(self, db_pool, embedding_fn, chunk_fn=chunk_by_sentences):
        self.db = db_pool
        self.embed = embedding_fn
        self.chunk = chunk_fn
    
    async def index_document(
        self,
        doc_id: str,
        text: str,
        metadata: dict = {},
    ) -> int:
        """Index a single document. Returns number of chunks created."""
        # 1. Chunk text
        chunks = self.chunk(text)
        if not chunks:
            return 0
        
        # 2. Generate embeddings
        embeddings = await self.embed(chunks)
        
        # 3. Store in vector DB
        await upsert_chunks(self.db, doc_id, chunks, embeddings, metadata)
        
        return len(chunks)
    
    async def index_directory(self, directory: Path, pattern: str = "**/*.txt") -> dict:
        """Index all matching files in a directory."""
        results = {"indexed": 0, "chunks": 0, "errors": []}
        
        files = list(directory.glob(pattern))
        print(f"Indexing {len(files)} files...")
        
        # Process in batches to avoid memory overload
        batch_size = 10
        for i in range(0, len(files), batch_size):
            batch = files[i:i + batch_size]
            tasks = []
            
            for path in batch:
                text = path.read_text(encoding="utf-8", errors="ignore")
                doc_id = str(path.relative_to(directory))
                tasks.append(self.index_document(doc_id, text, {"path": str(path)}))
            
            batch_results = await asyncio.gather(*tasks, return_exceptions=True)
            
            for path, result in zip(batch, batch_results):
                if isinstance(result, Exception):
                    results["errors"].append({"file": str(path), "error": str(result)})
                else:
                    results["indexed"] += 1
                    results["chunks"] += result
        
        return results
    
    async def search(self, query: str, limit: int = 5, **kwargs) -> List[dict]:
        """Search for documents semantically similar to the query."""
        query_embedding = (await self.embed([query]))[0]
        return await semantic_search(self.db, query_embedding, limit=limit, **kwargs)
```

### 5. Monitoring Embedding Quality
```python
from scipy.spatial.distance import cosine
import numpy as np

def evaluate_embedding_quality(
    test_pairs: List[tuple[str, str, float]],  # (text_a, text_b, expected_similarity)
    embedding_fn,
) -> dict:
    """
    Evaluate embedding quality against known similar/dissimilar pairs.
    expected_similarity: 1.0 = identical, 0.0 = completely different
    """
    texts_a = [p[0] for p in test_pairs]
    texts_b = [p[1] for p in test_pairs]
    expected = [p[2] for p in test_pairs]
    
    embeddings_a = embedding_fn(texts_a)
    embeddings_b = embedding_fn(texts_b)
    
    actual_similarities = [
        1 - cosine(a, b)
        for a, b in zip(embeddings_a, embeddings_b)
    ]
    
    # Pearson correlation between expected and actual
    from scipy.stats import pearsonr
    correlation, p_value = pearsonr(expected, actual_similarities)
    
    return {
        "pearson_correlation": correlation,
        "p_value": p_value,
        "mean_actual_similarity": np.mean(actual_similarities),
        "std_similarity": np.std(actual_similarities),
        "pairs_evaluated": len(test_pairs),
    }

# Standard test set for monitoring drift
QUALITY_TEST_PAIRS = [
    ("The cat sat on the mat", "A feline rested on the rug", 0.9),
    ("Python programming language", "Machine learning algorithms", 0.5),
    ("Invoice payment due", "Financial document billing", 0.8),
    ("The weather is sunny", "Quantum physics equations", 0.0),
]
```

## Key Commands Reference

```bash
# Install dependencies
pip install openai sentence-transformers pgvector asyncpg numpy scipy

# pgvector setup
docker run -d --name pgvector -e POSTGRES_PASSWORD=pass -p 5432:5432 pgvector/pgvector:pg16

# Check index usage
psql -c "EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM document_chunks ORDER BY embedding <=> '[0.1,0.2,...]' LIMIT 5;"

# Monitor index size
psql -c "SELECT pg_size_pretty(pg_relation_size('idx_chunks_embedding_hnsw'));"

# Rebuild HNSW index with higher quality settings
psql -c "DROP INDEX idx_chunks_embedding_hnsw; CREATE INDEX idx_chunks_embedding_hnsw ON document_chunks USING hnsw (embedding vector_cosine_ops) WITH (m=32, ef_construction=128);"

# Count embeddings per document
psql -c "SELECT doc_id, COUNT(*) as chunks FROM document_chunks GROUP BY doc_id ORDER BY chunks DESC LIMIT 10;"
```

## Common Patterns

### Pattern 1: Hybrid Search (BM25 + Dense)
```python
async def hybrid_search(pool, query: str, query_embedding: List[float], limit: int = 5, alpha: float = 0.5) -> List[dict]:
    """Combine keyword (BM25) and semantic (dense) search with RRF fusion."""
    async with pool.acquire() as conn:
        # Dense search results with rank
        dense_results = await conn.fetch("""
            SELECT doc_id, content, embedding <=> $1::vector as distance,
                   ROW_NUMBER() OVER (ORDER BY embedding <=> $1::vector) as dense_rank
            FROM document_chunks ORDER BY distance LIMIT $2
        """, str(query_embedding), limit * 3)
        
        # BM25 / full-text search results with rank
        bm25_results = await conn.fetch("""
            SELECT doc_id, content, ts_rank(to_tsvector('english', content), query) as bm25_score,
                   ROW_NUMBER() OVER (ORDER BY ts_rank(to_tsvector('english', content), query) DESC) as bm25_rank
            FROM document_chunks, to_tsquery('english', $1) query
            WHERE to_tsvector('english', content) @@ query
            LIMIT $2
        """, " & ".join(query.split()), limit * 3)
        
        # RRF fusion: score = sum(1 / (k + rank))
        k = 60
        scores: dict = {}
        for row in dense_results:
            key = (row["doc_id"], row["content"])
            scores[key] = scores.get(key, 0) + alpha * (1 / (k + row["dense_rank"]))
        for row in bm25_results:
            key = (row["doc_id"], row["content"])
            scores[key] = scores.get(key, 0) + (1 - alpha) * (1 / (k + row["bm25_rank"]))
        
        return [{"doc_id": k[0], "content": k[1], "score": v}
                for k, v in sorted(scores.items(), key=lambda x: -x[1])[:limit]]
```

### Pattern 2: Incremental Re-embedding After Model Update
```python
async def re_embed_all(pool, new_embedding_fn, batch_size: int = 500):
    """Re-embed all chunks when switching embedding models."""
    async with pool.acquire() as conn:
        total = await conn.fetchval("SELECT COUNT(*) FROM document_chunks")
        print(f"Re-embedding {total} chunks...")
        
        offset = 0
        while offset < total:
            rows = await conn.fetch("""
                SELECT id, content FROM document_chunks 
                ORDER BY id LIMIT $1 OFFSET $2
            """, batch_size, offset)
            
            if not rows:
                break
            
            texts = [r["content"] for r in rows]
            new_embeddings = await new_embedding_fn(texts)
            
            await conn.executemany(
                "UPDATE document_chunks SET embedding = $1 WHERE id = $2",
                [(str(emb), row["id"]) for emb, row in zip(new_embeddings, rows)]
            )
            
            offset += batch_size
            print(f"Re-embedded {min(offset, total)}/{total}")
```

### Pattern 3: Embedding Cache (Avoid Re-embedding Unchanged Content)
```python
import hashlib

async def embed_with_cache(texts: List[str], cache: dict, embed_fn) -> List[List[float]]:
    """Only embed texts not already in cache (by content hash)."""
    to_embed = []
    indices = []
    results = [None] * len(texts)
    
    for i, text in enumerate(texts):
        h = hashlib.sha256(text.encode()).hexdigest()
        if h in cache:
            results[i] = cache[h]
        else:
            to_embed.append(text)
            indices.append((i, h))
    
    if to_embed:
        new_embeddings = await embed_fn(to_embed)
        for (i, h), embedding in zip(indices, new_embeddings):
            cache[h] = embedding
            results[i] = embedding
    
    return results
```

## Pitfalls to Avoid

1. **Chunking too large or too small**: Chunks of 50 tokens often lack context; chunks of 2000 tokens dilute the embedding signal. Target 200-500 tokens for retrieval, 500-1000 for summarization. Always include overlap (10-20%) to avoid cutting context at boundaries. For code, chunk by function/class, not arbitrary token count.

2. **Not normalizing embeddings before cosine similarity**: If you compute cosine similarity with un-normalized vectors, you get inconsistent results because magnitude affects the dot product. Normalize at embedding time (`normalize_embeddings=True` in sentence-transformers) and use `<=>` (cosine distance) operator in pgvector, not `<->` (L2 distance), for semantic similarity.

3. **Ignoring embedding model updates**: When OpenAI releases `text-embedding-3-small` after you've indexed with `text-embedding-ada-002`, your old vectors are in a different space — mixing them produces garbage retrieval. Track the model version alongside each embedding. Never mix vectors from different models in the same collection without re-embedding everything.

## Related Skills

- `semantic-search` — Full semantic search stack with reranking
- `rag-pipeline` — RAG with embedding retrieval
- `postgres-advanced` — pgvector index tuning
- `ray-distributed-computing` — Parallel embedding at scale

## GitNexus Index

```json
{
  "skill": "embedding-pipeline",
  "category": "ai-ml",
  "triggers": ["embedding pipeline", "text embeddings", "vector embeddings", "chunking strategy", "pgvector", "openai embeddings", "sentence transformers", "semantic indexing"],
  "outputs": ["chunker", "batch embedder", "vector storage", "similarity search", "hybrid search"],
  "complexity": "high",
  "tools": ["openai", "sentence-transformers", "pgvector", "asyncpg", "numpy", "pytorch"]
}
```
