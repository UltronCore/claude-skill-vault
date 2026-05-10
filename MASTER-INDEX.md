# Claude Skill Vault — Master Index

_Last updated: 2026-05-10 | Total: 239 skills across 22 categories (+50 added 2026-05-10)_

---

## Quick Navigation

| Category | Skills | Purpose |
|----------|--------|---------|
| [ai-ml](#ai-ml) | 30 | LLM fine-tuning, HuggingFace, RAG, Ollama, Claude tools, streaming, vision |
| [app-usage](#app-usage) | 9 | Claude config, Obsidian, Raycast, AppleScript, Keyboard Maestro |
| [automation](#automation) | 24 | CI/CD, testing, scaffolding, Prisma, Zapier/Make, FFmpeg, Cursor |
| [business](#business) | 7 | Meetings, invoices, e-commerce, Shopify, Stripe, Resend email |
| [cloud-devops](#cloud-devops) | 13 | Docker, K8s, Terraform, Cloudflare, Vercel, Fly.io, PocketBase |
| [compliance](#compliance) | 5 | GDPR, SOC2, ISO27001, risk management, pen testing |
| [data-engineering](#data-engineering) | 11 | Polars, SQL, GraphQL, Drizzle ORM, WebSocket, realtime |
| [data-processing](#data-processing) | 3 | API contracts, env validation, Zod expert |
| [engineering-practices](#engineering-practices) | 13 | API design, profiling, monorepo, migration, FastAPI, Bun |
| [integrations](#integrations) | 14 | Supabase, Sentry, vector DB, NotebookLM, Firecrawl, Gmail, Linear |
| [ios-swift](#ios-swift) | 15 | SwiftUI, StoreKit, SwiftData, WidgetKit, macros, SPM, Xcode Cloud |
| [marketing](#marketing) | 37 | Full marketing stack: SEO, CRO, copy, ads, growth |
| [optimization](#optimization) | 6 | Usage orchestration, LLM routing, Core Web Vitals |
| [orchestration](#orchestration) | 8 | Agent loops, RAG, context engineering, execution |
| [product-business](#product-business) | 8 | CTO/CEO advisor, product strategy, competitive teardown |
| [research](#research) | 1 | Content research writing |
| [review](#review) | 2 | Skill reviewer and enhancer, vault push guardian |
| [security](#security) | 18 | Auth, CSP, RLS, RBAC, hardening, semgrep, API security |
| [ui-ux](#ui-ux) | 15 | TypeScript, TanStack Query, tRPC, Framer Motion, a11y, Storybook |
| [writing](#writing) | 6 | Doc co-authoring, internal comms, resume, blog, technical docs |
| [misc](#misc) | 0 | (empty — reserved) |
| [workflow](#workflow) | — | Workflow automation patterns |

**Active plugins (not in vault):** superpowers (14 skills), frontend-design, claude-md-management, skill-creator, swift-lsp, postgres-best-practices, marketing-skills (33 skills)

---

## ai-ml

_30 skills — AI/ML development, fine-tuning, HuggingFace ecosystem, RAG, Ollama local LLMs, Claude tool use, streaming, vision, cost optimization_

| Skill | Description |
|-------|-------------|
| huggingface-llm-trainer | Fine-tune LLMs using TRL: SFT, DPO, GRPO, reward modeling, GGUF export |
| huggingface-datasets | Explore, query, and extract data from any HuggingFace dataset |
| huggingface-local-models | Select and run models locally with llama.cpp and GGUF formats |
| hf-cli | Execute HuggingFace Hub operations: download/upload models, datasets, spaces |
| huggingface-gradio | Build Gradio web UIs and interactive ML demos in Python |
| transformers-js | Run state-of-the-art ML models in JavaScript/TypeScript with WebGPU/WASM |
| train-sentence-transformers | Fine-tune sentence embedding and reranking models |
| unsloth | 2-5x faster LLM fine-tuning with 50-80% less memory using Unsloth |
| peft-fine-tuning | Parameter-efficient fine-tuning: LoRA, QLoRA, 25+ methods for large models |
| langchain | Build LLM apps with agents, chains, RAG; 500+ integrations, memory, tools |
| langgraph | Production-grade stateful multi-actor AI apps with graph construction |
| crewai | Multi-agent orchestration: role-based collaboration, sequential/hierarchical |
| dspy | Declarative AI programming: auto-optimize prompts, modular RAG, agents |
| instructor | Extract structured Pydantic-validated data from LLM responses |
| chroma | Open-source embedding database: vector + full-text search, metadata filter |
| qdrant | High-performance Qdrant vector search engine for production RAG |
| pinecone | Managed Pinecone vector database: auto-scaling, hybrid search |
| faiss | Facebook FAISS similarity search: billions of vectors, GPU acceleration |
| llm-prompt-optimizer | Improve prompts for any LLM using proven engineering techniques |
| llm-evaluation | Comprehensive LLM evaluation: automated metrics, human eval, A/B testing |
| ollama-integration | Local LLM deployment: Ollama CLI, REST API, Python/JS libraries, Modelfiles |
| claude-tool-use | Advanced Claude tool/function calling: parallel tools, agentic loops, tool choice |
| llm-streaming | Streaming LLM responses: SSE, Next.js Route Handlers, React streaming UI |
| multimodal-ai | Vision and multimodal AI: Claude image API, PDF analysis, manga OCR |
| ai-cost-optimizer | LLM cost reduction: prompt caching, batch API, model routing, token budgets |
| embeddings-expert | Text embeddings: semantic search, cosine similarity, chunking, hybrid RAG |
| openrouter-litellm | Multi-provider LLM routing with OpenRouter and LiteLLM; fallback strategies |
| prompt-versioning | Prompt management: YAML versioning, A/B testing, eval tracking, Langfuse |
| computer-vision | PIL/Pillow, OpenCV, OCR (Tesseract/EasyOCR), YOLO, manga panel detection |
| vector-rag-advanced | Advanced RAG: chunking, pgvector, hybrid search, reranking, HyDE, RAGAS eval |

## app-usage

| Skill | Description |
|-------|-------------|
| skillguard | Security gate: mandatory pre-install review for any external file/skill/script |
| claude-api-integration | Anthropic Claude API integration patterns (Python, TS, Go, structured output) |
| claude-md-improver | Audit and improve CLAUDE.md files across a repository |
| agents-md-creator | Create and maintain concise AGENTS.md / CLAUDE.md reference files |
| claude-settings-audit | Generate recommended Claude Code settings.json permissions |
| obsidian-automation | Obsidian vault automation: Templater, Dataview, QuickAdd, MCP integration |
| raycast-extensions | Build Raycast extensions: List/Form/Detail commands, Preferences API, actions |
| applescript-jxa | macOS automation with AppleScript and JavaScript for Automation (JXA) |
| keyboard-maestro | Keyboard Maestro macros via kmtrigger, KMVAR_, osascript; common patterns |

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
| vercel-deploy | Deploy applications to Vercel instantly from conversations |
| remotion-video-builder | Build programmatic videos with React and Remotion: animations, audio, 3D |
| prisma-patterns | Prisma ORM: schema design, relations, transactions, pagination, Supabase |
| zapier-make | Zapier and Make.com automation: webhooks, data mapping, loops, error handling |
| ffmpeg-media | FFmpeg video/audio: transcoding (H.264/265/AV1), HLS, thumbnails, batch |
| cursor-expert | Cursor AI IDE: .cursorrules, Composer, Agent mode, @Codebase context |

## business

| Skill | Description |
|-------|-------------|
| meeting-insights-analyzer | Extract insights, action items, decisions from meeting transcripts |
| domain-name-brainstormer | Brainstorm and evaluate domain names for products/projects |
| invoice-organizer | Organize, parse, and summarize invoices and billing data |
| ecommerce-patterns | E-commerce: cart state (Zustand), checkout flow, inventory, orders, pagination |
| shopify-integration | Shopify Storefront + Admin API, headless Next.js, cart mutations, webhooks |
| stripe-expert | Stripe: Checkout Sessions, Payment Intents, subscriptions, webhooks, CLI |
| resend-email | Resend + React Email: order/welcome/reset templates, batch send, webhooks |

## cloud-devops

_13 skills — Docker, Kubernetes, Terraform, Cloudflare, Vercel, Fly.io, PocketBase_

| Skill | Description |
|-------|-------------|
| docker-expert | Advanced Docker: multi-stage builds, security hardening, production orchestration |
| kubernetes-architect | Expert Kubernetes: cloud-native, GitOps with ArgoCD/Flux, enterprise patterns |
| k8s-manifest-generator | Generate production-ready Kubernetes manifests: Deployments, Services, PVCs |
| terraform-code-generation | Write Terraform HCL: modules, providers, tests, CI/CD integration |
| aws-solution-architect | AWS architecture: services, patterns, cost optimization, Well-Architected |
| azure-cloud-architect | Azure architecture, Azure DevOps, cloud-native patterns |
| senior-devops | DevOps engineering: CI/CD, monitoring, infrastructure, SRE practices |
| observability-engineer | Build monitoring, logging, tracing systems: SLI/SLO, incident response |
| cloudflare-expert | Cloudflare Workers, D1 (SQLite), R2 storage, KV, Pages Functions, Durable Objects |
| vercel-advanced | Vercel ISR/PPR, unstable_cache, Edge Runtime, middleware, Speed Insights |
| github-actions-advanced | Matrix builds, reusable workflows, OIDC auth, artifact passing, deploy pipelines |
| pocketbase | PocketBase self-hosted backend: CRUD, auth, realtime, file storage, Fly.io deploy |
| flyio-deploy | Fly.io: fly.toml, secrets, volumes, Postgres, scaling, multi-region, health checks |

## compliance

_5 skills — Regulatory compliance, security frameworks, risk management_

| Skill | Description |
|-------|-------------|
| gdpr-expert | GDPR/DSGVO compliance: data mapping, privacy notices, consent flows |
| soc2-compliance | SOC 2 Type II: controls, evidence gathering, audit preparation |
| iso27001-isms | ISO 27001 Information Security Management System implementation |
| risk-management | Enterprise risk management: risk registers, FAIR framework, assessments |
| security-pen-testing | Penetration testing methodology: OWASP, PTES, reporting |

## data-engineering

_11 skills — Data pipelines, Python data science, MLOps, SQL, GraphQL, Drizzle, WebSocket_

| Skill | Description |
|-------|-------------|
| polars | Fast in-memory DataFrame library: lazy evaluation, parallel, Arrow backend |
| data-pipeline-engineer | Scalable data pipelines: Apache Spark, dbt, Airflow, modern data stack |
| airflow-dag-patterns | Apache Airflow DAGs: operators, sensors, testing, deployment patterns |
| async-python-patterns | Asynchronous Python: asyncio, concurrent programming, high-performance I/O |
| mlops-engineer | ML pipelines, experiment tracking with MLflow, Kubeflow, model registries |
| statistical-analyst | Hypothesis tests, A/B experiment analysis, sample sizes, effect sizes |
| database-schema-designer | ERD design, schema normalization, table relationships, migration planning |
| sql-expert | SQL queries, performance optimization, ORM integration (Prisma, Drizzle, SQLAlchemy) |
| graphql-expert | GraphQL schema design, DataLoader N+1 fix, codegen, Apollo vs graphql-request |
| drizzle-orm | Drizzle ORM: pgTable schema, query API, migrations, Supabase integration |
| websocket-realtime | WebSocket/SSE/Supabase Realtime: Next.js Route Handlers, reconnection hooks |

## data-processing

| Skill | Description |
|-------|-------------|
| api-contracts-and-zod-validation | Zod schemas and TypeScript types for forms, API routes, Server Actions |
| env-config-validator | Validate .env files across environments, check scoping |
| zod-expert | Zod v3 advanced: discriminated unions, transforms, superRefine, RHF integration |

## engineering-practices

_12 skills — API design, profiling, tech debt, monorepo, migration, FastAPI_

| Skill | Description |
|-------|-------------|
| api-design-reviewer | Comprehensive API design analysis: REST conventions, breaking changes, scorecards |
| openapi-spec-generation | Generate OpenAPI 3.1 specs from code; SDK generation, contract compliance |
| performance-profiler | Systematic profiling: Node/Python/Go, flamegraphs, bundle sizes, load testing |
| dependency-auditor | Audit dependencies: CVE scanning, license compliance, upgrade planning |
| codebase-onboarding | Onboard developers to unfamiliar codebases systematically |
| tech-debt-tracker | Scan for technical debt, score severity, generate prioritized remediation plans |
| migration-architect | Database and platform migration architecture and execution planning |
| monorepo-architect | Nx/Turborepo/Bazel expert for efficient multi-project monorepo development |
| release-manager | Plan releases, manage changelogs, coordinate deployments, automate versioning |
| ci-cd-pipeline-builder | Generate CI/CD pipelines for any detected project stack |
| spec-driven-workflow | Spec-first development: write acceptance criteria and specs before code |
| fastapi-expert | High-performance async APIs with FastAPI, SQLAlchemy 2.0, Pydantic V2, microservices |
| bun-runtime | Bun: Bun.serve(), Bun.file(), bun:sqlite, test runner, bundler, shell scripting |

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
| temporal-developer | Temporal durable execution: workflows, activities, workers, Python/TS/Go SDK |
| gmail-integration | Gmail: compose, search, label, filter, thread management |
| linear-integration | Linear project management: issues, projects, cycles, team workflows |
| youtube-transcript | Fetch and analyze YouTube video transcripts for content extraction |
| deep-research | PhD-level recursive research across any domain with source tiering |

## ios-swift

_15 skills — iOS architecture, Swift concurrency, SwiftUI, StoreKit, SwiftData, WidgetKit, macros, SPM_

| Skill | Description |
|-------|-------------|
| ios-architecture | iOS MVVM with @Observable, Clean Architecture, TCA, modular SPM, Coordinator |
| ios-concurrency | Swift Concurrency: async/await, structured concurrency, actors, Swift 6 |
| ios-networking | iOS networking: URLSession async/await, type-safe API clients, OAuth2, WebSocket |
| ios-performance | iOS performance: ARC, retain cycles, SwiftUI opt, Instruments profiling |
| ios-testing | iOS testing: Swift Testing framework, XCTest, UI Testing, snapshot testing |
| ios-swiftui-expert | Expert SwiftUI: layout system, state management, NavigationStack, animations |
| react-native-best-practices | React Native New Architecture: animations, audio, gestures, JSI, on-device AI |
| storekit-iap | StoreKit 2: Product.products(), purchase(), Transaction.updates, entitlements |
| swiftdata-expert | SwiftData: @Model, @Query, relationships, SchemaMigrationPlan, CloudKit |
| widgetkit | WidgetKit: TimelineProvider, AppIntent interactive widgets, Live Activities |
| swift-macros | Swift 5.9+ macros: freestanding, attached, SwiftSyntax, macro testing |
| app-store-connect | App Store: xcodebuild archive/export, ASC API, fastlane, rejection reasons |
| xcode-cloud | Xcode Cloud: ci_scripts/, hooks, env vars, test plans, TestFlight distribution |
| spm-author | SPM package authoring: Package.swift, resources, binary targets, local dev |
| swiftui-navigation | SwiftUI navigation: NavigationPath, deep links, sheet coordination, tab stacks |

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
| core-web-vitals | LCP/CLS/INP optimization for Next.js: images, fonts, code splitting, Vercel |

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

## product-business

_8 skills — C-level advisors, product strategy, competitive analysis, investor materials_

| Skill | Description |
|-------|-------------|
| cto-advisor | CTO technology strategy: tech roadmap, architecture governance, build vs buy |
| ceo-advisor | CEO strategic advisor: vision, growth strategy, stakeholder management |
| product-discovery | Product discovery: user research, problem definition, opportunity sizing |
| product-strategist | Product strategy: vision, positioning, roadmap, OKRs, metrics |
| competitive-teardown | Deep competitive analysis: feature comparison, positioning, gap analysis |
| founder-coach | Startup founder coaching: fundraising, team building, pivots, scaling |
| agile-product-owner | Agile product ownership: story writing, backlog refinement, sprint planning |
| investor-materials | Create investor pitch decks, one-pagers, financial models |

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

_17 skills — Auth, CSP, RLS, RBAC, hardening, Semgrep rules, fuzzing, YARA, supply chain_

| Skill | Description |
|-------|-------------|
| auth-route-protection-checker | Audit Next.js routes for missing auth checks |
| csp-config-generator | Generate Content Security Policy headers for Next.js |
| supabase-rls-policy-generator | Row-Level Security policies for multi-tenant Supabase apps |
| role-permission-table-builder | RBAC permission matrices in markdown or SQL |
| security-hardening-checklist | Full security audit: headers, cookies, RLS, rate limiting |
| output-guardrails | Safety validation and content constraints for LLM outputs |
| c-security-review | Comprehensive C/C++ security review with clustered parallel workers |
| static-code-analysis | Multi-tool static analysis with CodeQL and Semgrep |
| semgrep-rule-creator | Create custom Semgrep vulnerability detection rules |
| supply-chain-risk-auditor | Audit supply-chain threat landscape of project dependencies |
| insecure-defaults-finder | Identify weak configurations and hardcoded secrets |
| gha-security-review | GitHub Actions workflow security review for CI vulnerabilities |
| find-bugs | Find bugs and security vulnerabilities systematically |
| differential-security-review | Analyze code changes with emphasis on security implications |
| ffuf-web-fuzzing | Expert web fuzzing with ffuf during penetration testing |
| yara-rule-authoring | Develop YARA malware detection rules with quality checks |
| mutation-testing | Configure mutation testing campaigns for code robustness |
| api-security-hardening | API security: Upstash rate limiting, JWT/API key middleware, CORS, security headers |

## ui-ux

| Skill | Description |
|-------|-------------|
| frontend-design | Production-grade frontend interfaces (also available as plugin) |
| tailwind-shadcn-ui-setup | Tailwind v4 + shadcn/ui setup for Next.js 16 |
| form-generator-rhf-zod | React Hook Form + Zod forms with shadcn/ui |
| ui-library-usage-auditor | Audit shadcn/ui usage for accessibility and consistency |
| markdown-editor-integrator | @uiw/react-md-editor integration |
| uniapp-frontend | uni-app cross-platform (WeChat, H5) with Vue 3 + TS |
| react-best-practices | React/Next.js 40+ performance optimization rules across 8 categories |
| d3js-visualizations | D3.js charts and interactive data visualizations |
| typescript-expert | Advanced TypeScript: generics, conditional types, template literals, satisfies |
| react-query-tanstack | TanStack Query v5: useQuery, useMutation, optimistic updates, Suspense |
| trpc-expert | tRPC v11: type-safe APIs, Next.js App Router, protected procedures, middleware |
| framer-motion | Framer Motion: AnimatePresence, layout animations, layoutId, scroll, drag |
| a11y-wcag | WCAG 2.2 accessibility: ARIA, focus management, keyboard nav, axe-core |
| storybook-expert | Storybook 8: stories, play functions, MSW mocking, Chromatic visual testing |
| image-optimization | next/image, WebP/AVIF, blur placeholders, CDN loaders, lazy loading |

## writing

| Skill | Description |
|-------|-------------|
| doc-coauthoring | Structured co-authoring workflow for docs, specs, proposals |
| internal-comms | Internal communications: status updates, newsletters, incident reports |
| tailored-resume-generator | Generate tailored resumes and cover letters |
| engineering-blog-writer | Write and improve technical/engineering blog posts |
| tufte-report-creator | Data-driven reports in Edward Tufte's visual style |
| technical-docs | Docusaurus/VitePress docs sites: sidebars, MDX, versioning, Algolia search |

---

_See [ROUTING-GUIDE.md](./ROUTING-GUIDE.md) for task→skill routing decisions._
_See [SOURCE-MAP.md](./SOURCE-MAP.md) for where each skill came from._
