# Maintenance Guide

_For keeping this skill system organized, non-redundant, and up to date._

---

## Vault Structure

```
~/claude-skill-vault/
├── MASTER-INDEX.md       ← Full skill catalog with descriptions
├── ROUTING-GUIDE.md      ← Task → skill decision map
├── SOURCE-MAP.md         ← Attribution and update instructions per source
├── MAINTENANCE.md        ← This file
├── skills/
│   ├── _archive/         ← Deprecated/superseded skills (keep for history)
│   ├── _registry/        ← Auto-generated registry.json and category indexes
│   ├── _templates/       ← Skill templates for new skills
│   ├── app-usage/        ← Claude meta-tools (skillguard, claude-md-improver)
│   ├── automation/       ← CI/CD, testing, scaffolding
│   ├── business/         ← Meetings, invoices, domain naming
│   ├── data-processing/  ← Zod validation, env config
│   ├── dev/              ← MCP servers, webapp testing
│   ├── integrations/     ← Supabase, Sentry, Firecrawl, NotebookLM, etc.
│   ├── marketing/        ← Full marketing stack (37 skills)
│   ├── optimization/     ← Token usage, LLM routing, performance
│   ├── orchestration/    ← Agent loops, RAG, execution frameworks
│   ├── research/         ← Research and content writing
│   ├── review/           ← Skill reviewer
│   ├── security/         ← Auth, CSP, RLS, hardening
│   ├── ui-ux/            ← Frontend components and design
│   └── writing/          ← Documentation, comms, resumes
└── scripts/
    ├── vault-import.sh   ← Import a new skill (bash <path> <slug> <path-to-SKILL.md> <category>)
    ├── vault-save.sh     ← Update an existing skill
    ├── vault-registry-refresh.py  ← Rebuild registry.json
    └── vault-index-refresh.py     ← Rebuild all category INDEX.md files
```

---

## Active Skill Locations

Skills are active (loaded by Claude Code) when they exist in:

1. **`~/.claude/skills/<slug>/SKILL.md`** — Direct skills, always active
2. **`~/.claude/plugins/cache/local/<plugin>/<version>/skills/<slug>/SKILL.md`** — Local plugin skills, active when plugin is enabled in settings.json
3. **Plugin marketplace installs** (via `/plugin install`) — Official plugins

Vault skills are NOT automatically active. They must be installed to one of the above locations.

---

## Adding a New Skill

1. Write the SKILL.md (use `skills/_templates/skill-template/SKILL.md` as starting point)
2. Import to vault: `bash scripts/vault-import.sh <slug> /path/to/SKILL.md <category>`
3. Install to active location:
   - Direct: `cp /path/to/SKILL.md ~/.claude/skills/<slug>/SKILL.md`
   - Or add to an existing local plugin directory
4. Rebuild indexes: `python3 scripts/vault-registry-refresh.py && python3 scripts/vault-index-refresh.py`
5. Update MASTER-INDEX.md
6. Commit: `git add -A && git commit -m "add: <slug>"`

---

## Archiving a Skill

1. `mv skills/<category>/<slug>/ skills/_archive/<slug>/`
2. Run registry and index refresh
3. Update MASTER-INDEX.md
4. Remove from `~/.claude/skills/` if installed there
5. Remove from settings.json enabledPlugins if it was a plugin

---

## Upgrading a Skill

1. Fetch new SKILL.md content
2. `bash scripts/vault-save.sh <slug> /path/to/new/SKILL.md <category>`
3. Copy updated SKILL.md to active location
4. Commit with version note

---

## Plugin Management

**Official plugins** — managed via `/plugin install` / `/plugin update`

**Local plugins** — stored in `~/.claude/plugins/cache/local/<name>/<version>/skills/`

**Enable a plugin:** Add `"<name>@local": true` to `enabledPlugins` in `~/.claude/settings.json`

**Disable a plugin:** Remove from `enabledPlugins` (plugin files remain for re-enabling)

---

## Health Check Rules

Run `skill-portfolio-architect` when:
- Active skill count exceeds 60 (current system-reminder visible skills)
- Descriptions start overlapping (ambiguous routing)
- A new major skill source is being imported
- Quarterly maintenance review

---

## Deduplication Rules

- **Plugin duplicate detected?** Archive the manual copy. Plugin wins (maintained upstream).
- **Two skills with >60% description overlap?** Merge into stronger parent skill.
- **Superpowers skill duplicated manually?** Archive the manual copy always.
- **Source skill updated upstream?** Use SOURCE-MAP.md to identify source, re-fetch, update vault.

---

## Token Efficiency Tips

- Keep descriptions precise — Claude uses them for routing decisions
- Don't load heavy skills for light tasks (see ROUTING-GUIDE.md)
- The `claude-usage-orchestrator` skill helps with runtime routing decisions
- Marketing skills are bundled in `marketing-skills@local` — if not doing marketing work, you can disable the plugin

---

_Maintained by: claude-skill-vault automation + manual curation_
_Last restructured: 2026-03-25_
