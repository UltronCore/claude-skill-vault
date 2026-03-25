# RAG Pipeline Setup

**Category:** orchestration
**Status:** active
**Version:** v1

## What it does
Provides patterns for building Retrieval-Augmented Generation pipelines that give Claude access to external knowledge bases, documents, and codebases.

## When to use
- Claude needs to answer questions from a set of documents
- Building a knowledge base with semantic search
- Augmenting Claude responses with retrieved context
- Setting up vector storage (Chroma, Qdrant, pgvector)

## What it produces
Working RAG implementation using Chroma + sentence-transformers, LlamaIndex higher-level pattern, and vector DB selection guidance.

## Related skills
supabase-prisma-database-management (pgvector), vector-db-integration
