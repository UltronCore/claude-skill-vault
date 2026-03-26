# Skill Environment Maintenance Instructions

## Vault Health Checks
Run `skill-portfolio-architect` skill when:
- Active vault skills > 60: `find ~/claude-skill-vault/skills -name "SKILL.md" | grep -v "_archive\|/versions/" | wc -l`
- More than 10 new skills added since last audit
- Any new `misc/` catch-all appears
- Skills installed locally that aren't in vault

**Current baseline (2026-03-26):** 77 vault active, 33 installed in ~/.claude/skills/

## External Skills — Update Process
These skills are NOT in the vault (maintained by external authors):

| Skill slug(s) | Source | Update command |
|---|---|---|
| git-guardrails-claude-code, tdd, prd-to-issues, ubiquitous-language, improve-codebase-architecture, triage-issue, grill-me | mattpocock/skills | `cd /tmp && git clone --depth=1 https://github.com/mattpocock/skills mp && cp -r mp/{skill} ~/.claude/skills/{skill}` |
| office-pdf, office-docx, office-xlsx, office-pptx | LeoLin990405/claude-office-skills | `cd /tmp && git clone --depth=1 https://github.com/LeoLin990405/claude-office-skills ofs && for s in pdf docx xlsx pptx; do cp -r ofs/skills/$s ~/.claude/skills/office-$s; done` |
| agent-fetch | teng-lin/agent-fetch | `cd /tmp && git clone --depth=1 https://github.com/teng-lin/agent-fetch af && cp -r af/skills/agent-fetch ~/.claude/skills/agent-fetch` |

## Vault Skill Rules
1. No `misc/` category — every skill needs a real category
2. No local copies of plugin skills (superpowers:*, figma:*, etc.)
3. No vault copy of externally-maintained skills (see above)
4. Max 75 active vault skills (trigger audit at 60)
5. Archive before deleting — never hard-delete vault skills

## Security Flags (Do Not Reinstate)
- `marketing/developer-growth-analysis` — reads chat history + sends to Slack → QUARANTINE
- `vibeeval/vibecosystem` hooks — pre-compiled .mjs, unauditable → manual review required
- `heeyo-life/skillboss-skills` — all traffic through skillboss.co → commercial intermediary
- `SkyworkAI/Skywork-Skills` — uploads content to Alibaba OSS → data routing concern

## Discovery Sources for Future Updates
- https://github.com/karanb192/awesome-claude-skills — curated list, good for finding new skills
- https://github.com/mattpocock/skills — high quality, active, MIT
- https://github.com/anthropics/skills — official Anthropic skill library (check for new additions)

## Rollback Path
Snapshot at: `~/claude-skill-vault/_snapshots/snapshot-20260326-011425/`
- `installed-skills.txt` — 21 skills from before this session
- `vault-skills.txt` — 99 vault paths from before this session
- All archived skills recoverable from `~/claude-skill-vault/skills/_archive/`
