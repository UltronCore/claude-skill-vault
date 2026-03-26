# Claude Skill Vault — Master Index

_Last updated: 2026-03-25 | Total: 97 skills across 14 categories_

---

## Quick Navigation

| Category | Skills | Purpose |
|----------|--------|---------|
| [app-usage](#app-usage) | 3 | Meta-tools: Claude config, security gate, CLAUDE.md |
| [automation](#automation) | 9 | CI/CD, testing, scaffolding, DevOps |
| [business](#business) | 3 | Meetings, invoices, domain naming |
| [data-processing](#data-processing) | 2 | API contracts, env validation |
| [dev](#dev) | 2 | MCP servers, webapp testing |
| [integrations](#integrations) | 9 | Supabase, Sentry, vector DB, NotebookLM, Firecrawl |
| [marketing](#marketing) | 37 | Full marketing stack: SEO, CRO, copy, ads, growth |
| [misc](#misc) | 0 | (empty — reserved) |
| [optimization](#optimization) | 5 | Usage orchestration, LLM routing, performance |
| [orchestration](#orchestration) | 8 | Agent loops, RAG, context engineering, execution |
| [research](#research) | 1 | Content research writing |
| [review](#review) | 2 | Skill reviewer and enhancer, vault push guardian |
| [security](#security) | 6 | Auth, CSP, RLS, RBAC, security hardening |
| [ui-ux](#ui-ux) | 6 | Frontend, forms, Tailwind, shadcn/ui |
| [writing](#writing) | 3 | Doc co-authoring, internal comms, resume generation |

**Active plugins (not in vault):** superpowers (14 skills), frontend-design, claude-md-management, skill-creator, swift-lsp, postgres-best-practices, marketing-skills (33 skills)

---

## app-usage

| Skill | Description |
|-------|-------------|
| skillguard | Security gate: mandatory pre-install review for any external file/skill/script |
| claude-api-integration | Anthropic Claude API integration patterns (Python, TS, Go, structured output) |
| claude-md-improver | Audit and improve CLAUDE.md files across a repository |

## automation

| Skill | Description |
|-------|-------------|
| nextjs-fullstack-scaffold | Production-ready Next.js 16 app with Supabase, Prisma, Tailwind, testing |
| testing-next-stack | Vitest, RTL, Playwright, axe-core a11y testing for Next.js |
| github-actions-ci-workflow | GitHub Actions CI/CD pipelines with preview URLs |
| eslint-prettier-husky-config | ESLint v9 flat config, Prettier, Husky, lint-staged |
| playwright-flow-recorder | Playwright E2E test scripts from natural language flows |
| docs-and-changelogs | Changelogs from Conventional Commits, ADR, PRD scaffolding |
| feature-flag-manager | LaunchDarkly or JSON-based feature flags for Next.js |
| file-organizer | Organize files and directories intelligently |
| changelog-generator | Generate changelogs from git history and commits |

## business

| Skill | Description |
|-------|-------------|
| meeting-insights-analyzer | Extract insights, action items, decisions from meeting transcripts |
| domain-name-brainstormer | Brainstorm and evaluate domain names for products/projects |
| invoice-organizer | Organize, parse, and summarize invoices and billing data |

## data-processing

| Skill | Description |
|-------|-------------|
| api-contracts-and-zod-validation | Zod schemas and TypeScript types for forms, API routes, Server Actions |
| env-config-validator | Validate .env files across environments, check scoping |

## dev

| Skill | Description |
|-------|-------------|
| mcp-builder | Create high-quality MCP servers (Python FastMCP or Node/TS SDK) |
| webapp-testing | Playwright-based testing of local web applications |

## integrations

| Skill | Description |
|-------|-------------|
| notebooklm | Full NotebookLM API: notebooks, sources, podcasts, artifacts |
| firecrawl | Consolidated web scraping (use specific sub-skills when possible) |
| excalidraw-diagram | Create Excalidraw diagram JSON for visual documentation |
| supabase-auth-ssr-setup | Supabase Auth for Next.js App Router with SSR, middleware |
| supabase-prisma-database-management | Prisma ORM with Supabase PostgreSQL, migrations, seeds |
| sentry-and-otel-setup | Sentry error tracking + OpenTelemetry tracing for Next.js |
| llm-observability | LLM tracing with Langfuse/AgentOps/MLflow |
| vector-db-integration | Chroma, Qdrant, Weaviate vector DB for RAG systems |
| expo-skills | Expo React Native with RevenueCat, AdMob, i18n, NativeTabs |

## marketing

_37 skills — installed as marketing-skills@local plugin (auto-loads next session)_

**Foundation:**
- product-marketing-context — shared context doc all other skills read first

**SEO & Content:**
- seo-audit, ai-seo, programmatic-seo, site-architecture, schema-markup, content-strategy

**Conversion (CRO):**
- page-cro, signup-flow-cro, onboarding-cro, form-cro, popup-cro, paywall-upgrade-cro

**Copy & Email:**
- copywriting, copy-editing, email-sequence, cold-email, social-content

**Paid & Analytics:**
- ad-creative, paid-ads, ab-test-setup, analytics-tracking

**Growth & Retention:**
- referral-program, free-tool-strategy, churn-prevention, lead-magnets, launch-strategy, pricing-strategy

**Sales & GTM:**
- competitor-alternatives, sales-enablement, revops

**Strategy:**
- marketing-ideas, marketing-psychology

**ComposioHQ extras:**
- lead-research-assistant, developer-growth-analysis, competitive-ads-extractor, twitter-algorithm-optimizer

## optimization

| Skill | Description |
|-------|-------------|
| claude-usage-orchestrator | Discipline token usage, route tasks to lightest sufficient path |
| llm-routing-and-fallback | LiteLLM-based model routing with fallback and budget caps |
| performance-budget-enforcer | Lighthouse CI, bundle size monitoring, regression detection |
| revalidation-strategy-planner | Next.js ISR/SSR/SSG caching strategy advisor |
| server-actions-vs-api-optimizer | Choose between Server Actions and API routes |

## orchestration

| Skill | Description |
|-------|-------------|
| autonomous-knowledge-system | Multi-agent framework with Obsidian-style knowledge storage |
| context-engineer | Frame complex tasks before execution (auto-activates) |
| prompt-deepener | Deepen vague prompts before acting (auto-activates) |
| self-healing-execution | Ensure complete, verified execution (auto-activates) |
| system-builder | Build reusable systems, not one-off answers |
| skill-portfolio-architect | Audit and redesign the skill library |
| agent-loop-patterns | Autonomous agent loops, task queues, crew systems |
| rag-pipeline-setup | RAG pipelines with embeddings and vector search |

## research

| Skill | Description |
|-------|-------------|
| content-research-writer | Research-backed content writing with citations and iteration |

## review

| Skill | Description |
|-------|-------------|
| skill-reviewer-and-enhancer | Audit and improve existing skills against best practices |
| vault-push-guardian | Pre-push safety scan and weekly sync for Skill Vault and Project Vault |

## security

| Skill | Description |
|-------|-------------|
| auth-route-protection-checker | Audit Next.js routes for missing auth checks |
| csp-config-generator | Generate Content Security Policy headers for Next.js |
| supabase-rls-policy-generator | Row-Level Security policies for multi-tenant Supabase apps |
| role-permission-table-builder | RBAC permission matrices in markdown or SQL |
| security-hardening-checklist | Full security audit: headers, cookies, RLS, rate limiting |
| output-guardrails | Safety validation and content constraints for LLM outputs |

## ui-ux

| Skill | Description |
|-------|-------------|
| frontend-design | Production-grade frontend interfaces (also available as plugin) |
| tailwind-shadcn-ui-setup | Tailwind v4 + shadcn/ui setup for Next.js 16 |
| form-generator-rhf-zod | React Hook Form + Zod forms with shadcn/ui |
| ui-library-usage-auditor | Audit shadcn/ui usage for accessibility and consistency |
| markdown-editor-integrator | @uiw/react-md-editor integration |
| uniapp-frontend | uni-app cross-platform (WeChat, H5) with Vue 3 + TS |

## writing

| Skill | Description |
|-------|-------------|
| doc-coauthoring | Structured co-authoring workflow for docs, specs, proposals |
| internal-comms | Internal communications: status updates, newsletters, incident reports |
| tailored-resume-generator | Generate tailored resumes and cover letters |

---

_See [ROUTING-GUIDE.md](./ROUTING-GUIDE.md) for task→skill routing decisions._
_See [SOURCE-MAP.md](./SOURCE-MAP.md) for where each skill came from._
