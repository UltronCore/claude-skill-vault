# Web Scraping Pipeline

**Category:** automation
**Status:** active
**Version:** v1

## What it does
Builds web scraping pipelines that feed clean content into Claude Code workflows. Provides three patterns: Firecrawl for LLM-optimized markdown, Playwright for dynamic JS-rendered sites, and Scrapy for large-scale structured crawls. Includes a complete scrape-to-RAG pipeline.

## When to use
- Ingesting documentation sites into a RAG system
- Extracting structured data from web pages for Claude context
- Building a content monitoring or competitive intelligence pipeline
- Crawling product/pricing pages for analysis

## What it produces
A working scraping pipeline that outputs clean text/markdown content, ready to chunk, embed, and store in a vector database for Claude-powered semantic search.

## Related skills
- rag-pipeline-setup (next step after scraping)
- vector-db-integration (storage for scraped and chunked content)
- playwright-flow-recorder (shares Playwright dependency)
