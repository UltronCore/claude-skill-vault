# Repository Intake Report
## Ultra-Lovable Orchestrator — Source Analysis

**Date:** 2026-03-26
**Method:** Real GitHub page + README fetch via parallel subagents
**All star counts and status verified live**

---

## Repo Summaries — Real Data

### Tier 1: High Integration Value

#### firecrawl/open-lovable ⭐ 24,500 | MIT | Active (v3 Nov 2025)
- **Stack:** Next.js, TypeScript, Firecrawl API, multi-LLM (Gemini/Claude/GPT/Groq), Vercel Sandbox or E2B
- **Core capability:** URL → scrape → React app generation. Best-in-class website cloning.
- **Unique patterns:**
  - Morph LLM fast-apply: patch code without full regeneration (major efficiency win)
  - Dual sandbox abstraction: swap between Vercel Sandbox and E2B
  - Multi-provider LLM: swap models without changing workflows
- **Integration:** Core clone workflow (Section C). Firecrawl-first approach is the design pattern.
- **Security:** API keys in env only. No concerns.

#### dyad-sh/dyad ⭐ 20,000 | Apache 2.0 (core) + FSL (pro) | Daily commits
- **Stack:** Electron, TypeScript, React, Vite, Tailwind — native desktop app
- **Core capability:** Local-first AI app builder. No cloud dependency. BYOK.
- **Unique patterns:**
  - True local-first: runs entirely on user's machine, no sign-up
  - Fair-source split: Apache 2.0 core is fully open; pro features under FSL (commercial restriction for 2 years)
  - 20k stars, 1,247 commits, r/dyadbuilders community — most mature project in this set
  - Cross-platform Mac + Windows installers
- **Integration:** Task management patterns, local execution model, build workflow concepts
- **Security:** Local execution of AI-generated code — expected risk, user-controlled. API keys in OS keychain/config.

#### eyaltoledano/claude-task-master ⭐ 26,200 | MIT + Commons Clause | Very Active
- **Stack:** Node.js/JS, MCP (Model Context Protocol), multi-provider (Anthropic/OpenAI/Gemini/Perplexity/Ollama)
- **Core capability:** PRD → structured task hierarchy with dependencies. Best task management tool in the ecosystem.
- **Unique patterns:**
  - PRD-to-tasks pipeline: paste a requirements doc, get structured tasks with IDs and dependencies
  - Multi-model tiering: main model + research model + fallback model
  - Selective tool loading (core/standard/all) to conserve LLM context window
  - Native MCP server → works inside Claude Code, Cursor, Windsurf without API key (OAuth)
  - Cross-tag task movement with dependency awareness
- **Integration:** Section E (Task & Workflow Layer) — PRD-to-tasks pipeline directly adopted
- **License note:** Commons Clause means it cannot be resold/hosted as a service — fine for personal use
- **Security:** API key sprawl across many providers; MCP server has broad tool access in editor

#### chihebnabil/lovable-boilerplate ⭐ 51 | MIT | Actively maintained (Renovate bot, Mar 2026)
- **Stack:** React 19, Vite 7, TypeScript 5.9, Shadcn/UI (40+ components), Supabase, TanStack Query 5, React Hook Form + Zod 4, React Router 7
- **Core capability:** Most current, most maintained Lovable-compatible boilerplate
- **Unique patterns:**
  - Multi-IDE AI instruction files: CLAUDE.md + CURSOR-RULES.md + GitHub Copilot instructions
  - Renovate bot keeps all deps automatically current (React 19, Vite 7)
  - Supabase local dev with migrations folder — production-grade pattern
  - Design system guidelines embedded in AI instructions (color psychology, emotional tone)
- **Integration:** SaaS Starter template (Section F) — this is the canonical validated stack
- **Security:** Supabase anon key in env (standard). RLS not enforced by boilerplate — warn users.

#### lak7/devildev ⭐ 444 | Apache-2.0 | Daily commits (v0.5.1)
- **Stack:** Next.js, TypeScript, PostgreSQL+Prisma, Clerk auth, Supabase vector store, LangChain, Inngest background jobs, GitHub App
- **Core capability:** UNIQUE — architecture-first approach. Only tool in the set focused on spec → architecture, not code generation.
- **Unique patterns:**
  - Spec → Architecture → Modules → Implementation pipeline (nothing else does this)
  - Reverse-engineering: analyze existing GitHub repos to extract architecture
  - Architecture modification agent for iterative design evolution
  - PRD generation and saving
  - Supabase vector store for repo/doc retrieval during architecture analysis
  - Inngest for async background job processing
- **Integration:** Section A (Intake) gets the architecture-first pipeline concept. This is a genuinely novel capability.
- **Security:** GitHub App with RSA private key + ngrok for local dev + multiple webhook endpoints. Not for casual setup.

#### deepagents-open-lovable ⭐ 82 | Active Feb 2026
- **Stack:** Python 3.11+, LangGraph, LangChain, Claude (Anthropic), React 18, TypeScript, Vite, Tailwind, Sandpack
- **Core capability:** LangGraph-based stateful multi-agent orchestration for code generation
- **Unique patterns:**
  - SKILL.md files for agent behavior extension (very aligned with Claude Code's skill architecture!)
  - Sandpack: browser-native live preview without a server
  - Sub-agent pattern: separate designer and image researcher agents
  - Vercel one-click deployment built in
  - CLAUDE.md for project-level AI coding instructions
- **Integration:** Section D (Orchestration) — LangGraph patterns for stateful agent coordination

#### tinykit-studio/tinykit ⭐ 418 | MIT | Active alpha (Jan 2026)
- **Stack:** SvelteKit, PocketBase (embedded Go DB + auth + storage + realtime), Vercel AI SDK, Railway/Docker deploy
- **Core capability:** Self-hosted all-in-one AI app builder with built-in database
- **Unique patterns:**
  - PocketBase as all-in-one backend: database + auth + file storage + realtime in a single binary
  - Time-travel: snapshots on every change, full undo history — standout differentiator
  - One-file-per-app Svelte model — maximum simplicity
  - Domain-based multi-app routing on single server
  - 12+ starter templates, Railway one-click deploy
  - Built with Claude Code (commits co-authored by Claude)
- **Integration:** Template philosophy + self-hosted alternative option in Section F
- **Note:** Uses Svelte (not React/Next.js) — different stack from consensus, but self-hosted angle is valuable

---

### Tier 2: Medium Integration Value

#### freestyle-sh/Adorable ⭐ 694 | MIT | Very Active (commits this week)
- **Stack:** Next.js, TypeScript, Vercel AI SDK, OpenAI/Anthropic, assistant-ui, Freestyle cloud VMs, Shadcn/UI
- **Unique:** GitHub bidirectional sync, git-backed persistent VMs, one-click production publish
- **Limitation:** Relies on Freestyle proprietary VMs — lock-in risk; patterns usable but not the infrastructure
- **Integration:** UI quality standards, GitHub sync concept (Section B)

#### beam-cloud/lovable-clone ⭐ 276 | Aug 2025
- **Stack:** Python 3.12+, TypeScript, React+Vite+Shadcn, BAML (BoundaryML), FastMCP, Beam Cloud, WebSocket, OpenAI
- **Unique:** BAML structured LLM prompting — strongly typed AI responses with schema validation and test cases. Only Python-first backend in this set.
- **Integration:** Structured output pattern (Section B) — generate code with type-safe schemas, not freeform text

#### zainulabedeen123/Open-lovable-DIY ⭐ 38 | Stale Sep 2025 | MIT
- **Stack:** Next.js 15, TypeScript, Firecrawl, E2B sandbox, NextAuth (Google OAuth), Neon PostgreSQL
- **Unique:** E2B sandbox for secure isolated code execution, user analytics admin panel
- **Security concern:** Admin email hardcoded; stale — no security maintenance since Sep 2025
- **Integration:** E2B sandbox pattern noted; URL-clone workflow variant

#### soranoo/lovable-downloader ⭐ 27 | MIT | Dec 2025
- **Stack:** Chrome Extension (Manifest V3), Tampermonkey userscript, JavaScript
- **Unique:** Data portability from Lovable.dev — download your code without GitHub OAuth
- **Security:** Chrome Web Store rejected (must load as unpacked). JWT extraction from browser session.
- **Integration:** LOW — niche utility, export patterns noted but not core to skill

#### TesslateAI/Studio ⭐ 438 | Apache 2.0 | Possibly mirror (1 commit on main)
- **Stack:** React 19 + FastAPI + PostgreSQL + Redis + Docker/K8s + LiteLLM gateway + Stripe + Terraform
- **Unique:** Most feature-complete self-hosted platform — 11 agents, 67 templates, 10 IDE panels, 4 agent architectures
- **Caveat:** Main branch has 1 commit — appears to be a mirror; upstream source unclear
- **Integration:** Template archetype catalog inspiration (Section F), TESSLATE.md context file pattern

#### nextify-limited/libra ⭐ 1,500 | **AGPL-3.0** ⚠️ | Stalled Sep 2025
- **Stack:** Next.js 15, React 19, Turborepo, tRPC, Drizzle ORM, Cloudflare Workers, E2B+Daytona, Stripe, PostHog
- **Unique:** Most architecturally complete of all repos — 8+ microservices monorepo
- **License:** AGPL-3.0 — any derivative work must be open-sourced. **Do not integrate code directly.**
- **Integration:** Patterns only (not code) — Cloudflare Workers deployment, dual sandbox abstraction

---

### Tier 3: Low / Excluded

| Repo | Stars | Reason for Exclusion |
|------|-------|---------------------|
| we0-dev/we0 | 921 | **Explicitly discontinued** by maintainer ("停止更新和维护") |
| pkmixx/open-lovable | 23 | Redundant abandoned fork of firecrawl/open-lovable |
| MiladiCode/Lovable | 442 | 1 commit, no code — YouTube tutorial prompts only |
| AntonOsika/gpt-engineer | 55,200 | Effectively archived (superseded by lovable.dev); last real code commit Aug 2024 |
| ghostwriternr/nightona | 82 | Abandoned Jul 2025, **no license** (all rights reserved by default) |
| kehanzhang/lovable-clone | 194 | Abandoned Jul 2025, **no license**, podcast demo with 4 commits |
| ComposioHQ/lovable-for-ai-agents | 45 | **Archived by owner** Feb 2026 |
| filipecallegario/awesome-vibe-coding | N/A | **Repo does not exist** at provided URL |
| cporter202/lovable-for-beginners | 496 | Documentation only, no code to integrate |
| serralvo/TextFieldCounter | 436 | iOS Swift, out of scope |
| archtechx/enums | 561 | PHP library, out of scope |

---

## Tech Stack Consensus (verified from real data)

**Overwhelming consensus across all active, maintained repos:**

| Layer | Default | Alternative |
|-------|---------|-------------|
| Framework | Next.js 14/15 App Router | Vite+React, SvelteKit |
| Styling | Tailwind CSS | — |
| Components | Shadcn/UI | assistant-ui |
| Backend | Supabase | Prisma+PostgreSQL, PocketBase |
| Auth | Supabase Auth | Clerk, NextAuth |
| Validation | Zod | — |
| Data fetching | TanStack Query | React Query |
| Deploy | Vercel | Railway, Cloudflare Workers |
| AI SDK | Vercel AI SDK | direct Anthropic/OpenAI SDK |
| Package manager | pnpm / Bun | npm |

**Note:** TypeScript is universal across all active repos (96-99% of code).
