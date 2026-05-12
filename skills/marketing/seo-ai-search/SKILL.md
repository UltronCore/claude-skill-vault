---
name: seo-ai-search
description: SEO and AI search optimization — technical audits, content strategy for Google and LLM citation, programmatic page generation, and site architecture planning.
version: 1.0.0
---

# SEO & AI Search

Full-stack SEO and AI search optimization. Replaces: ai-seo, seo-audit, programmatic-seo, site-architecture.

## Trigger
SEO, search rankings, AI citations, site structure, organic traffic, LLM discovery, content clusters, technical SEO, keyword strategy.

## Technical SEO Audit

### Core Vitals Checklist
**Crawlability**
- [ ] robots.txt configured correctly (no accidental blocks)
- [ ] Sitemap.xml present, submitted to GSC/Bing
- [ ] No orphan pages (all pages linked from somewhere)
- [ ] Canonical tags correct (no self-referencing canonicals on paginated pages)
- [ ] No duplicate content (parameter handling, www vs non-www, http vs https)

**Indexability**
- [ ] Noindex not on pages that should rank
- [ ] Hreflang correct for multi-language
- [ ] Structured data (schema.org) on key page types
- [ ] Open Graph + Twitter Card meta tags

**Page Speed (Core Web Vitals)**
- LCP < 2.5s (Largest Contentful Paint)
- INP < 200ms (Interaction to Next Paint)
- CLS < 0.1 (Cumulative Layout Shift)
- TTFB < 600ms

**Architecture**
- [ ] URL structure: flat hierarchy (max 3 levels deep)
- [ ] Internal linking: hub pages link to cluster content
- [ ] Breadcrumbs on all interior pages
- [ ] Pagination handled (rel=prev/next or canonical to page 1)

### Common Technical Issues → Fixes
| Issue | Fix |
|-------|-----|
| Slow LCP | Preload hero image, move to CDN, lazy-load below fold |
| High CLS | Reserve image dimensions, avoid injected content above fold |
| Crawl budget waste | Block parameter URLs in robots.txt, consolidate thin pages |
| Duplicate content | 301 redirect to canonical, add canonical tag |
| Missing schema | Add FAQ, Article, Product, or HowTo schema to key pages |

## Keyword & Content Strategy

### Keyword Research Framework
1. **Seed keywords**: Core topic terms (3-5 words describing your product/service)
2. **Expand by intent**:
   - Informational: "how to X", "what is X", "X explained"
   - Commercial: "best X", "X alternatives", "X vs Y", "X pricing"
   - Transactional: "buy X", "X free trial", "X software"
3. **Prioritize by**: Volume × Relevance ÷ Difficulty

### Content Cluster Model
```
Pillar Page (broad topic, 2,000+ words)
├── Cluster Page 1 (subtopic A)
├── Cluster Page 2 (subtopic B)
├── Cluster Page 3 (subtopic C)
└── Cluster Page 4 (subtopic D)
```
- Pillar links to all clusters
- Each cluster links back to pillar
- Clusters link to each other when relevant

### On-Page Optimization Checklist
- [ ] Target keyword in title tag (front-loaded)
- [ ] Title tag 50-60 chars
- [ ] Meta description 150-160 chars, includes keyword + CTA
- [ ] H1 includes primary keyword (once only)
- [ ] H2s include secondary keywords naturally
- [ ] First 100 words include primary keyword
- [ ] Images: descriptive alt text, compressed
- [ ] Internal links: 3-5 to relevant pages
- [ ] External links: 1-2 to authoritative sources
- [ ] URL: short, hyphenated, includes keyword

## Programmatic SEO

### When to Use Programmatic SEO
- You have structured data that maps to user search queries
- Each variation has genuine unique value (not thin content)
- Target: 100+ pages with similar template but different data

### Page Templates That Work
- Location pages: "[Service] in [City]"
- Comparison pages: "[Brand A] vs [Brand B]"
- Category pages: "Best [Product Type] for [Use Case]"
- Listicles: "Top [X] [Category] in [Year]"
- Integration pages: "[Your Tool] + [Integration] integration"
- Glossary/definition pages: "[Term] definition and examples"

### Programmatic SEO Quality Controls
**Never generate**: Pages with <300 words of unique content
**Always include**:
- Unique intro paragraph with location/entity-specific data
- Dynamic content pulled from real data (reviews, stats, pricing)
- Local signals for location pages (address, hours, map embed)
- FAQ section with entity-specific questions

### Technical Implementation
```
Template: /blog/[competitor]-alternative
Data source: competitors table with name, strengths, weaknesses, pricing
Unique content blocks:
  - Intro: Why people look for [competitor] alternatives
  - Comparison table: dynamic from data
  - Your positioning vs this specific competitor
  - FAQ: competitor-specific questions
```

## Site Architecture

### Information Architecture Principles
- **Flat structure**: Max 3 clicks from homepage to any content
- **Logical grouping**: Related content in same directory
- **Descriptive URLs**: /blog/email-marketing-tips vs /blog/post-1234
- **Navigation reflects priority**: Most important pages in main nav

### Recommended URL Structure
```
/ (homepage)
/features/ (or /product/)
/pricing/
/blog/ (or /resources/)
  /blog/[category]/[slug]
/[use-case]/ (solution pages)
/[competitor]-alternative/ (comparison pages)
/integrations/ 
  /integrations/[tool-name]/
/customers/ (or /case-studies/)
/about/
/contact/
```

### Internal Linking Strategy
- Every new page: 3-5 internal links from existing content
- Hub pages (pillar, homepage): Link to all key sub-pages
- Blog posts: Link to relevant product/feature pages
- Run quarterly: find orphan pages, add internal links

## AI Search Optimization (LLM Citation)

### How LLMs Discover and Cite Content
LLMs (ChatGPT, Claude, Perplexity) pull from:
1. Training data (crawled web content, pre-cutoff)
2. Real-time search (Perplexity, SearchGPT, Claude with web access)
3. Bing index (many AI search products use Bing)

### AI Citation Optimization Framework

**1. Establish Topical Authority**
- Create comprehensive, definitive content on your core topics
- Cover topics more thoroughly than competitors
- Use the hub-and-spoke model (pillar + clusters)

**2. Be Citable**
- Include quotable statistics and data points
- Write clear definitions for industry terms
- Create opinionated frameworks with your name attached
- Structure content with clear headings LLMs can extract

**3. Structured Content Signals**
- Use FAQ schema (LLMs love Q&A format)
- Numbered lists and step-by-step guides cite cleanly
- Tables with clear headers extract well
- "The X Framework" / "The X Method" naming builds citations

**4. Authority Signals**
- Earn backlinks from authoritative sites in your niche
- Get mentioned on podcasts, in newsletters, at conferences
- Create original research/data (most cited content type)
- Wikipedia-style factual coverage of your space

**5. Direct LLM Visibility**
- Include structured data that helps LLMs understand entity relationships
- Build a Wikipedia page if applicable (entity recognition)
- Maintain consistent NAP (Name, Address, Phone) for local businesses
- Get listed in industry directories and roundup posts

### AI Search Content Checklist
- [ ] Defines key terms clearly (LLMs pull definitions)
- [ ] Contains specific statistics with sources
- [ ] Has a clear "what is X" section
- [ ] FAQ section with exact user questions
- [ ] Named framework or methodology
- [ ] Author bio with credentials
- [ ] Original data or survey results (highest citation rate)

## Link Building Strategy

### Link Types by Value
1. **Editorial links**: Earned by creating citable content (highest value)
2. **Digital PR**: Newsjacking, research, expert commentary
3. **Guest posts**: Strategic placements on relevant publications
4. **Partnerships**: Integrations, co-marketing, resource links
5. **Broken link building**: Replace dead links on relevant pages

### Link Velocity
- New sites: 5-10 links/month (natural growth)
- Established sites: 20-50 links/month
- Never: Sudden spike of 500 links overnight (penalty risk)

## Reporting & Metrics

### Monthly SEO Dashboard
- Organic sessions (MoM, YoY)
- Keyword rankings (tracked set — leaders, movers, new)
- Impressions + CTR (GSC)
- Backlinks acquired (new vs lost)
- Core Web Vitals (all green?)
- Conversion from organic (goal completions)

### Output Format
For audits: Issue → Impact → Fix → Priority (High/Med/Low)
For strategy: Keyword cluster → content plan → timeline
For programmatic: Template spec → data requirements → quality checklist
