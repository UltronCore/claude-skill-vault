# Skill Memory: RAG Pipeline Setup

## Purpose
Teaches Claude Code skills how to build RAG pipelines using Chroma (local dev), Qdrant (production), or Supabase pgvector (existing Supabase users). Covers embedding, indexing, retrieval, and context injection.

## Category notes
Belongs in orchestration — RAG orchestrates retrieval from external stores to augment Claude's context window at runtime.

## Relationships
Pairs with supabase-prisma-database-management when pgvector is the chosen vector store. llm-routing-and-fallback handles the Claude API call after retrieval.

## Maintenance notes
Voyage-3 is Anthropic's recommended embedding model (available via Anthropic API). Default to sentence-transformers for local dev (no API key needed). Chunk size 512-1024 tokens with 10% overlap is a good starting point.
