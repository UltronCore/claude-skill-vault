# Capability Matrix
## Ultra-Lovable Orchestrator — Real Data (verified 2026-03-26)

---

## Matrix: Repo × Capability (Real Stars)

| Repository | Stars | App Gen | Prompt→Code | Arch-First | Multi-Agent | Task Mgmt | UI Scaffold | Clone/Recreate | Boilerplate | Self-Hosted | Structured Output |
|---|---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| firecrawl/open-lovable | 24.5k | ★★ | ★★ | | | | ★★ | ★★★ | | | |
| dyad-sh/dyad | 20k | ★★★ | ★★★ | | ★★ | ★★★ | | | | ★★★ | |
| eyaltoledano/claude-task-master | 26.2k | | | | | ★★★ | | | | | |
| AntonOsika/gpt-engineer | 55.2k | ★★ | ★★★ | | | | | | | | |
| chihebnabil/lovable-boilerplate | 51 | | | | | | ★★★ | | ★★★ | | |
| lak7/devildev | 444 | | ✓ | ★★★ | ★★ | ★★ | | | | | |
| deepagents-open-lovable | 82 | ★★ | ★★ | | ★★★ | | | | | | |
| tinykit-studio/tinykit | 418 | ★★★ | ★★ | | | | ★★ | | ★★ | ★★★ | |
| freestyle-sh/Adorable | 694 | ★★ | ★★ | | | | ★★ | | | | |
| TesslateAI/Studio | 438 | ★★★ | ★★ | | ★★★ | ★★ | ★★ | | ★★★ | ★★★ | |
| beam-cloud/lovable-clone | 276 | ★★ | | | | | | | | | ★★★ |
| nextify-limited/libra | 1.5k | ★★ | | | | | ★★ | | ★★ | ★★ | |
| Open-lovable-DIY | 38 | ★★ | | | | | | ★★ | | | |
| soranoo/lovable-downloader | 27 | | | | | | | ✓ | | | |
| MiladiCode/Lovable | 442 | | ✓ | | | | | | | | |
| cporter202/lovable-for-beginners | 496 | | ✓ | | | | | | | | |
| serralvo/TextFieldCounter | 436 | EXCLUDED — iOS Swift | | | | | | | | | |
| archtechx/enums | 561 | EXCLUDED — PHP | | | | | | | | | |

**Legend:** ★★★ = best-in-class | ★★ = solid | ✓ = present/minor | blank = not a capability

---

## Capability Leaders (Real Data)

| Category | Winner | Stars | Runner-Up | Stars |
|---|---|---:|---|---:|
| Task Management | eyaltoledano/claude-task-master | 26.2k | dyad-sh/dyad | 20k |
| App Generation | dyad-sh/dyad | 20k | tinykit | 418 |
| Prompt→Code | AntonOsika/gpt-engineer (archived) | 55.2k | deepagents-open-lovable | 82 |
| Architecture-First | lak7/devildev | 444 | (only one) | — |
| Clone/Recreation | firecrawl/open-lovable | 24.5k | Open-lovable-DIY | 38 |
| Boilerplate/Scaffold | chihebnabil/lovable-boilerplate | 51 | TesslateAI/Studio | 438 |
| Self-Hosted | tinykit | 418 | TesslateAI/Studio | 438 |
| Structured LLM Output | beam-cloud/lovable-clone | 276 | (only one using BAML) | — |
| Multi-Agent Orchestration | deepagents-open-lovable | 82 | lak7/devildev | 444 |
| Template Catalog | TesslateAI/Studio | 438 | chihebnabil/lovable-boilerplate | 51 |

---

## Integration Decision Matrix (Final)

| Repo | Integration Level | What Was Taken |
|------|-----------------|----------------|
| firecrawl/open-lovable | HIGH | Clone workflow, Morph fast-apply pattern, multi-LLM approach |
| dyad-sh/dyad | HIGH | Local build patterns, task tracking, resumable sessions |
| eyaltoledano/claude-task-master | HIGH | PRD-to-tasks pipeline, multi-model tiering, TASKS.md format |
| chihebnabil/lovable-boilerplate | HIGH | Canonical SaaS stack, multi-IDE AI instructions, Supabase local dev |
| lak7/devildev | HIGH | Architecture-first pipeline (unique), spec→arch→modules→impl |
| deepagents-open-lovable | HIGH | LangGraph agent patterns, SKILL.md extension pattern, Sandpack |
| tinykit-studio/tinykit | MEDIUM | Self-hosted philosophy, time-travel concept, template variety |
| TesslateAI/Studio | MEDIUM | Template archetype catalog (67 templates), TESSLATE.md context pattern |
| beam-cloud/lovable-clone | MEDIUM | BAML structured output pattern, Python backend reference |
| freestyle-sh/Adorable | MEDIUM | GitHub bidirectional sync concept, persistent session patterns |
| nextify-limited/libra | MEDIUM | Patterns only (AGPL bars code); Cloudflare Workers deploy, dual sandbox |
| Open-lovable-DIY | MEDIUM | E2B sandbox pattern, user analytics approach |
| soranoo/lovable-downloader | LOW | Data portability awareness, export concept |
| cporter202/lovable-for-beginners | LOW | Prompt patterns distilled |
| MiladiCode/Lovable | LOW | Prompt engineering for GSAP/Spline/Locomotive Scroll |
| we0-dev/we0 | EXCLUDED | Discontinued by owner |
| AntonOsika/gpt-engineer | EXCLUDED | Effectively archived (Aug 2024 last code commit); superseded |
| ghostwriternr/nightona | EXCLUDED | No license, abandoned |
| kehanzhang/lovable-clone | EXCLUDED | No license, abandoned podcast demo |
| pkmixx/open-lovable | EXCLUDED | Redundant fork |
| ComposioHQ/lovable-for-ai-agents | EXCLUDED | Archived by owner |
| filipecallegario/awesome-vibe-coding | EXCLUDED | Repo does not exist |
| serralvo/TextFieldCounter | EXCLUDED | iOS Swift — out of scope |
| archtechx/enums | EXCLUDED | PHP — out of scope |

---

## Tech Stack Consensus (Verified)

From active, maintained repos only (2025-2026):

**Universal:** TypeScript (96-99% of all code)
**Framework consensus:** Next.js App Router (used in 7/11 active repos)
**UI consensus:** Tailwind + Shadcn/UI (used in 8/11 active repos)
**Backend consensus:** Supabase (used in 5/11 active repos, lovable-boilerplate, devildev, DIY...)
**Validation consensus:** Zod (universal in TypeScript repos)
**AI SDK:** Vercel AI SDK (used in 4/11 repos)
**Deploy:** Vercel (primary), Railway (secondary), Cloudflare Workers (emerging)
