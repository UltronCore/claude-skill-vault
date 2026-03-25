---
name: rag-pipeline-setup
description: Build Retrieval-Augmented Generation (RAG) pipelines that give Claude access to external knowledge bases, documents, and codebases. Use when Claude needs to answer questions from documents, search a knowledge base, or augment responses with retrieved context. Trigger when users mention RAG, embeddings, vector search, document Q&A, knowledge base, semantic search, or llama_index.
---

# RAG Pipeline Setup

RAG connects Claude to external knowledge by embedding documents, storing vectors, and retrieving relevant chunks at query time.

## Minimal RAG stack (Python)

```python
# 1. Embed documents
from anthropic import Anthropic
import chromadb

client = Anthropic()
chroma = chromadb.Client()
collection = chroma.create_collection("docs")

def embed_text(text: str) -> list[float]:
    # Use voyage-3 via Anthropic or any embedding model
    # For local dev: use sentence-transformers
    from sentence_transformers import SentenceTransformer
    model = SentenceTransformer("all-MiniLM-L6-v2")
    return model.encode(text).tolist()

# Index documents
docs = ["doc1 content", "doc2 content"]
for i, doc in enumerate(docs):
    collection.add(
        embeddings=[embed_text(doc)],
        documents=[doc],
        ids=[f"doc_{i}"]
    )

# 2. Retrieve at query time
def retrieve(query: str, n=3) -> list[str]:
    results = collection.query(
        query_embeddings=[embed_text(query)],
        n_results=n
    )
    return results["documents"][0]

# 3. Augment Claude with retrieved context
def rag_query(question: str) -> str:
    context = retrieve(question)
    context_str = "\n\n".join(context)
    response = client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=1024,
        messages=[{
            "role": "user",
            "content": f"Context:\n{context_str}\n\nQuestion: {question}"
        }]
    )
    return response.content[0].text
```

## Vector DB options (by use case)
| DB | Best for | Size |
|---|---|---|
| Chroma | Local dev, prototyping | Small |
| Qdrant | Production, fast retrieval | Medium-large |
| Weaviate | Hybrid search (keyword + vector) | Large |
| Supabase pgvector | Already using Supabase | Any |

## LlamaIndex pattern (higher-level)
```python
from llama_index.core import VectorStoreIndex, SimpleDirectoryReader

# Index a folder of documents
documents = SimpleDirectoryReader("./docs").load_data()
index = VectorStoreIndex.from_documents(documents)
query_engine = index.as_query_engine()
response = query_engine.query("What is X?")
```

## Key decisions
- **Chunking**: Split docs at 512-1024 tokens with 10% overlap
- **Embedding model**: voyage-3 (Anthropic), text-embedding-3-small (OpenAI), or local sentence-transformers
- **Retrieval**: top-3 to top-5 chunks is usually enough
- **Context window**: Claude 3.5+ handles 200k tokens — for large retrieval, summarize chunks first

## Related skills
supabase-prisma-database-management (pgvector), vector-db-integration
