# Skill Memory: Skill Reviewer and Enhancer

## Purpose
Provides a structured 9-step workflow for comprehensively reviewing and improving Claude Code skills. Validates frontmatter structure (name conventions, description quality), scans for second-person instruction style violations, verifies domain-specific best practices across development/testing/UI/database/security domains, checks that referenced scripts/references/assets actually exist, generates a graded improvement report, and optionally applies automated fixes using the Edit tool.

## Category notes
Belongs in the review category as its sole purpose is quality assurance and improvement of other skills — it has no functional output in an application domain.

## Relationships
- Companion to skillguard: skillguard handles security review, this skill handles quality/standards review
- Applicable to any skill in the vault regardless of category
- References domain-specific best practice files (nextjs, testing, ui, database, security) that should be maintained alongside this skill

## Maintenance notes
The domain best practice references (nextjs-best-practices.md, testing-best-practices.md, etc.) are listed as resource files but are not included in the SKILL.md itself — they live in the skill's references/ directory in the source plugin. Update version numbers in domain checks (Next.js 15/16, React 19, Prisma 5+) as ecosystem evolves.
