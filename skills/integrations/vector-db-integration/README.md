# Vector DB Integration

**Category:** integrations
**Status:** active
**Version:** v1

## What it does
Sets up vector database integrations (Chroma, Qdrant, Weaviate) for semantic search and embedding storage in Claude Code projects. Provides ready-to-use code patterns for each database and a decision matrix for choosing the right one.

## When to use
- Adding semantic search to a Claude Code project
- Building a RAG (Retrieval-Augmented Generation) system
- Storing and querying embeddings for similarity search
- Migrating from one vector DB to another

## What it produces
Working vector DB setup code for Chroma (local/prototype), Qdrant (production), or Weaviate (hybrid search), with query patterns ready to integrate into RAG pipelines.

## Related skills
- rag-pipeline-setup (uses vector DB as storage layer)
- supabase-prisma-database-management (alternative: pgvector for Supabase users)
- web-scraping-pipeline (content ingestion that feeds into vector storage)
