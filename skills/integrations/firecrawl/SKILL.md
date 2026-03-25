---
name: firecrawl
description: |
  Web scraping, search, crawling, and page interaction via the Firecrawl CLI. Use this skill whenever the user wants to search the web, find articles, research a topic, look something up online, scrape a webpage, grab content from a URL, extract data from a website, crawl documentation, download a site, extract structured JSON from sites, or interact with pages that need clicks or logins. Also use when they say "fetch this page", "pull the content from", "get the page at https://", or reference scraping external websites. This provides real-time web search with full page content extraction and interact capabilities — beyond what Claude can do natively with built-in tools. Do NOT trigger for local file operations, git commands, deployments, or code editing tasks.
allowed-tools:
  - Bash(firecrawl *)
  - Bash(npx firecrawl *)
---

# Firecrawl CLI

Web scraping, search, and page interaction CLI. Returns clean markdown optimized for LLM context windows.

Run `firecrawl --help` or `firecrawl <command> --help` for full option details.

## Prerequisites

Must be installed and authenticated. Check with `firecrawl --status`.

```
  🔥 firecrawl cli v1.8.0

  ● Authenticated via FIRECRAWL_API_KEY
  Concurrency: 0/100 jobs (parallel scrape limit)
  Credits: 500,000 remaining
```

## Workflow

Follow this escalation pattern:

1. **Search** - No specific URL yet. Find pages, answer questions, discover sources.
2. **Scrape** - Have a URL. Extract its content directly.
3. **Map + Scrape** - Large site or need a specific subpage. Use `map --search` to find the right URL, then scrape it.
4. **Crawl** - Need bulk content from an entire site section (e.g., all /docs/).
5. **Interact** - Scrape first, then interact with the page (pagination, modals, form submissions, multi-step navigation).

| Need                        | Command               | When                                                      |
| --------------------------- | --------------------- | --------------------------------------------------------- |
| Find pages on a topic       | `search`              | No specific URL yet                                       |
| Get a page's content        | `scrape`              | Have a URL, page is static or JS-rendered                 |
| Find URLs within a site     | `map`                 | Need to locate a specific subpage                         |
| Bulk extract a site section | `crawl`               | Need many pages (e.g., all /docs/)                        |
| AI-powered data extraction  | `agent`               | Need structured data from complex sites                   |
| Interact with a page        | `scrape` + `interact` | Content requires clicks, form fills, pagination, or login |
| Download a site to files    | `download`            | Save an entire site as local files                        |

**Scrape vs interact:** Use `scrape` first — it handles static pages and JS-rendered SPAs. Only escalate to `interact` when you need clicks, form fills, or pagination.

**Avoid redundant fetches:** `search --scrape` already fetches full page content. Don't re-scrape those URLs. Check `.firecrawl/` for existing data before fetching again.

## Output & Organization

Unless the user specifies to return in context, write results to `.firecrawl/` with `-o`. Add `.firecrawl/` to `.gitignore`. Always quote URLs — shell interprets `?` and `&` as special characters.

```bash
firecrawl search "react hooks" -o .firecrawl/search-react-hooks.json --json
firecrawl scrape "<url>" -o .firecrawl/page.md
```

Naming conventions: `.firecrawl/search-{query}.json` · `.firecrawl/{site}-{path}.md`

Never read entire output files at once. Use `grep`, `head`, or incremental reads:

```bash
wc -l .firecrawl/file.md && head -50 .firecrawl/file.md
grep -n "keyword" .firecrawl/file.md
jq -r '.data.web[].url' .firecrawl/search.json   # Extract URLs
```

---

## Command Reference

### search

Web search with optional content scraping. Returns search results as JSON, optionally with full page content.

```bash
firecrawl search "your query" -o .firecrawl/result.json --json
firecrawl search "your query" --scrape -o .firecrawl/scraped.json --json
firecrawl search "your query" --sources news --tbs qdr:d -o .firecrawl/news.json --json
```

| Option                               | Description                                   |
| ------------------------------------ | --------------------------------------------- |
| `--limit <n>`                        | Max number of results                         |
| `--sources <web,images,news>`        | Source types to search                        |
| `--categories <github,research,pdf>` | Filter by category                            |
| `--tbs <qdr:h\|d\|w\|m\|y>`          | Time-based search filter                      |
| `--scrape`                           | Also scrape full page content for each result |
| `-o, --output <path>`                | Output file path                              |

**Tip:** `--scrape` fetches full content — don't re-scrape those URLs afterward.

---

### scrape

Extract clean markdown from one or more URLs. Handles static pages and JS-rendered SPAs. Multiple URLs scraped concurrently.

```bash
firecrawl scrape "<url>" -o .firecrawl/page.md
firecrawl scrape "<url>" --only-main-content -o .firecrawl/page.md
firecrawl scrape "<url>" --wait-for 3000 -o .firecrawl/page.md
firecrawl scrape https://example.com/a https://example.com/b    # concurrent
firecrawl scrape "<url>" --query "What is the enterprise plan price?"
```

| Option                   | Description                                                      |
| ------------------------ | ---------------------------------------------------------------- |
| `-f, --format <formats>` | Output formats: markdown, html, rawHtml, links, screenshot, json |
| `-Q, --query <prompt>`   | Ask a question about the page content (5 credits)                |
| `--only-main-content`    | Strip nav, footer, sidebar                                       |
| `--wait-for <ms>`        | Wait for JS rendering before scraping                            |
| `--include-tags <tags>`  | Only include these HTML tags                                     |
| `--exclude-tags <tags>`  | Exclude these HTML tags                                          |
| `-o, --output <path>`    | Output file path                                                 |

**Tip:** Prefer scraping to file over `--query` — you can search the full content yourself. Use `--query` only for a single targeted answer.

---

### map

Discover URLs on a site. Use `--search` to locate a specific page within a large site.

```bash
firecrawl map "<url>" --search "authentication" -o .firecrawl/filtered.txt
firecrawl map "<url>" --limit 500 --json -o .firecrawl/urls.json
```

| Option                            | Description                  |
| --------------------------------- | ---------------------------- |
| `--limit <n>`                     | Max number of URLs to return |
| `--search <query>`                | Filter URLs by search query  |
| `--sitemap <include\|skip\|only>` | Sitemap handling strategy    |
| `--include-subdomains`            | Include subdomain URLs       |
| `--json`                          | Output as JSON               |
| `-o, --output <path>`             | Output file path             |

**Pattern:** `map --search` to find the right URL → `scrape` that URL.

---

### crawl

Bulk extract content from a website. Crawls pages following links up to a depth/limit.

```bash
firecrawl crawl "<url>" --include-paths /docs --limit 50 --wait -o .firecrawl/crawl.json
firecrawl crawl "<url>" --max-depth 3 --wait --progress -o .firecrawl/crawl.json
firecrawl crawl <job-id>   # check status of running crawl
```

| Option                    | Description                                 |
| ------------------------- | ------------------------------------------- |
| `--wait`                  | Wait for crawl to complete before returning |
| `--progress`              | Show progress while waiting                 |
| `--limit <n>`             | Max pages to crawl                          |
| `--max-depth <n>`         | Max link depth to follow                    |
| `--include-paths <paths>` | Only crawl URLs matching these paths        |
| `--exclude-paths <paths>` | Skip URLs matching these paths              |
| `--delay <ms>`            | Delay between requests                      |
| `-o, --output <path>`     | Output file path                            |

**Tip:** Always use `--wait` for immediate results. Use `--include-paths` to scope the crawl — don't crawl an entire site when you only need one section.

---

### agent

AI-powered autonomous extraction. Navigates sites and returns structured data (takes 2–5 minutes).

```bash
firecrawl agent "extract all pricing tiers" --wait -o .firecrawl/pricing.json
firecrawl agent "extract products" --schema '{"type":"object","properties":{"name":{"type":"string"},"price":{"type":"number"}}}' --wait -o .firecrawl/products.json
firecrawl agent "get feature list" --urls "<url>" --wait -o .firecrawl/features.json
```

| Option                 | Description                               |
| ---------------------- | ----------------------------------------- |
| `--urls <urls>`        | Starting URLs for the agent               |
| `--model <model>`      | Model to use: spark-1-mini or spark-1-pro |
| `--schema <json>`      | JSON schema for structured output         |
| `--schema-file <path>` | Path to JSON schema file                  |
| `--max-credits <n>`    | Credit limit for this agent run           |
| `--wait`               | Wait for agent to complete                |
| `-o, --output <path>`  | Output file path                          |

**Tip:** Use `--schema` for predictable output. Use `--max-credits` to cap spending. For simple single-page extraction, prefer `scrape`.

---

### download

Convenience command combining `map` + `scrape` to save an entire site as local files. Experimental.

```bash
firecrawl download https://docs.example.com --screenshot --limit 20 -y
firecrawl download https://docs.example.com --include-paths "/features,/sdks" -y
firecrawl download https://docs.example.com --exclude-paths "/zh,/ja,/fr" --only-main-content -y
```

Always pass `-y` to skip the confirmation prompt in automated flows. All `scrape` options work with `download`.

---

## Parallelization

Run independent operations in parallel up to the concurrency limit (`firecrawl --status`):

```bash
firecrawl scrape "<url-1>" -o .firecrawl/1.md &
firecrawl scrape "<url-2>" -o .firecrawl/2.md &
firecrawl scrape "<url-3>" -o .firecrawl/3.md &
wait
```

## Credit Usage

```bash
firecrawl credit-usage
firecrawl credit-usage --json --pretty -o .firecrawl/credits.json
```
