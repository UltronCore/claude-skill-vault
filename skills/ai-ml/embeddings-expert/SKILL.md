---
name: embeddings-expert
description: >
  Text embeddings for semantic search, clustering, RAG retrieval, and similarity. Triggers on: embeddings, embedding model, sentence-transformers, text-embedding, cosine similarity, semantic search, vector similarity.
---

# Embeddings Expert

## When to Use
- Building semantic search or similarity matching
- Setting up RAG (Retrieval-Augmented Generation) retrieval
- Clustering or classifying text by meaning
- Choosing an embedding model for a project
- Computing cosine similarity between texts
- Chunking documents for embedding

## Core Rules
1. Normalize embeddings before computing cosine similarity — most libraries return unnormalized vectors.
2. Choose embedding dimensions based on your use case: 384 (fast/small), 768 (balanced), 1536+ (high quality).
3. Chunk documents before embedding — embedding a 10k-word doc produces one vector that loses detail.
4. Match your embedding model at query time — never mix embeddings from different models.
5. For RAG, embed chunks at index time; embed queries at request time using the same model.
6. Use `sentence-transformers` locally for free, private embeddings; use APIs for managed/scalable embedding.
7. Cosine similarity ranges from -1 to 1; semantic matches are typically > 0.7 for same-topic content.
8. Hybrid search (BM25 + embeddings) outperforms either alone — use BM25 for keyword recall.
9. Store embeddings as `float32` arrays; quantize to `int8` only if storage is critical.
10. Batch embed large document sets — single-item API calls are wasteful at scale.

## Embedding Model Comparison

| Model | Provider | Dimensions | Max Tokens | Notes |
|-------|----------|-----------|------------|-------|
| `text-embedding-3-small` | OpenAI | 1536 | 8191 | Good default, cheap |
| `text-embedding-3-large` | OpenAI | 3072 | 8191 | Best OpenAI quality |
| `text-embedding-ada-002` | OpenAI | 1536 | 8191 | Legacy, use 3-small instead |
| `nomic-embed-text` | Ollama (local) | 768 | 8192 | Free, good quality |
| `mxbai-embed-large` | Ollama (local) | 1024 | 512 | High quality local |
| `all-MiniLM-L6-v2` | sentence-transformers | 384 | 256 | Fast, tiny, good |
| `all-mpnet-base-v2` | sentence-transformers | 768 | 384 | Best sentence-transformers |
| `BAAI/bge-large-en-v1.5` | sentence-transformers | 1024 | 512 | Top open-source quality |

## OpenAI Embeddings (Python)

```python
from openai import OpenAI
import numpy as np

client = OpenAI()  # Uses OPENAI_API_KEY env var

def embed_text(text: str, model: str = "text-embedding-3-small") -> list[float]:
    """Embed a single text string."""
    text = text.replace("\n", " ")  # Normalize newlines
    response = client.embeddings.create(input=text, model=model)
    return response.data[0].embedding

def embed_batch(texts: list[str], model: str = "text-embedding-3-small") -> list[list[float]]:
    """Embed multiple texts in one API call."""
    texts = [t.replace("\n", " ") for t in texts]
    response = client.embeddings.create(input=texts, model=model)
    # Results are in order
    return [item.embedding for item in sorted(response.data, key=lambda x: x.index)]

# Usage
embedding = embed_text("The quick brown fox jumps over the lazy dog")
print(f"Dimensions: {len(embedding)}")  # 1536

batch = embed_batch(["Hello world", "Goodbye world", "Python is great"])
print(f"Batch size: {len(batch)}, dims: {len(batch[0])}")
```

## Sentence-Transformers (Local, Free)

```python
from sentence_transformers import SentenceTransformer
import numpy as np

# Load model (downloads automatically on first use, cached locally)
model = SentenceTransformer("all-MiniLM-L6-v2")       # 384-dim, fast
# model = SentenceTransformer("all-mpnet-base-v2")    # 768-dim, better
# model = SentenceTransformer("BAAI/bge-large-en-v1.5")  # 1024-dim, best

# Single embedding
embedding = model.encode("Hello world")  # numpy array
print(f"Shape: {embedding.shape}")  # (384,)

# Batch embedding (much faster than one-by-one)
texts = ["First document", "Second document", "Third document"]
embeddings = model.encode(texts, batch_size=32, show_progress_bar=True)
print(f"Shape: {embeddings.shape}")  # (3, 384)

# Normalize for cosine similarity
from sentence_transformers import util
embeddings_normalized = model.encode(texts, normalize_embeddings=True)
```

## Ollama Embeddings (Local)

```python
import requests
import numpy as np

def embed_ollama(text: str, model: str = "nomic-embed-text") -> list[float]:
    response = requests.post(
        "http://localhost:11434/api/embeddings",
        json={"model": model, "prompt": text}
    )
    return response.json()["embedding"]

def embed_ollama_batch(texts: list[str], model: str = "nomic-embed-text") -> list[list[float]]:
    return [embed_ollama(t, model) for t in texts]

embedding = embed_ollama("Hello world")
print(f"Dimensions: {len(embedding)}")  # 768 for nomic-embed-text
```

## Cosine Similarity

```python
import numpy as np
from typing import Union

def cosine_similarity(a: list[float], b: list[float]) -> float:
    """Compute cosine similarity between two embedding vectors."""
    a = np.array(a, dtype=np.float32)
    b = np.array(b, dtype=np.float32)
    return float(np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b)))

def top_k_similar(
    query_embedding: list[float],
    candidate_embeddings: list[list[float]],
    texts: list[str],
    k: int = 5,
) -> list[dict]:
    """Find the top-k most similar texts to a query."""
    query = np.array(query_embedding, dtype=np.float32)
    corpus = np.array(candidate_embeddings, dtype=np.float32)

    # Normalize
    query = query / np.linalg.norm(query)
    norms = np.linalg.norm(corpus, axis=1, keepdims=True)
    corpus_normalized = corpus / np.where(norms == 0, 1, norms)

    # Compute similarities (vectorized)
    similarities = corpus_normalized @ query

    # Get top-k indices
    top_indices = np.argsort(similarities)[::-1][:k]

    return [
        {"text": texts[i], "score": float(similarities[i]), "index": int(i)}
        for i in top_indices
    ]

# Example usage
from sentence_transformers import SentenceTransformer

model = SentenceTransformer("all-MiniLM-L6-v2")
docs = [
    "Python is a programming language",
    "Machine learning uses statistics",
    "Cats are domestic animals",
    "Deep learning is a subset of ML",
]
doc_embeddings = model.encode(docs).tolist()
query_embedding = model.encode("What is machine learning?").tolist()

results = top_k_similar(query_embedding, doc_embeddings, docs, k=2)
for r in results:
    print(f"{r['score']:.3f}: {r['text']}")
```

## Document Chunking Strategies

```python
from typing import Generator

def chunk_by_words(text: str, chunk_size: int = 200, overlap: int = 50) -> list[str]:
    """Split text into overlapping word-based chunks."""
    words = text.split()
    chunks = []
    start = 0
    while start < len(words):
        end = min(start + chunk_size, len(words))
        chunk = " ".join(words[start:end])
        chunks.append(chunk)
        if end == len(words):
            break
        start += chunk_size - overlap
    return chunks

def chunk_by_sentences(text: str, max_sentences: int = 5, overlap: int = 1) -> list[str]:
    """Split text into sentence-based chunks."""
    import re
    sentences = re.split(r"(?<=[.!?])\s+", text.strip())
    chunks = []
    start = 0
    while start < len(sentences):
        end = min(start + max_sentences, len(sentences))
        chunks.append(" ".join(sentences[start:end]))
        if end == len(sentences):
            break
        start += max_sentences - overlap
    return chunks

def chunk_by_tokens(text: str, model_name: str = "cl100k_base", max_tokens: int = 256, overlap: int = 32) -> list[str]:
    """Chunk by actual token count using tiktoken."""
    import tiktoken
    enc = tiktoken.get_encoding(model_name)
    tokens = enc.encode(text)
    chunks = []
    start = 0
    while start < len(tokens):
        end = min(start + max_tokens, len(tokens))
        chunks.append(enc.decode(tokens[start:end]))
        if end == len(tokens):
            break
        start += max_tokens - overlap
    return chunks

# Chunk selection guide:
# - Short docs (< 500 words): no chunking needed
# - Articles/blog posts: sentence chunks (3-5 sentences)
# - Long documents: token chunks (256-512 tokens with overlap)
# - Code files: chunk by function/class (AST-based)
```

## Simple In-Memory Semantic Search

```python
import json
import pickle
from pathlib import Path
from sentence_transformers import SentenceTransformer
import numpy as np

class SemanticSearch:
    def __init__(self, model_name: str = "all-MiniLM-L6-v2"):
        self.model = SentenceTransformer(model_name)
        self.documents: list[dict] = []
        self.embeddings: np.ndarray | None = None

    def add_documents(self, docs: list[str], metadata: list[dict] = None):
        """Add documents and compute their embeddings."""
        if metadata is None:
            metadata = [{} for _ in docs]
        new_embeddings = self.model.encode(docs, normalize_embeddings=True)
        for text, meta, emb in zip(docs, metadata, new_embeddings):
            self.documents.append({"text": text, "metadata": meta})
        if self.embeddings is None:
            self.embeddings = new_embeddings
        else:
            self.embeddings = np.vstack([self.embeddings, new_embeddings])

    def search(self, query: str, k: int = 5, threshold: float = 0.0) -> list[dict]:
        """Search for the most similar documents."""
        if self.embeddings is None or len(self.documents) == 0:
            return []
        query_emb = self.model.encode(query, normalize_embeddings=True)
        scores = self.embeddings @ query_emb
        top_k = np.argsort(scores)[::-1][:k]
        return [
            {**self.documents[i], "score": float(scores[i])}
            for i in top_k
            if scores[i] >= threshold
        ]

    def save(self, path: str):
        data = {"documents": self.documents, "embeddings": self.embeddings}
        with open(path, "wb") as f:
            pickle.dump(data, f)

    def load(self, path: str):
        with open(path, "rb") as f:
            data = pickle.load(f)
        self.documents = data["documents"]
        self.embeddings = data["embeddings"]

# Usage
search = SemanticSearch()
search.add_documents([
    "Python is great for data science",
    "JavaScript runs in the browser",
    "Rust is a systems programming language",
], metadata=[{"lang": "python"}, {"lang": "js"}, {"lang": "rust"}])

results = search.search("what language is good for ML?", k=2)
for r in results:
    print(f"{r['score']:.3f}: {r['text']}")
```

## Hybrid Search (BM25 + Embeddings)

```python
from rank_bm25 import BM25Okapi  # pip install rank-bm25
import numpy as np
from sentence_transformers import SentenceTransformer

class HybridSearch:
    def __init__(self, model_name: str = "all-MiniLM-L6-v2"):
        self.model = SentenceTransformer(model_name)
        self.documents: list[str] = []
        self.embeddings: np.ndarray | None = None
        self.bm25: BM25Okapi | None = None

    def index(self, documents: list[str]):
        self.documents = documents
        # BM25 index
        tokenized = [doc.lower().split() for doc in documents]
        self.bm25 = BM25Okapi(tokenized)
        # Dense embeddings
        self.embeddings = self.model.encode(documents, normalize_embeddings=True)

    def search(self, query: str, k: int = 5, alpha: float = 0.5) -> list[dict]:
        """
        Hybrid search combining BM25 and dense retrieval.
        alpha=0.0 → pure BM25, alpha=1.0 → pure dense, alpha=0.5 → balanced
        """
        # BM25 scores
        bm25_scores = self.bm25.get_scores(query.lower().split())
        bm25_norm = (bm25_scores - bm25_scores.min()) / (bm25_scores.max() - bm25_scores.min() + 1e-8)

        # Dense scores
        query_emb = self.model.encode(query, normalize_embeddings=True)
        dense_scores = self.embeddings @ query_emb
        dense_norm = (dense_scores - dense_scores.min()) / (dense_scores.max() - dense_scores.min() + 1e-8)

        # Combine
        combined = alpha * dense_norm + (1 - alpha) * bm25_norm
        top_k = np.argsort(combined)[::-1][:k]

        return [
            {"text": self.documents[i], "score": float(combined[i]),
             "bm25_score": float(bm25_norm[i]), "dense_score": float(dense_norm[i])}
            for i in top_k
        ]

# Usage
hybrid = HybridSearch()
hybrid.index(["Python programming guide", "Machine learning basics", "Web development with JavaScript"])
results = hybrid.search("ML tutorial", k=2)
```

## RAG Retrieval Pattern

```python
import anthropic
from sentence_transformers import SentenceTransformer

client = anthropic.Anthropic()
search_engine = SemanticSearch()  # From above

def rag_answer(question: str, k: int = 5) -> str:
    """Answer a question using RAG."""
    # 1. Retrieve relevant chunks
    results = search_engine.search(question, k=k, threshold=0.3)

    if not results:
        context = "No relevant documents found."
    else:
        context = "\n\n---\n\n".join(
            f"[Score: {r['score']:.2f}]\n{r['text']}" for r in results
        )

    # 2. Generate answer with context
    response = client.messages.create(
        model="claude-sonnet-4-5",
        max_tokens=1024,
        system="You are a helpful assistant. Answer questions based on the provided context. If the context doesn't contain enough information, say so.",
        messages=[
            {
                "role": "user",
                "content": f"Context:\n{context}\n\nQuestion: {question}"
            }
        ],
    )
    return response.content[0].text
```

## TypeScript: OpenAI Embeddings

```typescript
import OpenAI from "openai";

const client = new OpenAI();

async function embedText(text: string): Promise<number[]> {
  const response = await client.embeddings.create({
    input: text.replace(/\n/g, " "),
    model: "text-embedding-3-small",
  });
  return response.data[0].embedding;
}

async function embedBatch(texts: string[]): Promise<number[][]> {
  const response = await client.embeddings.create({
    input: texts.map((t) => t.replace(/\n/g, " ")),
    model: "text-embedding-3-small",
  });
  return response.data.sort((a, b) => a.index - b.index).map((d) => d.embedding);
}

function cosineSimilarity(a: number[], b: number[]): number {
  const dot = a.reduce((sum, val, i) => sum + val * b[i], 0);
  const normA = Math.sqrt(a.reduce((sum, val) => sum + val * val, 0));
  const normB = Math.sqrt(b.reduce((sum, val) => sum + val * val, 0));
  return dot / (normA * normB);
}

// Usage
const queryEmb = await embedText("machine learning tutorial");
const docEmbs = await embedBatch(["Python ML guide", "JavaScript basics", "Deep learning intro"]);
const scores = docEmbs.map((emb) => cosineSimilarity(queryEmb, emb));
console.log(scores); // e.g., [0.82, 0.41, 0.79]
```
