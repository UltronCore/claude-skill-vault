# Repository Memory

## Purpose
This is the Claude Skill Vault — a versioned, categorized backup repository for Claude Code skills.

## Current state
- Initial import completed 2026-03-24
- All locally installed skills imported as v1 baselines
- Official superpowers skills imported as v1 baselines
- Categories established: app-usage, automation, data-processing, integrations, misc, optimization, orchestration, research, review, security, ui-ux

## Organization notes
- Category assignment is based on primary use case
- Skills with multiple uses are assigned to their dominant category
- Tags in metadata capture secondary categories

## Known relationships
- The superpowers bundle skills (brainstorming, writing-plans, dispatching-parallel-agents, etc.) form a cohesive orchestration workflow
- Supabase skills (auth-ssr, prisma, rls-policy) are related and may benefit from a dedicated subcategory if more supabase skills are added
- Security skills include both infrastructure security (CSP, RLS) and code-level security (auth routes, hardening)

## Maintenance notes
- Registry and indexes should be regenerated with scripts/vault-registry-refresh.py and scripts/vault-index-refresh.py after bulk updates
- Review structure-state.json and optimization-state.json periodically
- Consider subcategories if any category exceeds 15 skills

## Evolution
- 2026-03-24: vault created, all existing skills imported
