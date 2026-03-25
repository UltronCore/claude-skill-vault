# SkillGuard

**Category:** app-usage
**Status:** active
**Version:** v1

## What it does
Acts as a mandatory pre-install security gate that reviews any external file, skill, config, script, or package before it is installed or activated in the Claude workflow. Performs a multi-reviewer council analysis covering technical security, prompt injection, output impact, supply chain risk, and toxic flow detection.

## When to use
- Before installing any skill, prompt pack, agent config, or plugin
- Before running any external script (shell, Python, JavaScript, etc.)
- Before importing or trusting any config file (JSON, YAML, TOML, Dockerfile, etc.)
- Any time a user says "install this", "add this skill", "run this setup", or similar

## What it produces
A full SkillGuard Security Report with risk level (Safe/Low/Medium/High/Critical), reviewer findings with OWASP LLM Top 10 codes, and an explicit APPROVE/REJECT gate requiring human decision before any action proceeds.

## Related skills
- skill-reviewer-and-enhancer (quality review for skills that pass security gate)
