# Skill Memory: SkillGuard

## Purpose
A mandatory pre-install security gate that must be invoked before any external file, skill, config, script, or package is installed or activated in the Claude workflow. Implements a multi-reviewer council model (Reviewers A through H) covering technical security, prompt/behavior analysis, output impact, dependency supply chain, execution path, data exfiltration, agentic permission abuse, and toxic flow detection. Produces a structured security report with OWASP LLM Top 10 codes and requires explicit human APPROVE/REJECT before any action proceeds. Critically, remains active and more vigilant (not less) when dangerous permission modes like bypassPermissions are active.

## Category notes
Belongs in app-usage because it governs how Claude itself is used — specifically what external content is permitted to influence Claude's behavior. It is a meta-skill about safe Claude operation rather than an integration or domain feature.

## Relationships
- Precedes skill-reviewer-and-enhancer in the skill adoption workflow: security first, then quality review
- Should trigger before importing any skill from this vault into a new project
- Foundational to the entire skill management ecosystem

## Maintenance notes
The threat catalog and report template are referenced as external files (references/threat-catalog.md, references/report-template.md, references/reviewer-guide.md) that live in the source plugin's references/ directory. Keep OWASP LLM Top 10 codes current as the standard evolves. The reviewer council structure (A-H) should be reviewed periodically for new threat categories.
