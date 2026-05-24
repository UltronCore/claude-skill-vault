---
name: haystack
description: Production-ready LLM pipeline framework with component-based architecture for RAG and QA
version: 1.0.0
tags: [llm, rag, pipeline, haystack, document-store, question-answering]
---

# Haystack — LLM Pipeline Framework

## Overview

Haystack (by deepset) is a production-ready framework for building NLP/LLM pipelines with a modular component architecture. It excels at RAG (Retrieval-Augmented Generation), document Q&A, and agentic workflows. Components (retrievers, readers, generators, converters) connect via pipelines. Supports 30+ document stores, all major LLM providers, and has built-in evaluation tooling.

GitHub: https://github.com/deepset-ai/haystack (18k+ stars)

## When to Use

- Building RAG pipelines with production-quality document processing
- Document Q&A over large corpus (PDFs, web pages, databases)
- Multi-hop question answering
- Modular NLP pipeline with swappable components
- Evaluating RAG quality with built-in evaluation framework

## Installation

```bash
pip install haystack-ai

# With specific integrations
pip install haystack-ai chroma-haystack sentence-transformers
```

## Key Patterns / Usage

### Basic RAG Pipeline
```python
from haystack import Pipeline, Document
from haystack.components.retrievers.in_memory import InMemoryBM25Retriever
from haystack.components.generators import OpenAIGenerator
from haystack.components.builders import PromptBuilder
from haystack.document_stores.in_memory import InMemoryDocumentStore

# Setup document store
document_store = InMemoryDocumentStore()
document_store.write_documents([
    Document(content="Python was created by Guido van Rossum in 1991."),
    Document(content="Python 3.12 was released in October 2023."),
    Document(content="Python is known for its clean, readable syntax."),
])

# Build RAG pipeline
template = """
Given the context below, answer the question.
Context: {% for doc in documents %}{{ doc.content }}{% endfor %}
Question: {{ question }}
"""

pipeline = Pipeline()
pipeline.add_component("retriever", InMemoryBM25Retriever(document_store=document_store))
pipeline.add_component("prompt_builder", PromptBuilder(template=template))
pipeline.add_component("llm", OpenAIGenerator(model="gpt-4o-mini"))

pipeline.connect("retriever", "prompt_builder.documents")
pipeline.connect("prompt_builder", "llm")

result = pipeline.run({
    "retriever": {"query": "When was Python created?"},
    "prompt_builder": {"question": "When was Python created?"},
})
print(result["llm"]["replies"][0])
```

### Document Indexing with Embeddings
```python
from haystack.components.embedders import SentenceTransformersDocumentEmbedder, SentenceTransformersTextEmbedder
from haystack.components.writers import DocumentWriter
from haystack.components.retrievers import InMemoryEmbeddingRetriever
from haystack.document_stores.in_memory import InMemoryDocumentStore

# Indexing pipeline
document_store = InMemoryDocumentStore()

indexing = Pipeline()
indexing.add_component("embedder", SentenceTransformersDocumentEmbedder())
indexing.add_component("writer", DocumentWriter(document_store=document_store))
indexing.connect("embedder", "writer")

documents = [
    Document(content="Haystack supports multiple document stores."),
    Document(content="You can use OpenSearch, Elasticsearch, Chroma with Haystack."),
]
indexing.run({"embedder": {"documents": documents}})

# Query pipeline
querying = Pipeline()
querying.add_component("text_embedder", SentenceTransformersTextEmbedder())
querying.add_component("retriever", InMemoryEmbeddingRetriever(document_store=document_store))

querying.connect("text_embedder.embedding", "retriever.query_embedding")

result = querying.run({"text_embedder": {"text": "What document stores are supported?"}})
for doc in result["retriever"]["documents"]:
    print(f"[{doc.score:.2f}] {doc.content}")
```

### PDF Document Processing
```python
from haystack.components.converters import PyPDFToDocument
from haystack.components.preprocessors import DocumentSplitter, DocumentCleaner

indexing = Pipeline()
indexing.add_component("converter", PyPDFToDocument())
indexing.add_component("cleaner", DocumentCleaner())
indexing.add_component(
    "splitter",
    DocumentSplitter(split_by="sentence", split_length=5, split_overlap=2)
)
indexing.add_component("embedder", SentenceTransformersDocumentEmbedder())
indexing.add_component("writer", DocumentWriter(document_store=document_store))

indexing.connect("converter", "cleaner")
indexing.connect("cleaner", "splitter")
indexing.connect("splitter", "embedder")
indexing.connect("embedder", "writer")

indexing.run({"converter": {"sources": ["document.pdf"]}})
```

### Agentic Pipeline with Tools
```python
from haystack.components.routers import MetadataRouter
from haystack.components.generators.chat import OpenAIChatGenerator
from haystack.dataclasses import ChatMessage

# Tool-using agent
tools = [
    {
        "type": "function",
        "function": {
            "name": "search_documents",
            "description": "Search the document store for relevant information",
            "parameters": {
                "type": "object",
                "properties": {"query": {"type": "string"}},
                "required": ["query"],
            },
        },
    }
]

generator = OpenAIChatGenerator(model="gpt-4o", generation_kwargs={"tools": tools})
```

### Evaluation
```python
from haystack.evaluation import EvaluationRunResult
from haystack.components.evaluators import (
    FaithfulnessEvaluator,
    ContextRelevanceEvaluator,
    SASEvaluator,
)

faithfulness = FaithfulnessEvaluator()
relevance = ContextRelevanceEvaluator()

questions = ["What is Python?", "When was it created?"]
contexts = [["Python is a high-level language..."], ["Python was created in 1991..."]]
responses = ["Python is a programming language.", "It was created in 1991."]

faith_result = faithfulness.run(questions=questions, contexts=contexts, responses=responses)
rel_result = relevance.run(questions=questions, contexts=contexts)

print(f"Faithfulness: {faith_result['score']:.2f}")
print(f"Relevance: {rel_result['score']:.2f}")
```

## Common Pitfalls

- **Component connections**: connections must match exact output/input names; use `pipeline.show()` to debug
- **Document store persistence**: `InMemoryDocumentStore` loses data on restart; use persistent stores for production
- **Embedding dimensions**: ensure embedder model dimensions match what the document store expects
- **Token limits**: splitter chunk sizes should account for embedding model token limits
- **Pipeline serialization**: pipelines can be serialized to YAML; custom components need `@component` decorator

## Related Skills

- `rag-pipeline` — general RAG pipeline patterns
- `vector-rag-advanced` — advanced RAG techniques
- `ragas` — RAG evaluation framework
- `langchain` — alternative pipeline framework
- `embedding-pipeline` — embedding generation patterns

## GitNexus Index

```
tool: haystack
category: llm-pipeline
tier: library
interface: python-sdk
platform: cross-platform
stars: 18000+
```
