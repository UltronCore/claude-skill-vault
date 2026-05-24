---
name: web-researcher
description: Web research and content extraction — search the web with full page content, scrape any URL, autonomously extract structured data from complex sites, and synthesize findings into actionable intelligence.
version: 1.0.0
---

# Web Researcher

Full web research and content extraction. Replaces: firecrawl-search, firecrawl-scrape, firecrawl-agent, firecrawl-browser, agent-fetch.

## Trigger
Any request to search the web, fetch content from a URL, scrape a site, extract information from web pages, research a company/topic/person, or gather structured data online.

## Capabilities

This skill uses Firecrawl MCP tools and web fetch to:
- **Search**: Find web content with full-page results, not just snippets
- **Scrape**: Extract clean markdown from any URL
- **Crawl**: Map and extract from entire websites or sections
- **Agent**: Autonomously browse and extract complex multi-step data
- **Browser**: Interact with JS-heavy sites that require execution

## Tool Selection

| Need | Tool | When |
|------|------|-------|
| Find pages on a topic | `firecrawl_search` | Research queries, competitive intel |
| Get content from 1 URL | `firecrawl_scrape` | Articles, product pages, docs |
| Explore a whole site | `firecrawl_map` + `firecrawl_scrape` | Full site extraction |
| Complex multi-page task | `firecrawl_agent` | Navigating paginated results, forms |
| JS-heavy / auth-required | `firecrawl_browser_*` | SPAs, login-required content |
| Simple public URL | `WebFetch` | Fast single-page, no JS needed |

## Research Workflows

### Company Research
1. Search: `[Company name] overview site:crunchbase.com OR linkedin.com`
2. Scrape: Company website → /about, /pricing, /blog
3. Search: `[Company name] funding OR press OR review`
4. Synthesize: Founded, team size, product, pricing, positioning, traction

### Competitive Analysis
1. Identify competitors: Search "[product category] alternatives" or "[our product] competitors"
2. For each competitor: Scrape homepage, pricing page, features page
3. Extract: positioning, key features, pricing tiers, target customer
4. Produce: comparison table + positioning gaps

### Market Research
1. Search industry reports, analyst coverage, news
2. Scrape relevant articles for data points
3. Search Reddit/forums for unfiltered customer opinions
4. Synthesize: market size, trends, key players, customer pain points

### Person Research
1. Search: "[Name] site:linkedin.com"
2. Search: "[Name] interview OR podcast OR talk"
3. Search: "[Name] company" to find current role
4. Synthesize: background, expertise, recent work, contact info

### Content Research
1. Search: "[Topic] guide OR tutorial OR best practices"
2. Scrape top 3-5 results for structure and depth
3. Identify: what's covered, what's missing, best formats
4. Produce: content brief with outline, key points, differentiation

## Output Formats

### Research Brief
```
## [Topic] Research Brief

**Summary**: [2-3 sentence overview]

**Key Findings**:
- [Finding 1 with source]
- [Finding 2 with source]
- [Finding 3 with source]

**Data Points**:
| Metric | Value | Source |
|--------|-------|--------|
| ...    | ...   | ...    |

**Implications**: [So what? → Actionable takeaways]
```

### Competitive Overview
```
## Competitive Landscape: [Space]

| Company | Positioning | Key Features | Pricing | Weakness |
|---------|-------------|--------------|---------|---------|
| ...     | ...         | ...          | ...     | ...     |

**Market gaps**: [What nobody is doing well]
**Our edge**: [Where we win]
```

## Synthesis Principles

1. **Primary sources over summaries**: Get the original page, not a cached summary
2. **Triangulate**: Cross-check findings across 2-3 sources before stating as fact
3. **Cite everything**: Every claim → source URL
4. **Flag uncertainty**: "Appears to be" vs "Confirmed:" for unverified data
5. **Actionable output**: End every research task with "So what?" implications

## Firecrawl Usage Notes

- `firecrawl_search`: Returns full page content, not just snippets — use for rich research
- `firecrawl_scrape`: Returns markdown; use `formats: ["markdown"]` for clean text
- `firecrawl_agent`: Best for: "find all pricing info on this site" type tasks
- `firecrawl_map`: Returns all URLs — combine with selective scraping for efficiency
- For authenticated content: Use `firecrawl_browser_create` → `firecrawl_browser_execute`

## Autonomous Research Behavior

When given a research goal, proceed autonomously:
1. Formulate 3-5 search queries covering different angles
2. Scrape most relevant results
3. Identify gaps and run follow-up searches
4. Synthesize into structured output
5. Flag what couldn't be verified and what sources to check manually

Do not ask for permission between steps. Deliver a complete research package.

## GitNexus Index
This skill is indexed by GitNexus for knowledge graph traversal.
Index path: /Users/localuser/claude-skill-vault/skills/research/web-researcher/.gitnexus
Last indexed: 2026-05-23
