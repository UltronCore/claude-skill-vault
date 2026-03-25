# Public Safety Policy

This repository is designed for future public release. All content must comply with this policy before being committed.

## What is allowed

- Skill instructions and prompts
- Generic workflow descriptions
- Public-safe operational memory files
- Example commands using placeholder values
- Documentation referencing generic paths like `/path/to/project`

## What is not allowed

- Personal names, usernames, or identity details
- Machine-specific file paths (e.g., `/Users/specificname/`)
- API keys, tokens, secrets, or credentials of any kind
- Private repository URLs or internal endpoint URLs
- Personal notes unrelated to skill operation
- Travel details, personal schedules, or private routines
- Sensitive system configuration details

## Handling violations

Before any commit:
1. Review all modified files for disallowed content
2. Replace personal paths with `/Users/{user}/` or `/path/to/...`
3. Redact credentials entirely — do not partially mask
4. Remove personal notes from skill-memory.md files
5. Set `public_safe: false` in metadata.json if content cannot be fully sanitized
6. Do not push any file with `public_safe: false` until resolved

## Memory file rules

Memory files (skill-memory.md, category-memory.md, repo-memory.md, etc.) must only contain:
- Operational notes about skill purpose and function
- Category organization rationale
- Relationship notes between skills
- Maintenance and evolution notes

Memory files must never contain personal details of any kind.

## Enforcement

Every skill import, update, optimization, or reorganization must include a safety review pass before committing. The `scripts/vault-check.sh` script automates basic checks.
