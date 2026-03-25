# Source Map

_Tracks where each installed skill came from. Use this for attribution, update tracking, and maintenance._

---

## Sources

### 1. obra/superpowers (Plugin — Official Marketplace)
**Install:** `/plugin install superpowers@claude-plugins-official`
**Version:** 5.0.5

Skills provided (all prefixed `superpowers:`):
- brainstorming, writing-plans, executing-plans, dispatching-parallel-agents
- requesting-code-review, receiving-code-review, finishing-a-development-branch
- using-git-worktrees, verification-before-completion, test-driven-development
- subagent-driven-development, writing-skills, systematic-debugging, using-superpowers

**Assessment:** Battle-tested workflow framework. Used as-is. No duplication.

---

### 2. anthropics/skills (Official — Partial Install)
**Marketplace:** Add via `/plugin marketplace add anthropics/skills` then `/plugin install example-skills@anthropic-agent-skills`

**Installed directly to `~/.claude/skills/`:**
- `mcp-builder` — MCP server creation guide (FastMCP / Node SDK)
- `webapp-testing` — Playwright-based local app testing

**Installed to vault (writing category):**
- `doc-coauthoring` — Structured documentation co-authoring
- `internal-comms` — Internal communication templates

**Not installed (rationale):**
- `algorithmic-art` — Niche (p5.js generative art)
- `canvas-design` — Niche (requires Python image libraries)
- `theme-factory` — Claude.ai artifact-focused, not Claude Code
- `web-artifacts-builder` — Claude.ai artifact-focused
- `slack-gif-creator` — Niche
- `brand-guidelines` — Anthropic internal brand (not generic)
- `frontend-design` — Already installed as official plugin
- `skill-creator` — Already installed as official plugin
- `pdf/docx/pptx/xlsx` — Document skills (install via `/plugin install document-skills@anthropic-agent-skills`)

**Note:** The Anthropic marketplace is now registered in `extraKnownMarketplaces` as `anthropic-agent-skills`.

---

### 3. PleasePrompto/notebooklm-skill
**Status:** 404 — Repo not found/removed.
**Action:** `notebooklm` skill already installed from a prior source (notebooklm-py v0.3.4). No action needed.

---

### 4. coreyhaines31/marketingskills (Plugin — marketing-skills@local)
**Install:** Fetched all SKILL.md files via GitHub API, created local plugin.
**Location:** `~/.claude/plugins/cache/local/marketing-skills/1.0.0/skills/`

**33 skills installed:**
ab-test-setup, ad-creative, ai-seo, analytics-tracking, churn-prevention, cold-email,
competitor-alternatives, content-strategy, copy-editing, copywriting, email-sequence,
form-cro, free-tool-strategy, launch-strategy, lead-magnets, marketing-ideas,
marketing-psychology, onboarding-cro, page-cro, paid-ads, paywall-upgrade-cro,
popup-cro, pricing-strategy, product-marketing-context, programmatic-seo,
referral-program, revops, sales-enablement, schema-markup, seo-audit,
signup-flow-cro, site-architecture, social-content

**Also in vault:** `marketing/` category

**Note:** `product-marketing-context` is the foundation skill — run it first when starting any marketing project. It creates `.agents/product-marketing-context.md` that all other skills reference.

---

### 5. ComposioHQ/awesome-claude-skills (Partial — Vault Only)
**Branch:** `master`
**Source URL:** `https://raw.githubusercontent.com/ComposioHQ/awesome-claude-skills/master/<skill>/SKILL.md`

**Installed to vault and `~/.claude/skills/`:**
- `content-research-writer` (research) — Research + citations + content writing

**Installed to vault only (business category):**
- `meeting-insights-analyzer` — Meeting transcript analysis
- `domain-name-brainstormer` — Domain name ideation
- `invoice-organizer` — Invoice parsing and organization

**Installed to vault only (marketing category):**
- `lead-research-assistant` — B2B lead research
- `developer-growth-analysis` — Growth analytics for dev tools
- `competitive-ads-extractor` — Extract competitor ad intelligence
- `twitter-algorithm-optimizer` — Twitter/X content optimization

**Installed to vault only (writing category):**
- `tailored-resume-generator` — Job-specific resume writing

**Installed to vault only (automation category):**
- `file-organizer` — File and directory organization
- `changelog-generator` — Git-based changelog generation

**Not installed (rationale):**
- `artifacts-builder` — Overlaps with web-artifacts-builder (Anthropic)
- `brand-guidelines` — Anthropic-specific branding
- `canvas-design` — Overlap with canvas-design (Anthropic)
- `composio-skills` — Composio-specific integration (requires Composio account)
- `connect-apps` / `connect-apps-plugin` / `connect` — Composio-specific
- `document-skills` — Overlap with Anthropic document-skills
- `image-enhancer` — Requires specific image processing tools
- `langsmith-fetch` — Niche (LangSmith specific)
- `mcp-builder` — Installed from Anthropic (stronger version)
- `raffle-winner-picker` — Too niche
- `skill-creator` — Already installed as plugin
- `skill-share` — Meta/administrative
- `slack-gif-creator` — Already from Anthropic skills
- `template-skill` — Template only
- `theme-factory` — Already from Anthropic
- `video-downloader` — Depends on yt-dlp, not universally useful
- `webapp-testing` — Installed from Anthropic (official version)

---

## Prior Vault Skills (Before This Session)

**Official Plugins (unchanged):**
- `frontend-design@claude-plugins-official` — UI design (plugin)
- `claude-md-management@claude-plugins-official` — CLAUDE.md management
- `skill-creator@claude-plugins-official` — Skill creation
- `swift-lsp@claude-plugins-official` — Swift LSP
- `postgres-best-practices@supabase-agent-skills` — Postgres best practices

**Local Plugins (unchanged):**
All skills in `~/.claude/plugins/cache/local/` under categories: automation, security, ui-ux, data-processing

**Skills from prior setup:** autonomous-knowledge-system, context-engineer, excalidraw-diagram, prompt-deepener, self-healing-execution, skill-portfolio-architect, system-builder, notebooklm, agent-native-automation-research-install

---

## Update Instructions

To update marketing skills: re-fetch from `coreyhaines31/marketingskills` master branch.

To update Anthropic skills: `/plugin install example-skills@anthropic-agent-skills` or re-fetch specific SKILL.md files.

To update ComposioHQ skills: re-fetch from `ComposioHQ/awesome-claude-skills` master branch.

To update Superpowers: `/plugin update superpowers@claude-plugins-official`
