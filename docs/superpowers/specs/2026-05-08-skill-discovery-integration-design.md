# Skill Discovery & Integration Design

_Date: 2026-05-08 | Status: Approved → In Progress_

## Objective

Find the top 100 Claude Code / AI skills not currently in the vault, download them from GitHub, and integrate them into `~/claude-skill-vault` with proper categorization and index updates. Push results to both skill vault and project vault on GitHub.

## Scope

- All domains (AI/LLM, iOS/Swift, data, productivity, orchestration, dev tools)
- Quality bar: must have name, description, usage instructions (>200 chars), no obvious malicious patterns
- Target: 100 net-new skills after deduplication against 98 existing

## Search Strategy

1. GitHub search: `claude code skills`, `claude-skills`, `CLAUDE.md skill`, `anthropic skills`
2. Known community repos: awesome-claude-code lists, claude-plugins-official community forks
3. Dedup by skill name + description similarity vs current vault

## Integration Flow

1. Parallel GitHub search agents → collect skill file URLs + metadata
2. Download raw .md skill content
3. Quality filter (>200 chars, has description + usage)
4. Deduplicate vs current 98 skills
5. Categorize into existing vault directories
6. Update MASTER-INDEX.md
7. Push: `claude-skill-vault` (skills) + `claude-project-vault` (log)

## Approved

User approved full autonomous execution on 2026-05-08. No further check-ins required.
