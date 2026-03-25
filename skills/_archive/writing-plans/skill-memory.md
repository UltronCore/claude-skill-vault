# Skill Memory: Writing Plans

## Purpose
This skill creates comprehensive implementation plans assuming zero codebase context in the executor. It requires mapping exact file paths and responsibilities before decomposing into bite-sized TDD-structured tasks (2-5 minutes per step). Plans undergo subagent review before execution, and the execution handoff offers the choice between subagent-driven-development and executing-plans.

## Category notes
Classified as orchestration because it produces the plan artifact that all implementation workflows consume.

## Relationships
- brainstorming: always the upstream skill — brainstorming produces the spec that writing-plans consumes
- subagent-driven-development: primary execution path (preferred)
- executing-plans: alternative execution path (inline/parallel session)
- using-git-worktrees: should already be set up before this skill runs (created by brainstorming)

## Maintenance notes
References plan-document-reviewer-prompt.md that is not included in this vault import.
