# Skill Routing Guide

_How to choose the right skill for common task types. Lighter skills preferred over heavier ones._

---

## Web & Research Tasks

| Task | Best Skill | Why |
|------|-----------|-----|
| Search the web | `firecrawl-search` | Returns full page content, not just snippets |
| Scrape a URL | `firecrawl-scrape` | Handles JS-rendered pages |
| Crawl a whole site | `firecrawl-crawl` | Bulk extraction with depth/path filters |
| Find URLs on a site | `firecrawl-map` | URL discovery before scraping |
| Download site locally | `firecrawl-download` | Saves as organized local markdown files |
| Extract structured JSON from site | `firecrawl-agent` | AI-powered extraction with schema |
| Research + write article | `content-research-writer` | Research + citations + iterative writing |
| Create a podcast/study guide | `notebooklm` | Google NotebookLM API |

## Development Tasks

| Task | Best Skill | Why |
|------|-----------|-----|
| Build MCP server | `mcp-builder` | MCP-specific design patterns |
| Test a local web app | `webapp-testing` | Playwright against localhost |
| Scaffold Next.js app | `nextjs-fullstack-scaffold` | Production-ready full stack |
| Set up testing | `testing-next-stack` | Vitest + RTL + Playwright + a11y |
| Configure CI/CD | `github-actions-ci-workflow` | GitHub Actions best practices |
| Set up linting | `eslint-prettier-husky-config` | ESLint v9 flat config |
| Claude API integration | `claude-api-integration` | SDK patterns, structured output |
| Build with Claude API | `claude-api` (plugin) | API usage + SDK code generation |

## Database & Backend

| Task | Best Skill | Why |
|------|-----------|-----|
| Supabase auth + SSR | `supabase-auth-ssr-setup` | Next.js App Router auth patterns |
| Database migrations | `supabase-prisma-database-management` | Prisma + Supabase workflow |
| RLS policies | `supabase-rls-policy-generator` | Multi-tenant RLS patterns |
| Postgres optimization | `postgres-best-practices` (plugin) | Supabase-endorsed patterns |
| API validation | `api-contracts-and-zod-validation` | Zod + TypeScript end-to-end |

## Security

| Task | Best Skill | Why |
|------|-----------|-----|
| Full security audit | `security-hardening-checklist` | Covers all layers |
| Auth route audit | `auth-route-protection-checker` | Route-specific checks |
| CSP headers | `csp-config-generator` | Next.js CSP configuration |
| RBAC design | `role-permission-table-builder` | Permission matrix generation |
| Output safety | `output-guardrails` | Content constraints for LLM outputs |

## Marketing Tasks

| Task | Best Skill | Why |
|------|-----------|-----|
| First task in new project | `product-marketing-context` | Creates shared context all other skills read |
| Write landing page copy | `copywriting` | Structured marketing copy workflow |
| Edit existing copy | `copy-editing` | Review + improve existing content |
| SEO audit | `seo-audit` | Technical + on-page SEO analysis |
| Optimize for AI search | `ai-seo` | LLM citation optimization |
| CRO for any page | `page-cro` | Conversion optimization framework |
| Improve signup flow | `signup-flow-cro` | Signup/registration specific patterns |
| Email drip campaign | `email-sequence` | Lifecycle email flows |
| B2B cold outreach | `cold-email` | Reply-optimized cold email |
| Social media content | `social-content` | Platform-specific content |
| Paid advertising | `paid-ads` | Google, Meta, LinkedIn campaigns |
| A/B test setup | `ab-test-setup` | Experiment design + implementation |
| Analytics setup | `analytics-tracking` | Measurement and tracking systems |
| Product launch | `launch-strategy` | Launch planning + execution |
| Pricing decisions | `pricing-strategy` | Packaging and monetization |
| Marketing ideas | `marketing-ideas` | Ideation for SaaS/software |
| Psychology-driven copy | `marketing-psychology` | Behavioral science in marketing |
| Competitor pages | `competitor-alternatives` | SEO competitor comparison pages |
| Sales enablement | `sales-enablement` | Pitch decks, one-pagers, objection handling |

## Writing & Documentation

| Task | Best Skill | Why |
|------|-----------|-----|
| Co-author a doc/spec | `doc-coauthoring` | Structured 3-stage writing workflow |
| Internal updates/newsletters | `internal-comms` | Business communication templates |
| Research-backed article | `content-research-writer` | Research + citations + hooks |
| Changelog generation | `docs-and-changelogs` | Conventional Commits → CHANGELOG.md |
| Tailored resume | `tailored-resume-generator` | Job-specific resume writing |

## Planning & Execution (Superpowers)

| Task | Best Skill | Why |
|------|-----------|-----|
| Any creative/feature work | `superpowers:brainstorming` | Explore intent before coding |
| Multi-step task plan | `superpowers:writing-plans` | Spec → implementation plan |
| Execute a plan | `superpowers:executing-plans` | Plan → verified execution |
| Debug a bug | `superpowers:systematic-debugging` | Root cause before fixes |
| Parallel workstreams | `superpowers:dispatching-parallel-agents` | Independent tasks in parallel |
| Code review | `superpowers:requesting-code-review` | Post-implementation review |
| Before claiming done | `superpowers:verification-before-completion` | Evidence before assertions |

## Visualization & Design

| Task | Best Skill | Why |
|------|-----------|-----|
| Architecture/workflow diagram | `excalidraw-diagram` | Visual Excalidraw JSON |
| Web component/page | `frontend-design` (plugin) | Production-grade UI |
| UI audit | `ui-library-usage-auditor` | shadcn/ui compliance |

## Meta / System

| Task | Best Skill | Why |
|------|-----------|-----|
| New skill creation | `skill-creator` (plugin) | Full skill creation workflow |
| Skill library audit | `skill-portfolio-architect` | Portfolio cleanup and rationalization |
| Improve an existing skill | `skill-reviewer-and-enhancer` | Quality improvement workflow |
| CLAUDE.md improvement | `claude-md-management:claude-md-improver` (plugin) | CLAUDE.md audit |
| Business meeting notes | `meeting-insights-analyzer` | Action items + decisions extraction |

---

## Token Efficiency Rules

1. **Prefer specific over general**: Use `firecrawl-search` not `firecrawl` when you know you need search.
2. **One context doc, not repetition**: Run `product-marketing-context` once per project, then all other marketing skills read it.
3. **Superpowers for process, domain skills for content**: Superpowers handles the HOW; domain skills handle the WHAT.
4. **claude-usage-orchestrator** advises when to use lighter paths — consult it for long autonomous runs.
5. **notebooklm only for multi-format output**: Don't use it when firecrawl-search or content-research-writer suffice.
