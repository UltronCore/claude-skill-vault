# Skill Memory: Web Scraping Pipeline

## Purpose
Provides three patterns for ingesting web content into Claude Code workflows: Firecrawl for LLM-optimized markdown output, Playwright for dynamic JS-rendered pages, and Scrapy for large-scale structured crawls. Includes a complete scrape-to-RAG pipeline pattern.

## Category notes
Belongs in automation because it automates the process of collecting and transforming web content for use in Claude Code workflows and RAG pipelines.

## Relationships
- Feeds directly into rag-pipeline-setup (scraped content becomes RAG corpus)
- Feeds directly into vector-db-integration (chunks get embedded and stored)
- Complements playwright-flow-recorder (Playwright is used for both scraping and flow recording)
- Content ingested here can be monitored via llm-observability

## Maintenance notes
Firecrawl API response structure may change — verify `result["markdown"]` vs `result.get("content")` against current firecrawl-py release. Playwright's `wait_until="networkidle"` can be slow for SPAs; consider `"domcontentloaded"` for faster scraping. Scrapy requires careful robots.txt compliance and rate limiting in production use.
