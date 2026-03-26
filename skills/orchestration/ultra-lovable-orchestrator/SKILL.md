---
name: ultra-lovable-orchestrator
description: |
  Full-stack autonomous app generation mega-skill — a Lovable-inspired build ecosystem for Claude Code.
  Use this skill when the user wants to: build an app, scaffold a project, generate UI/fullstack code,
  clone/recreate a website, plan a complex build, orchestrate multi-agent development, manage build tasks,
  audit a codebase, document a project, or run any Lovable-style prompt-to-app workflow.
  Triggers on: "build me an app", "create a project", "scaffold X", "clone this site", "generate UI",
  "plan this app", "run agents on", "vibe code", "lovable-style", "prompt to code", "full stack generate",
  "create a SaaS", "build a dashboard", "make a landing page", "create an admin panel",
  "generate a CRUD app", "build a workflow tool", "create an auth app", "help me build",
  "analyze my codebase", "document my project", "refine my app", "upgrade my skill".
  This is the primary skill for any autonomous app creation, generation, or orchestration request.
---

# Ultra-Lovable Orchestrator

A unified Claude Code mega-skill for autonomous full-stack app generation, cloning, orchestration, task management, and documentation. Synthesizes the strongest patterns from the Lovable ecosystem into one coherent, production-ready system.

## Quick Command Reference

| Command Intent | Say | What Happens |
|---|---|---|
| Analyze project | "analyze project" | Full codebase inspection + report |
| Plan an app | "plan app: [description]" | Architecture + task decomposition |
| Generate app | "generate app: [description]" | Full-stack scaffolding + code |
| Clone a site | "clone site: [url]" | Recreate with modern stack |
| Scaffold starter | "scaffold [type]" | Boilerplate from template library |
| Run agents | "run agents on [task]" | Multi-agent orchestration |
| Manage tasks | "manage tasks" | Task tracking + next steps |
| Refine project | "refine [aspect]" | Targeted improvement pass |
| Audit security | "audit security" | Security + risk review |
| Document project | "document project" | Auto-generate docs |
| Upgrade skill | "upgrade skill" | Self-improvement + refresh |

---

## How to Use This Skill

Read the user's intent and route to the appropriate subsystem below. Most requests combine 2-3 subsystems — that's expected. Run them in sequence or parallel as appropriate.

For complex multi-step builds, always: **Intake → Plan → Generate → Refine → Document**

---

## A. Intake & Understanding Layer

**When:** Any new project, codebase, or prompt arrives. Always run before generating.

**Two modes — choose based on what the user provides:**

### Mode 1: Standard Intake (prompt or existing codebase)
1. **Parse the prompt** — extract: app type, target users, core features, tech preferences, constraints, existing code
2. **Detect tech stack** — read package.json, requirements.txt, go.mod, Cargo.toml, pyproject.toml, or any manifest; infer from file patterns
3. **Map file tree** — understand src layout, entry points, config files, build system
4. **Extract requirements** — implicit (from domain) + explicit (from prompt)
5. **Identify gaps** — what's missing, unclear, or ambiguous

### Mode 2: Architecture-First Intake (for complex or PRD-based projects)
*Inspired by lak7/devildev — the only architecture-first tool in the Lovable ecosystem.*

When the user provides a PRD, a detailed spec, or an existing complex codebase:
1. **Extract system architecture** — identify bounded contexts, data models, service boundaries, integration points
2. **Generate architecture document** — modules, their responsibilities, relationships, and data flows
3. **Decompose into build phases** — Phase 1 (foundation), Phase 2 (core features), Phase 3 (polish/integrations)
4. **Map to implementation tasks** — each module becomes a tracked task
5. **Identify critical path** — which tasks block others, what can be parallel

Architecture document format:
```
## Architecture: [App Name]
### Modules
- [Module]: [Responsibility] → [Data owned] → [Interfaces with]
### Data Model
- [Entity]: [Fields] [Relationships]
### Build Phases
- Phase 1: [Foundation tasks]
- Phase 2: [Core feature tasks]
- Phase 3: [Integration/polish tasks]
```

**When to use Mode 2:** User has a written spec, PRD, or complex existing system to analyze. Mode 2 produces better task decomposition for builds >5 features.

**Output format:**
```
## Project Intake Report
- Type: [SaaS / Dashboard / Landing / API / Mobile / CLI / Library]
- Stack: [Frontend / Backend / DB / Auth / Deploy]
- Core features: [bullet list, max 8]
- Constraints: [bullet list]
- Ambiguities: [what needs clarification if any]
- Recommended approach: [1-2 sentences]
```

**Key principle:** Understand before generating. A 2-minute intake saves 20 minutes of wrong output.

---

## B. Generation Layer

**When:** User wants code — app, UI, component, API, schema, or scaffold.

**Generation approach:** Think like Lovable. Generate complete, working, connected code — not stubs.

### Full-Stack App Generation
1. Choose stack (default: Next.js + Tailwind + Supabase/SQLite + Shadcn/UI unless user specifies)
2. Scaffold directory structure first
3. Generate in this order: schema → auth → API routes → UI components → pages → config
4. Connect everything — no orphaned files
5. Add sensible defaults (env.example, .gitignore, README skeleton)

### UI Generation
- Use Tailwind + Shadcn/UI as default
- Generate responsive layouts
- Include dark mode when appropriate
- Use semantic HTML
- Add loading states and error boundaries

### Component Generation
- Match existing codebase conventions (read 2-3 existing components first)
- Generate props, types, and logic together
- Include basic accessibility (aria labels, keyboard nav)

### API Route Generation
- REST by default, tRPC if user uses it
- Include input validation (zod)
- Return consistent error shapes
- Add JSDoc for complex endpoints

### Schema Suggestions
- Normalize appropriately
- Add sensible indexes
- Include created_at/updated_at by default
- Consider RLS policies for Supabase

**Quality bar:** Generated code should run without modification in 80%+ of cases. Prefer working > perfect.

---

## C. Cloning & Recreation Layer

**When:** User provides a URL or screenshot and wants to recreate/modernize it.

**Workflow:**
1. **Analyze source** — if URL, fetch with firecrawl-scrape; if screenshot, describe what you see
2. **Extract structure** — layout sections, components, color scheme, typography, interactions
3. **Map to modern stack** — identify Tailwind equivalents for styles
4. **Reconstruct** — generate section by section, then wire together
5. **Modernize** — improve accessibility, responsiveness, performance where source was weak

**Safe fallback strategy:** If exact recreation isn't possible (proprietary fonts, complex animations, auth-gated content), reproduce the layout and intent, note what couldn't be captured, and suggest alternatives.

**Inspired by:** open-lovable (firecrawl/pkmixx variants), soranoo/lovable-downloader patterns

---

## D. Orchestration Layer

**When:** Complex builds that benefit from parallel or specialized agents.

**Rule:** Only spawn agents when tasks are genuinely independent. Serial is simpler and often faster for <3 tasks.

### Agent Roster

**Planner Agent** — Decomposes requirements into tracked tasks. Output: numbered task list with dependencies.

**Researcher Agent** — Gathers context: reads docs, fetches APIs, inspects existing code. Never modifies files.

**Code Generator Agent** — Writes implementation code for a specific task. Scoped to one feature/module.

**Reviewer Agent** — Checks output against requirements and coding standards. Produces diff-style feedback.

**Refactor Agent** — Improves existing code: naming, structure, DRY, performance. Does not change behavior.

**Debug Agent** — Diagnoses failures. Reads error output, traces call stack, proposes minimal fix.

**Integration Agent** — Connects components: wires API calls, updates imports, adds env vars, fixes types.

**Documentation Agent** — Generates README, JSDoc, inline comments, and architecture notes.

**Release Agent** — Prepares for deploy: build check, env audit, changelog entry, version bump.

### Orchestration Protocol
```
1. Planner decomposes → task list
2. Identify independent tasks → run in parallel via Agent tool
3. Identify sequential tasks → run in order
4. After each agent: Reviewer checks output
5. Integration Agent connects completed parts
6. Final pass: Documentation Agent
```

**Coordination signal:** Agents communicate through task output files in `./build-workspace/`. No shared mutable state.

---

## E. Task & Workflow Layer

**When:** Managing complex multi-step builds, tracking progress, resuming interrupted work.

**Inspired by:** eyaltoledano/claude-task-master (26.2k stars, MCP-native, production-grade)

### PRD-to-Tasks Pipeline

When the user provides a requirements document (PRD, spec, or detailed description):
1. Parse into features (each feature = 1+ tasks)
2. Identify dependencies between tasks (what must come first)
3. Assign priority: high (blocking), medium (core), low (polish)
4. Output TASKS.md at project root

**Multi-model approach for task research:** For complex features, use a research pass before writing implementation tasks — search docs, understand constraints, then write tasks with that context. This avoids tasks that are wrong in structure or make false assumptions.

### Task Structure
```markdown
## Task: [ID] [Name]
Status: pending | in_progress | blocked | done
Priority: high | medium | low
Depends: [task IDs]
---
[1-3 sentence description]
[acceptance criteria]
```

### Workflow Rules
1. Break any build with >3 distinct features into tasks
2. Mark status immediately when starting/finishing
3. Blocked = missing info or upstream dependency
4. Never leave a task "in_progress" at end of session — either done or reset to pending with a note
5. Keep task list in `TASKS.md` at project root
6. Resume: read TASKS.md first, continue from first `pending` task

### Default Task Template for New Apps
```
T01 Project scaffold + config
T02 Database schema
T03 Authentication
T04 Core data models / API
T05 UI: layout + navigation
T06 UI: main feature screens
T07 UI: forms + validation
T08 Integration + end-to-end wiring
T09 Error handling + loading states
T10 README + deployment notes
```

---

## F. Template & Accelerator Layer

**When:** User wants to start from a known pattern rather than blank slate.

### App Archetypes

**SaaS Starter**
- Stack: Next.js 14 + Supabase + Stripe + Resend + Shadcn/UI
- Auth: Supabase Auth with email + OAuth
- Structure: `app/(auth)`, `app/(dashboard)`, `app/api`
- Key files: middleware.ts, stripe webhooks, auth callbacks

**Admin Panel**
- Stack: Next.js + Prisma + NextAuth + Shadcn/UI + TanStack Table
- Features: CRUD tables, role-based access, audit log, search/filter
- Pattern: server components for data, client components for interaction

**Landing Page**
- Stack: Next.js + Tailwind + Framer Motion (optional)
- Sections: Hero, Features, Pricing, Testimonials, CTA, Footer
- Performance: static generation, optimized images, minimal JS

**Internal Tool**
- Stack: Next.js + Prisma + SQLite/Postgres + Shadcn/UI
- Auth: single-tenant, session-based
- Pattern: data-heavy tables, forms, dashboards

**CRUD App**
- Stack: Next.js + Drizzle + SQLite + Shadcn/UI
- Pattern: list → detail → create/edit → delete with confirmation
- Include: pagination, search, sort, optimistic updates

**Auth App**
- Stack: Next.js + NextAuth or Supabase Auth
- Flows: sign up, sign in, forgot password, email verification, profile
- Include: protected routes, session management, token refresh

**Workflow App**
- Stack: Next.js + Supabase + React Query
- Pattern: kanban or pipeline UI, status transitions, notifications
- Include: drag-and-drop, real-time updates (optional)

**AI-Integrated App**
- Stack: Next.js + Vercel AI SDK + OpenAI/Anthropic + Supabase
- Pattern: streaming UI, chat interface, tool calls, memory
- Include: rate limiting, usage tracking, error recovery

### Prompt Patterns (distilled from educational repos)

**Lovable-style prompting:**
> "Build a [app type] with [key features]. Use [stack]. Include [auth/payments/AI]. Make it production-ready."

**Feature addition:**
> "Add [feature] to the existing codebase. Match current conventions. Include tests if the project has them."

**Refactor request:**
> "Refactor [component/module] to be cleaner. Don't change behavior. Explain key decisions."

**Clone request:**
> "Recreate [URL/description] using [stack]. Modernize where appropriate. Focus on [aspect]."

---

## G. Refinement & Optimization Layer

**When:** After initial generation, or when user says "improve", "refactor", "clean up", "optimize".

### Self-Audit Checklist
Run this after any significant generation:
- [ ] No orphaned imports or unused variables
- [ ] All components are connected to real data (no hardcoded arrays where API should be)
- [ ] Error states exist (not just happy path)
- [ ] Loading states exist for async operations
- [ ] No console.log left in production code
- [ ] Types are correct (no `any` unless justified)
- [ ] File/folder structure is consistent
- [ ] No duplicate logic that should be extracted

### Optimization Targets
- **Token efficiency:** Prefer generated code that is complete but not verbose. No boilerplate comments.
- **Bundle size:** Prefer tree-shakeable imports. Avoid heavy dependencies for simple tasks.
- **Runtime:** Prefer server components for data fetching in Next.js apps.
- **Maintainability:** Consistent naming, clear file organization, no magic strings.

---

## Security Audit Mode

**When:** User asks to audit, or before finalizing any project.

### Security Review Checklist
```
Authentication & Authorization:
- [ ] Auth is enforced on all protected routes (middleware or server-side)
- [ ] Role checks exist on sensitive API routes
- [ ] Passwords never logged or stored in plain text
- [ ] Tokens have appropriate expiry

Input Validation:
- [ ] All user input is validated (zod, yup, or equivalent)
- [ ] SQL queries use parameterization (ORM) not string concatenation
- [ ] File uploads validate type, size, and scan for content

Secrets & Config:
- [ ] No hardcoded secrets in source
- [ ] .env.example exists with safe placeholder values
- [ ] .env is in .gitignore
- [ ] API keys scoped to minimum needed permissions

Dependencies:
- [ ] No known-vulnerable packages (npm audit / pip-audit)
- [ ] No packages with unusual postinstall scripts
- [ ] Pinned versions for production dependencies

Data Exposure:
- [ ] API responses don't leak internal fields
- [ ] Error messages don't expose stack traces to clients
- [ ] CORS configured restrictively

External Calls:
- [ ] Rate limiting on outbound API calls
- [ ] Timeouts on all HTTP calls
- [ ] No eval() or dynamic code execution on user input
```

**Output format:** Table of findings with severity (critical/high/medium/low) and remediation.

---

## Documentation Mode

**When:** User wants auto-generated docs, README, or architecture notes.

### README Template
```markdown
# [Project Name]

[One-sentence description]

## What it does
[2-3 bullets]

## Stack
[Frontend + Backend + Database + Auth + Deploy]

## Getting started
\`\`\`bash
npm install
cp .env.example .env
# fill in .env values
npm run dev
\`\`\`

## Environment variables
| Variable | Description | Required |
|---|---|---|

## Project structure
\`\`\`
src/
  app/        # Next.js app router
  components/ # Shared UI components
  lib/        # Utilities and helpers
\`\`\`

## Deploy
[1-2 steps to deploy to Vercel/Railway/Fly]
```

---

## Upgrade & Maintenance

**When:** User says "upgrade skill" or you're refreshing from new repo research.

### Self-Improvement Protocol
1. Identify the weakest part of the last build (what required the most back-and-forth)
2. Extract the pattern that would have prevented it
3. Add it to the relevant subsystem above
4. Remove any guidance that proved unhelpful in practice

### Repo Refresh
To re-analyze the source repos and update this skill:
- Run the ultra-lovable repo intake pipeline
- Compare capability matrix changes
- Update templates and patterns accordingly
- Log changes in CHANGELOG.md

---

## Default Workflow (Daily Use)

**For a new app build:**
```
1. Intake & Understand (5 min)
2. Plan: generate task list (2 min)
3. Scaffold project structure (5 min)
4. Generate in task order, reviewing each (variable)
5. Self-audit pass (5 min)
6. Write README (3 min)
```

**For a clone request:**
```
1. Fetch/analyze source
2. Extract layout + components
3. Scaffold with chosen stack
4. Generate section by section
5. Wire + connect
6. Modernize + audit
```

**For a refine request:**
```
1. Read existing code
2. Run self-audit checklist
3. Identify top 3 issues
4. Fix in priority order
5. Verify nothing broke
```

---

## Reference Files

- `references/capability-matrix.md` — Full repo intake matrix and integration decisions
- `references/security-report.md` — Security findings from repo analysis
- `references/repo-intake.md` — Per-repo analysis and source data
- `references/changelog.md` — Version history of this skill
