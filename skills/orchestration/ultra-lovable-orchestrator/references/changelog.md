# Changelog
## Ultra-Lovable Orchestrator

---

## v1.1.0 — 2026-03-26

### Updated with verified real data from live repo research

**Corrections from initial analysis:**
- we0-dev/we0: EXPLICITLY DISCONTINUED — removed from integration credits
- dyad-sh/dyad: 20k stars (not "active but small") — elevated to HIGH tier
- claude-task-master: 26.2k stars, MCP-native — elevated prominence in Section E
- lak7/devildev: architecture-first pipeline recognized as unique — added Mode 2 Intake
- libra: AGPL-3.0 license — excluded from code integration
- awesome-vibe-coding: repo does not exist at provided URL — excluded
- nightona + kehanzhang/lovable-clone: no licenses — excluded
- ComposioHQ: archived — excluded
- gpt-engineer: effectively archived since Aug 2024 — downgraded to LOW
- AntonOsika/gpt-engineer: superseded by lovable.dev itself

**New content added:**
- Section A Mode 2: Architecture-First Intake (from lak7/devildev)
- Section E: PRD-to-Tasks pipeline (from claude-task-master)
- All reference files updated with verified star counts and real status

---

## v1.0.0 — 2026-03-26

### Created
- Initial release: ultra-lovable-orchestrator mega skill
- SKILL.md with 7 subsystems (A–G) plus Security + Documentation modes
- Full repo intake of 24 Lovable-ecosystem repositories
- Capability matrix covering all 24 repos across 11 categories
- Security audit report for all source repos
- Integration decisions report (repo-intake.md)
- This changelog

### Integrated (HIGH priority)
- gpt-engineer → intake pipeline + clarify-first pattern
- firecrawl/open-lovable → clone-site workflow
- we0-dev/we0 → multi-agent coordination
- claude-task-master → task structure (TASKS.md format)
- dyad-sh/dyad → resumable workflow + dependency tracking
- chihebnabil/lovable-boilerplate → SaaS starter stack

### Integrated (MEDIUM priority — patterns/inspiration)
- deepagents-open-lovable → agent sequencing
- beam-cloud/lovable-clone → release agent patterns
- freestyle-sh/Adorable → UI quality bar
- nextify-limited/libra → component patterns
- TesslateAI/Studio → template archetype catalog
- ghostwriternr/nightona → agent scoping
- tinykit-studio/tinykit → minimal-but-working philosophy
- ComposioHQ/lovable-for-ai-agents → tool integration

### Excluded
- pkmixx/open-lovable (redundant with firecrawl variant)
- soranoo/lovable-downloader (niche export, not core)
- serralvo/TextFieldCounter (iOS Swift, out of scope)
- archtechx/enums (PHP, out of scope)

### Architecture decisions
- Single SKILL.md entrypoint, reference files for deep detail
- 7 subsystems map to distinct user intents
- Default stack: Next.js + Tailwind + Supabase + Shadcn/UI
- Task layer uses TASKS.md at project root
- Agent coordination via sequential composition, not default-parallel

---

## Upgrade Path

To refresh this skill with updated repo analysis:
1. Re-run the repo intake pipeline (fetch fresh READMEs)
2. Update capability matrix for changed repos
3. Update integration decisions if new patterns emerge
4. Bump version in this file with date and changes
