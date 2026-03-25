# Skill Memory: Vector DB Integration

## Purpose
Guides setup of Chroma, Qdrant, and Weaviate vector databases for semantic search, embedding storage, and RAG pipelines in Claude Code projects. Provides decision matrix for choosing the right database based on scale and search type needs.

## Category notes
Belongs in integrations because it integrates third-party vector database systems (Chroma, Qdrant, Weaviate, Milvus) into Claude Code projects.

## Relationships
- Often used alongside rag-pipeline-setup (vector DB is the storage layer for RAG)
- Often used alongside supabase-prisma-database-management (alternative: pgvector extension)
- Feeds into web-scraping-pipeline (scraped content gets embedded and stored here)
- Pairs with llm-observability for monitoring query quality and latency

## Maintenance notes
Weaviate v4 client API changed significantly from v3 — verify `connect_to_local()` vs legacy `Client()` API. Chroma 0.4+ introduced PersistentClient replacing the old `.Client(Settings(...))` pattern. Qdrant's in-memory mode (":memory:") is ideal for testing but not production.
