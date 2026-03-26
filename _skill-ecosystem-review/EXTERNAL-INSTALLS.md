# External Skill Installs — 2026-03-26

These skills are installed in ~/.claude/skills/ but maintained by external authors.
They are NOT backed up to the vault (their authors' repos ARE the upstream source).
Re-install from these sources if lost.

## mattpocock/skills (MIT)
**Source:** https://github.com/mattpocock/skills
**Installed skills:**
- git-guardrails-claude-code — blocks destructive git commands via hook
- tdd — test-driven development with 5 reference docs  
- prd-to-issues — vertical-slice PRD → GitHub issues workflow
- ubiquitous-language — extract domain language from code
- improve-codebase-architecture — architecture review and improvement
- triage-issue — structured issue analysis
- grill-me — collaborative design exploration via questioning

**Re-install:** `cp -r /tmp/mattpocock-skills/{skill} ~/.claude/skills/`
or clone fresh from GitHub

## LeoLin990405/claude-office-skills (Anthropic content, MIT wrapper)
**Source:** https://github.com/LeoLin990405/claude-office-skills
**Note:** Content is Anthropic's official office skill library. Safe for personal use within Claude Code (covered by Anthropic ToS).
**Installed skills:**
- office-pdf — PDF extraction, creation, merging, splitting, forms
- office-docx — DOCX OOXML manipulation, redlining, content editing
- office-xlsx — Spreadsheet analysis, openpyxl, pandas, LibreOffice recalc
- office-pptx — PPTX creation/editing, html2pptx, OOXML, thumbnails

**Dependencies:** pypdf, pdfplumber, reportlab, openpyxl, pandas, pandoc, LibreOffice (for recalc/thumbnails)
**Re-install:** Clone from source, copy skills/pdf|docx|xlsx|pptx → ~/.claude/skills/office-{type}

## teng-lin/agent-fetch (MIT)
**Source:** https://github.com/teng-lin/agent-fetch
**Installed skill:** agent-fetch — browser-impersonating web fetcher, no API key, 7 extraction strategies
**Runtime:** `npx agent-fetch` (no global install needed)
**Use when:** Firecrawl is blocked, unavailable, or you need local/offline extraction
**Re-install:** Clone from source, copy skills/agent-fetch → ~/.claude/skills/agent-fetch

## Skipped Sources (with reasoning)
| Repo | Reason |
|------|--------|
| ComposioHQ/awesome-claude-skills | Curated list only; duplicate skills already in vault; Composio API required for most |
| SkyworkAI/Skywork-Skills | Proprietary API, content uploads to Alibaba OSS, 10-day-old repo |
| jeremylongshore/excel-analyst-pro | Proprietary license (Intent Solutions) — legal risk |
| 10x-Anit/10X-Canva-Skills | Canva MCP already active; repo inaccessible; unlicensed |
| karanb192/awesome-claude-skills | Curated list only, no installable files |
| vibeeval/vibecosystem | Pre-compiled .mjs hooks unauditable; massive collision risk with existing setup |
| heeyo-life/skillboss-skills | Proprietary SaaS, all traffic through skillboss.co intermediary, API key required |

## Security Findings
- **marketing/developer-growth-analysis** (ARCHIVED): Accessed private Claude Code chat history and sent contents to Slack DMs. Removed from vault.
- **vibeeval hooks**: Pre-compiled TypeScript `.mjs` files in `hooks/dist/` — cannot verify behavior without rebuilding from source. Do not install without TypeScript audit.
- **SkyworkAI**: Caches API tokens in `~/.skywork_token` (plaintext), uploads content to Alibaba OSS.
