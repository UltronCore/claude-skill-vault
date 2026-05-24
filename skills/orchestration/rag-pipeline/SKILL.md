---
name: rag-pipeline
description: Build and optimize RAG pipelines — document ingestion, indexing, retrieval, search backends
type: tool-routing
repos_absorbed: [haystack, ragflow, DocsGPT, meilisearch, typesense, quickwit, hayhooks]
---

# RAG Pipeline

Routes RAG pipeline tasks to the right framework and search backend.

## Stack Decision

| Need | Tool |
|------|------|
| Full RAG pipeline with components | haystack (deepset) |
| Production RAG app with UI + API | ragflow (infiniflow) |
| Open-source ChatGPT for your docs | DocsGPT |
| Fast full-text + vector search (SaaS-friendly) | meilisearch |
| Typo-tolerant search API | typesense |
| Log/event search at scale | quickwit |
| Serve Haystack pipelines as REST API | hayhooks |

## haystack — Composable RAG Pipelines

```python
# pip install haystack-ai

from haystack import Pipeline
from haystack.components.retrievers.in_memory import InMemoryBM25Retriever
from haystack.components.generators import OpenAIGenerator
from haystack.components.builders import PromptBuilder
from haystack.document_stores.in_memory import InMemoryDocumentStore

# Build document store
doc_store = InMemoryDocumentStore()
doc_store.write_documents([
    {"content": "Paris is the capital of France."},
    {"content": "Berlin is the capital of Germany."},
])

# Build RAG pipeline
pipe = Pipeline()
pipe.add_component("retriever", InMemoryBM25Retriever(document_store=doc_store))
pipe.add_component("prompt_builder", PromptBuilder(
    template="Context: {% for doc in documents %}{{ doc.content }}{% endfor %}\n\nQuestion: {{question}}\nAnswer:"
))
pipe.add_component("llm", OpenAIGenerator(model="gpt-4o-mini"))

pipe.connect("retriever.documents", "prompt_builder.documents")
pipe.connect("prompt_builder.prompt", "llm.prompt")

result = pipe.run({"retriever": {"query": "What is the capital of France?"},
                   "prompt_builder": {"question": "What is the capital of France?"}})
print(result["llm"]["replies"][0])
```

**Haystack components**: FileConverters, DocumentSplitters, Embedders (OpenAI/local), Retrievers (BM25/vector), Rerankers, Generators, EvaluationHarness

### Production Vector RAG with Haystack
```python
from haystack.components.embedders import OpenAITextEmbedder, OpenAIDocumentEmbedder
from haystack_integrations.document_stores.qdrant import QdrantDocumentStore

doc_store = QdrantDocumentStore(url="http://localhost:6333", embedding_dim=1536)

indexing = Pipeline()
indexing.add_component("embedder", OpenAIDocumentEmbedder())
indexing.add_component("writer", DocumentWriter(doc_store))
indexing.connect("embedder.documents", "writer.documents")
```

## hayhooks — Serve Haystack as REST API

```bash
# pip install hayhooks

# Serve a pipeline YAML as REST endpoint
hayhooks run --pipelines-dir ./pipelines

# POST to endpoint
curl -X POST http://localhost:1416/pipeline/rag-pipeline/run \
  -H "Content-Type: application/json" \
  -d '{"retriever": {"query": "What is RAG?"}}'
```

## ragflow — Full RAG Application Stack

```bash
# Clone and start
git clone https://github.com/infiniflow/ragflow.git
cd ragflow
docker compose up -d

# Access UI at http://localhost:80
# API at http://localhost:80/v1/
```

**Ragflow features**: Document parsing (PDF, DOCX, PPT, Excel), chunking strategies, vector + keyword hybrid search, built-in chat UI, REST API, multi-model support

**API usage**:
```python
from ragflow_sdk import RAGFlow

rag = RAGFlow(api_key="YOUR_API_KEY", base_url="http://localhost:80")
dataset = rag.create_dataset(name="my_docs")
dataset.upload_documents([{"path": "doc.pdf"}])

chat = rag.create_chat("my_chat", dataset_ids=[dataset.id])
session = chat.create_session()
response = session.ask("What is in the document?")
```

## meilisearch — Fast Full-Text + Vector Search

```bash
# Install and run
brew install meilisearch
meilisearch --master-key="YOUR_MASTER_KEY"
# or Docker:
docker run -p 7700:7700 getmeili/meilisearch:latest
```

```python
# pip install meilisearch

import meilisearch

client = meilisearch.Client("http://localhost:7700", "YOUR_MASTER_KEY")
index = client.index("documents")

# Index documents
index.add_documents([
    {"id": 1, "title": "RAG Tutorial", "content": "RAG stands for..."},
])

# Search
results = index.search("RAG tutorial", {
    "limit": 10,
    "attributesToHighlight": ["content"]
})

# Vector search (semantic)
results = index.search("", {
    "vector": [0.1, 0.2, ...],  # embedding
    "hybrid": {"semanticRatio": 0.9, "embedder": "openai"}
})
```

## typesense — Typo-Tolerant Search API

```bash
# Docker
docker run -p 8108:8108 \
  -v /tmp/typesense-data:/data \
  typesense/typesense:latest \
  --data-dir /data --api-key=xyz --enable-cors
```

```python
# pip install typesense

import typesense

client = typesense.Client({
    "nodes": [{"host": "localhost", "port": "8108", "protocol": "http"}],
    "api_key": "xyz"
})

# Create schema
client.collections.create({
    "name": "docs",
    "fields": [
        {"name": "title", "type": "string"},
        {"name": "content", "type": "string"},
        {"name": "embedding", "type": "float[]", "num_dim": 1536}
    ]
})

# Search
results = client.collections["docs"].documents.search({
    "q": "RAG pipeline",
    "query_by": "title,content",
    "vector_query": "embedding:([...], k:10)"
})
```

## quickwit — Log & Event Search

```bash
# Install
curl -L https://install.quickwit.io | sh

# Start server
./quickwit run

# Create index and ingest
./quickwit index create --index-config config.yaml
./quickwit index ingest --index my-index --input-path logs.json
./quickwit index search --index my-index --query "error AND status:500"
```

**Use quickwit for**: Structured log ingestion, time-series event data, high-volume append-only search, Jaeger-compatible trace storage

## RAG Architecture Patterns

### Naive RAG (baseline)
```
Documents → Chunking → Embedding → Vector Store
Query → Embedding → Retrieval (top-k) → LLM → Answer
```

### Advanced RAG
```
Documents → Smart Chunking → Multi-vector Embedding → Hybrid Store
Query → Query Expansion → Hybrid Retrieval → Reranking → LLM → Answer
```

### Modular RAG (Haystack style)
```
Indexing Pipeline: FileConverter → Splitter → Embedder → Writer
Query Pipeline: Router → Retrievers → Joiner → Reranker → Generator
```

## Decision Guide

**"Build a RAG prototype quickly"** → haystack (InMemory store)
**"Deploy a full RAG web app with UI"** → ragflow
**"Add search to my app"** → meilisearch or typesense
**"Search my logs at scale"** → quickwit
**"Expose my Haystack pipeline as API"** → hayhooks

## Environment Variables

```bash
OPENAI_API_KEY=         # Required for OpenAI embeddings/generation
MEILISEARCH_API_KEY=    # Meilisearch master key
TYPESENSE_API_KEY=      # Typesense API key
RAGFLOW_API_KEY=        # Set in ragflow UI after startup
```

## GitNexus Index
This skill is indexed by GitNexus for knowledge graph traversal.
Index path: /Users/localuser/claude-skill-vault/skills/orchestration/rag-pipeline/.gitnexus
Last indexed: 2026-05-23
