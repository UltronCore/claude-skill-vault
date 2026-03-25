# Skill Memory: UI Library Usage Auditor

## Purpose
Performs structured codebase audits of shadcn/ui component usage using Read, Grep, and Glob tools. Identifies accessibility violations (missing labels, div-as-button, missing alt text, heading hierarchy), component inconsistencies (mixed spacing, inconsistent error patterns, loading states), extraction opportunities for repeated patterns, and layout/responsiveness issues. Produces scored reports with critical/warning/suggestion tiers and file-level citations.

## Category notes
Belongs in ui-ux because its sole focus is evaluating and improving user interface code quality, accessibility compliance, and design system consistency.

## Relationships
- Audits output produced by tailwind-shadcn-ui-setup and form-generator-rhf-zod
- Findings can feed into refactoring tasks that use claude-usage-orchestrator for routing

## Maintenance notes
Uses allowed-tools: Read, Grep, Glob, Bash as declared in the skill frontmatter. Grep patterns for accessibility issues should be validated against current React/JSX conventions when updating.
