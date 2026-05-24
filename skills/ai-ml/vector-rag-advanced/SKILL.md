---
name: vector-rag-advanced
description: >
  Advanced RAG patterns: hybrid search, reranking, chunking strategies, query transformation, and eval. Triggers on: RAG, retrieval augmented generation, reranking, hybrid search, BM25, pgvector, chunk strategy, query expansion, RAG eval.
---

# Advanced RAG (Retrieval-Augmented Generation)

## When to Use
Use this skill when building or improving a RAG system: choosing chunking strategy, setting up pgvector in Supabase, implementing hybrid search (vector + BM25), adding reranking, transforming queries (HyDE, multi-query), or evaluating retrieval quality.

---

## Core Rules
- Chunking strategy is the #1 lever — get this right before tuning anything else.
- Hybrid search (vector + BM25) almost always beats vector-only; implement it from the start.
- Reranking is cheap compute for large retrieval gains — always add a reranker before the LLM context window.
- Embedding model matters: domain-specific embeddings (e.g., medical, code) outperform general models. Test before committing.
- Evaluate retrieval separately from generation — measure context recall and relevance before measuring answer quality.
- Chunk overlap prevents context loss at boundaries: 10–20% overlap of chunk size is typical.

---

## Chunking Strategies

### 1. Fixed-Size Chunking (baseline)
```python
from langchain.text_splitter import RecursiveCharacterTextSplitter

splitter = RecursiveCharacterTextSplitter(
    chunk_size=512,        # characters (not tokens!)
    chunk_overlap=64,      # ~10% overlap
    separators=["\n\n", "\n", ". ", " ", ""],  # tries in order
)

docs = splitter.split_text(long_document)

# Token-aware chunking (more accurate)
from langchain.text_splitter import TokenTextSplitter
token_splitter = TokenTextSplitter(chunk_size=256, chunk_overlap=32)
```

**Use when:** Documents are relatively uniform; quick setup; baseline to beat.

---

### 2. Semantic Chunking (split at meaning boundaries)
```python
from langchain_experimental.text_splitter import SemanticChunker
from langchain_openai import OpenAIEmbeddings

embeddings = OpenAIEmbeddings()
semantic_splitter = SemanticChunker(
    embeddings,
    breakpoint_threshold_type="percentile",  # or "standard_deviation", "interquartile"
    breakpoint_threshold_amount=95,          # split when similarity drops below 95th pct
)

docs = semantic_splitter.split_text(long_document)
```

**Use when:** Long documents with clear topic shifts (articles, chapters, reports).

---

### 3. Hierarchical / Parent-Child Chunking
```python
from langchain.text_splitter import RecursiveCharacterTextSplitter
from langchain.retrievers import ParentDocumentRetriever
from langchain.storage import InMemoryStore
from langchain_community.vectorstores import SupabaseVectorStore

# Large parent chunks (for context)
parent_splitter = RecursiveCharacterTextSplitter(chunk_size=2000, chunk_overlap=200)
# Small child chunks (for precision retrieval)
child_splitter = RecursiveCharacterTextSplitter(chunk_size=400, chunk_overlap=40)

store = InMemoryStore()  # or Redis for production
vectorstore = SupabaseVectorStore(...)

retriever = ParentDocumentRetriever(
    vectorstore=vectorstore,
    docstore=store,
    child_splitter=child_splitter,
    parent_splitter=parent_splitter,
)

# Retrieves small chunks, returns large parent for LLM context
retriever.add_documents(documents)
results = retriever.get_relevant_documents("query here")
```

**Use when:** You need precise retrieval but rich context for generation.

---

### 4. Document-Aware Chunking (markdown, code, HTML)
```python
from langchain.text_splitter import MarkdownHeaderTextSplitter, Language

# Markdown: split by headers
md_splitter = MarkdownHeaderTextSplitter(
    headers_to_split_on=[
        ("#", "h1"), ("##", "h2"), ("###", "h3")
    ]
)
md_docs = md_splitter.split_text(markdown_content)
# Each chunk has metadata: {"h1": "Section Title", "h2": "Subsection"}

# Code: split by language structure
from langchain.text_splitter import RecursiveCharacterTextSplitter
code_splitter = RecursiveCharacterTextSplitter.from_language(
    language=Language.PYTHON,
    chunk_size=1000,
    chunk_overlap=100,
)
code_docs = code_splitter.split_text(python_source)
```

---

## Embedding Model Selection

| Model | Best For | Dim | Notes |
|-------|----------|-----|-------|
| `text-embedding-3-small` (OpenAI) | General purpose, cost-efficient | 1536 | Good default |
| `text-embedding-3-large` (OpenAI) | Best quality general | 3072 | 2× cost |
| `all-MiniLM-L6-v2` (HuggingFace) | Fast, local, free | 384 | Good for dev |
| `BAAI/bge-large-en-v1.5` | Best open-source English | 1024 | Near OpenAI quality |
| `nomic-embed-text` | Long documents (8192 ctx) | 768 | Via Ollama locally |
| `voyage-code-2` (Voyage AI) | Code retrieval | 1536 | Best for code search |

```python
# OpenAI embeddings
from openai import OpenAI
client = OpenAI()

def embed(text: str, model: str = "text-embedding-3-small") -> list[float]:
    response = client.embeddings.create(input=text, model=model)
    return response.data[0].embedding

# Batch embed (up to 2048 items)
def embed_batch(texts: list[str], model: str = "text-embedding-3-small") -> list[list[float]]:
    response = client.embeddings.create(input=texts, model=model)
    return [d.embedding for d in response.data]

# HuggingFace local embedding
from sentence_transformers import SentenceTransformer
model = SentenceTransformer("BAAI/bge-large-en-v1.5")
embeddings = model.encode(texts, normalize_embeddings=True, batch_size=64)
```

---

## pgvector Setup (Supabase)

```sql
-- Enable pgvector extension in Supabase SQL editor
create extension if not exists vector;

-- Create documents table
create table documents (
  id          bigserial primary key,
  content     text not null,
  metadata    jsonb default '{}',
  embedding   vector(1536),   -- match your embedding model's dimensions
  created_at  timestamptz default now()
);

-- Create HNSW index (fastest ANN search, pgvector 0.5+)
create index on documents using hnsw (embedding vector_cosine_ops)
  with (m = 16, ef_construction = 64);

-- Or IVFFlat (older, simpler)
-- create index on documents using ivfflat (embedding vector_cosine_ops)
--   with (lists = 100);  -- lists ≈ sqrt(total rows)

-- Similarity search function
create or replace function match_documents(
  query_embedding vector(1536),
  match_count     int     default 10,
  match_threshold float   default 0.5
)
returns table (id bigint, content text, metadata jsonb, similarity float)
language sql stable
as $$
  select id, content, metadata,
         1 - (embedding <=> query_embedding) as similarity
  from   documents
  where  1 - (embedding <=> query_embedding) > match_threshold
  order  by embedding <=> query_embedding
  limit  match_count;
$$;
```

```python
# Query from Python
from supabase import create_client
import os

supabase = create_client(os.environ["SUPABASE_URL"], os.environ["SUPABASE_KEY"])

def vector_search(query: str, match_count: int = 10) -> list[dict]:
    query_embedding = embed(query)
    result = supabase.rpc("match_documents", {
        "query_embedding": query_embedding,
        "match_count": match_count,
        "match_threshold": 0.5,
    }).execute()
    return result.data

# Insert document
def insert_document(content: str, metadata: dict = {}):
    embedding = embed(content)
    supabase.table("documents").insert({
        "content": content,
        "metadata": metadata,
        "embedding": embedding,
    }).execute()
```

---

## Hybrid Search (Vector + BM25)

Hybrid search combines dense vector search with sparse BM25 keyword matching, then merges results via Reciprocal Rank Fusion (RRF).

```python
# Option 1: Pure Python BM25 + pgvector
from rank_bm25 import BM25Okapi
import numpy as np

class HybridRetriever:
    def __init__(self, documents: list[dict], alpha: float = 0.5):
        """alpha: weight of vector score (0=pure BM25, 1=pure vector)"""
        self.documents = documents
        self.alpha = alpha
        self.contents = [d["content"] for d in documents]
        self.embeddings = embed_batch(self.contents)

        # BM25 setup
        tokenized = [c.lower().split() for c in self.contents]
        self.bm25 = BM25Okapi(tokenized)

    def search(self, query: str, top_k: int = 10) -> list[dict]:
        # Vector scores
        q_emb = np.array(embed(query))
        emb_matrix = np.array(self.embeddings)
        vector_scores = (emb_matrix @ q_emb) / (
            np.linalg.norm(emb_matrix, axis=1) * np.linalg.norm(q_emb) + 1e-8
        )

        # BM25 scores (normalized)
        bm25_scores = np.array(self.bm25.get_scores(query.lower().split()))
        if bm25_scores.max() > 0:
            bm25_scores = bm25_scores / bm25_scores.max()

        # Combine
        combined = self.alpha * vector_scores + (1 - self.alpha) * bm25_scores
        top_indices = np.argsort(combined)[::-1][:top_k]

        return [
            {**self.documents[i], "score": float(combined[i])}
            for i in top_indices
        ]
```

```sql
-- Option 2: pgvector + Postgres full-text search (production approach)
create or replace function hybrid_search(
  query_text      text,
  query_embedding vector(1536),
  match_count     int   default 10,
  full_text_weight float default 1.0,
  semantic_weight  float default 1.0,
  rrf_k           int   default 50
)
returns table (id bigint, content text, metadata jsonb, score float)
language sql stable
as $$
with full_text as (
  select id,
         row_number() over (order by ts_rank_cd(to_tsvector('english', content),
                            plainto_tsquery('english', query_text)) desc) as rank
  from   documents
  where  to_tsvector('english', content) @@ plainto_tsquery('english', query_text)
  order  by rank limit match_count * 2
),
semantic as (
  select id,
         row_number() over (order by embedding <=> query_embedding) as rank
  from   documents
  order  by embedding <=> query_embedding limit match_count * 2
)
select
  coalesce(ft.id, s.id) as id,
  d.content,
  d.metadata,
  coalesce(1.0 / (rrf_k + ft.rank), 0.0) * full_text_weight
  + coalesce(1.0 / (rrf_k + s.rank), 0.0) * semantic_weight as score
from   full_text ft
full outer join semantic s on ft.id = s.id
join   documents d on d.id = coalesce(ft.id, s.id)
order  by score desc
limit  match_count;
$$;
```

---

## Reranking

Reranking re-scores the top-K candidates from retrieval using a more expensive cross-encoder model. Run it on 20–50 candidates, return top 5–10 to the LLM.

```python
# Option 1: Cohere Rerank API (easiest)
import cohere

co = cohere.Client(os.environ["COHERE_API_KEY"])

def rerank(query: str, documents: list[str], top_n: int = 5) -> list[dict]:
    results = co.rerank(
        model="rerank-english-v3.0",
        query=query,
        documents=documents,
        top_n=top_n,
        return_documents=True,
    )
    return [
        {"text": r.document.text, "relevance_score": r.relevance_score, "index": r.index}
        for r in results.results
    ]

# Usage
candidates = vector_search(query, match_count=20)
candidate_texts = [c["content"] for c in candidates]
reranked = rerank(query, candidate_texts, top_n=5)
context = "\n\n---\n\n".join([r["text"] for r in reranked])
```

```python
# Option 2: Local cross-encoder (no API cost)
from sentence_transformers import CrossEncoder

model = CrossEncoder("cross-encoder/ms-marco-MiniLM-L-6-v2")

def rerank_local(query: str, documents: list[str], top_n: int = 5) -> list[dict]:
    pairs = [(query, doc) for doc in documents]
    scores = model.predict(pairs)

    ranked = sorted(
        [{"text": doc, "score": float(score)} for doc, score in zip(documents, scores)],
        key=lambda x: x["score"],
        reverse=True
    )
    return ranked[:top_n]
```

---

## Query Transformation

### HyDE (Hypothetical Document Embeddings)
Generate a fake answer to the query, then embed that as the search query. Dramatically improves recall for "what is X?" style queries.

```python
import anthropic

client = anthropic.Anthropic()

def hyde_query(query: str) -> list[float]:
    """Generate hypothetical document, embed it instead of the raw query."""
    response = client.messages.create(
        model="claude-haiku-4-5",
        max_tokens=300,
        messages=[{
            "role": "user",
            "content": f"Write a short paragraph that would be the perfect answer to this question. Be specific and detailed.\n\nQuestion: {query}\n\nAnswer:"
        }]
    )
    hypothetical_doc = response.content[0].text
    return embed(hypothetical_doc)   # embed the generated answer, not the query

# Then search with this embedding instead of embed(query)
results = vector_search_by_embedding(hyde_query(user_query), match_count=10)
```

---

### Multi-Query Retrieval
Generate multiple phrasings of the query, retrieve for each, merge and deduplicate.

```python
def generate_query_variants(query: str, n: int = 3) -> list[str]:
    response = client.messages.create(
        model="claude-haiku-4-5",
        max_tokens=300,
        messages=[{
            "role": "user",
            "content": f"""Generate {n} different phrasings of this question that could help retrieve relevant documents. 
Return only the questions, one per line, no numbering.

Question: {query}"""
        }]
    )
    variants = response.content[0].text.strip().split("\n")
    return [query] + [v.strip() for v in variants if v.strip()]

def multi_query_retrieve(query: str, top_k_per_query: int = 5) -> list[dict]:
    variants = generate_query_variants(query)
    seen_ids = set()
    all_results = []

    for q in variants:
        results = vector_search(q, match_count=top_k_per_query)
        for r in results:
            if r["id"] not in seen_ids:
                seen_ids.add(r["id"])
                all_results.append(r)

    # Re-rank merged results
    texts = [r["content"] for r in all_results]
    reranked = rerank(query, texts, top_n=min(8, len(texts)))
    return reranked
```

---

### Query Decomposition (for complex questions)
```python
def decompose_query(query: str) -> list[str]:
    """Break complex question into atomic sub-queries."""
    response = client.messages.create(
        model="claude-haiku-4-5",
        max_tokens=400,
        messages=[{
            "role": "user",
            "content": f"""If this question has multiple distinct sub-questions that need separate answers, list them.
If it's already atomic, return just the original question.
Return one question per line.

Question: {query}"""
        }]
    )
    sub_queries = [q.strip() for q in response.content[0].text.strip().split("\n") if q.strip()]
    return sub_queries or [query]
```

---

## RAG Evaluation Metrics

### Key Metrics

| Metric | What it measures | Target |
|--------|-----------------|--------|
| **Context Recall** | % of relevant info retrieved | >0.80 |
| **Context Precision** | % of retrieved chunks that are relevant | >0.70 |
| **Faithfulness** | Answer only uses retrieved context | >0.90 |
| **Answer Relevance** | Answer addresses the question | >0.85 |
| **Hit Rate** | Query's answer in top-K results | >0.80 |
| **MRR** | Mean Reciprocal Rank | >0.60 |

---

### Evaluation with RAGAS

```python
# pip install ragas langchain openai
from ragas import evaluate
from ragas.metrics import (
    faithfulness,
    answer_relevancy,
    context_recall,
    context_precision,
)
from datasets import Dataset

# Build evaluation dataset
eval_data = {
    "question": ["What is the capital of France?", "How does photosynthesis work?"],
    "answer": ["Paris is the capital of France.", "Photosynthesis converts light to energy..."],
    "contexts": [
        ["France is a country in Western Europe. Its capital city is Paris."],
        ["Photosynthesis is a process used by plants to convert sunlight..."],
    ],
    "ground_truth": ["Paris", "Plants use sunlight, water, and CO2 to produce glucose."],
}

dataset = Dataset.from_dict(eval_data)
result = evaluate(dataset, metrics=[faithfulness, answer_relevancy, context_recall, context_precision])
print(result)
# {'faithfulness': 0.95, 'answer_relevancy': 0.88, 'context_recall': 0.82, 'context_precision': 0.76}
```

---

### Quick Eval — Hit Rate and MRR

```python
def evaluate_retrieval(qa_pairs: list[dict], retriever_fn, top_k: int = 10) -> dict:
    """
    qa_pairs: [{"question": "...", "answer_chunk_id": 42}, ...]
    retriever_fn: function(query: str) -> list[{"id": int, ...}]
    """
    hits = 0
    reciprocal_ranks = []

    for pair in qa_pairs:
        results = retriever_fn(pair["question"])
        result_ids = [r["id"] for r in results[:top_k]]
        target_id = pair["answer_chunk_id"]

        if target_id in result_ids:
            hits += 1
            rank = result_ids.index(target_id) + 1
            reciprocal_ranks.append(1.0 / rank)
        else:
            reciprocal_ranks.append(0.0)

    return {
        "hit_rate": hits / len(qa_pairs),
        "mrr": sum(reciprocal_ranks) / len(reciprocal_ranks),
        "n_queries": len(qa_pairs),
    }
```

---

## Common RAG Failure Modes

| Failure | Symptom | Fix |
|---------|---------|-----|
| **Chunk too large** | LLM ignores parts of context | Reduce chunk size; use parent-child |
| **Chunk too small** | Missing context, hallucination | Increase size or add overlap |
| **Semantic drift** | Wrong chunks retrieved | Add HyDE or multi-query |
| **Keyword miss** | Exact term not found | Add BM25 hybrid search |
| **Top-K overload** | LLM loses the relevant part | Reduce K; add reranker |
| **Stale embeddings** | Docs updated, index not** | Set up incremental re-embedding |
| **Missing metadata filters** | Too many irrelevant results | Filter by date/source/category |
| **Lost-in-middle** | Middle chunks ignored by LLM | Reorder context: most relevant first + last |

---

## End-to-End RAG Pipeline Skeleton

```python
import anthropic
from typing import Optional

client = anthropic.Anthropic()

def rag_answer(
    query: str,
    top_k: int = 20,
    rerank_to: int = 5,
    use_hyde: bool = False,
    use_multi_query: bool = False,
) -> dict:
    # Step 1: Query transformation
    if use_hyde:
        search_embedding = hyde_query(query)
        raw_results = vector_search_by_embedding(search_embedding, top_k)
    elif use_multi_query:
        raw_results = multi_query_retrieve(query, top_k_per_query=top_k // 3)
    else:
        raw_results = vector_search(query, match_count=top_k)

    # Step 2: Rerank
    candidate_texts = [r["content"] for r in raw_results]
    reranked = rerank(query, candidate_texts, top_n=rerank_to)

    # Step 3: Build context (most relevant first and last — lost-in-middle mitigation)
    context_chunks = [r["text"] for r in reranked]
    if len(context_chunks) > 2:
        # Put 2nd-best in middle, best and 3rd-best at edges
        context_chunks = [context_chunks[0]] + context_chunks[2:] + [context_chunks[1]]
    context = "\n\n---\n\n".join(context_chunks)

    # Step 4: Generate with Claude
    response = client.messages.create(
        model="claude-sonnet-4-5",
        max_tokens=1024,
        system="You are a helpful assistant. Answer questions using ONLY the provided context. "
               "If the context doesn't contain the answer, say so clearly.",
        messages=[{
            "role": "user",
            "content": f"Context:\n{context}\n\nQuestion: {query}"
        }]
    )

    return {
        "answer": response.content[0].text,
        "sources": reranked,
        "chunks_retrieved": len(raw_results),
        "chunks_used": len(reranked),
    }
```

## Related Skills
- `rag-pipeline` — RAG patterns
- `vector-db-integration` — vector storage
- `embedding-pipeline` — embedding generation

## GitNexus Index
This skill is indexed by GitNexus for knowledge graph traversal.
Index path: /Users/localuser/.claude/skills/vector-rag-advanced/.gitnexus
Last indexed: 2026-05-23
