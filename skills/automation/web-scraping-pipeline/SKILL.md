---
name: web-scraping-pipeline
description: Build web scraping pipelines that feed clean content into Claude Code workflows. Use when Claude needs to ingest web content, crawl sites for RAG, or extract structured data from pages. Trigger when users mention web scraping, Firecrawl, crawling websites, content ingestion, or extracting data from URLs.
---

# Web Scraping Pipeline

Three patterns for getting web content into Claude — from simple single-URL to full site crawls.

## Pattern 1: Firecrawl (LLM-optimized, recommended)
Firecrawl converts any URL to clean markdown — perfect for Claude context.
```python
pip install firecrawl-py

from firecrawl import FirecrawlApp

app = FirecrawlApp(api_key="fc-YOUR_KEY")

# Single page → markdown
result = app.scrape_url("https://docs.example.com/page", params={"formats": ["markdown"]})
markdown_content = result["markdown"]

# Crawl entire site
crawl_result = app.crawl_url(
    "https://docs.example.com",
    params={"limit": 50, "formats": ["markdown"]},
    poll_interval=5
)
pages = crawl_result["data"]

# Feed into Claude
for page in pages:
    # page["markdown"] is clean, ready for Claude context
    pass
```

## Pattern 2: Playwright (JavaScript-heavy sites)
```python
pip install playwright && python -m playwright install chromium

from playwright.async_api import async_playwright

async def scrape_dynamic(url: str) -> str:
    async with async_playwright() as p:
        browser = await p.chromium.launch()
        page = await browser.new_page()
        await page.goto(url, wait_until="networkidle")
        content = await page.inner_text("body")
        await browser.close()
        return content
```

## Pattern 3: Scrapy (large-scale structured crawl)
```python
pip install scrapy

import scrapy

class DocsSpider(scrapy.Spider):
    name = "docs"
    start_urls = ["https://docs.example.com"]

    def parse(self, response):
        yield {
            "url": response.url,
            "title": response.css("h1::text").get(),
            "content": " ".join(response.css("p::text").getall())
        }
        for link in response.css("a::attr(href)"):
            yield response.follow(link, self.parse)
```

## Choosing a pattern
| Need | Use |
|---|---|
| Clean markdown for Claude context | Firecrawl |
| Dynamic JS-rendered content | Playwright |
| Large-scale structured crawl | Scrapy |
| One-off URL extraction | Firecrawl single-URL |

## Pipeline: scrape → chunk → embed → retrieve
```python
# 1. Scrape
pages = firecrawl_crawl(site_url)

# 2. Chunk
chunks = [page["markdown"][:2000] for page in pages]  # simple chunking

# 3. Embed + store (see rag-pipeline-setup skill)
for chunk in chunks:
    collection.add(documents=[chunk], ids=[str(uuid4())])

# 4. Retrieve at query time
results = collection.query(query_texts=[user_question], n_results=3)
```

## Related skills
rag-pipeline-setup, playwright-flow-recorder, vector-db-integration
