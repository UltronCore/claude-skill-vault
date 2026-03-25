# Skill Memory: Requesting Code Review

## Purpose
This skill defines how to dispatch a code-reviewer subagent with precisely isolated context (git SHAs, what was implemented, requirements) rather than passing session history. It integrates into subagent-driven-development as a mandatory after-each-task step.

## Category notes
Classified as review because it governs when and how to initiate code review.

## Relationships
- subagent-driven-development: this skill is invoked after each task in SDD
- receiving-code-review: the response side of the same workflow
- executing-plans: called after each batch (every 3 tasks)

## Maintenance notes
References a template at requesting-code-review/code-reviewer.md that is not included in this vault import.
