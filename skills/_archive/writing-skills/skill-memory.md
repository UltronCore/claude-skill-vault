# Skill Memory: Writing Skills

## Purpose
This skill applies TDD methodology to skill authoring. The RED phase requires running baseline scenarios without the skill to observe natural agent failures and rationalizations verbatim. The GREEN phase writes minimal skill content addressing those specific failures. The REFACTOR phase closes loopholes by finding new rationalizations and adding explicit counters. Claude Search Optimization (CSO) is a critical subsystem — description field must trigger on conditions, never summarize workflow.

## Category notes
Classified as app-usage because it is specifically about authoring content for the Claude Code skill system.

## Relationships
- test-driven-development: this skill is explicitly an adaptation of TDD for documentation
- skill-creator: the more comprehensive end-to-end skill creation tool that includes evals
- using-superpowers: writing-skills produces skills that using-superpowers governs

## Maintenance notes
References several supporting files (testing-skills-with-subagents.md, graphviz-conventions.dot, persuasion-principles.md, anthropic-best-practices.md, render-graphs.js) not included in this vault import.
