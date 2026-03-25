# Requesting Code Review

**Category:** review
**Status:** active
**Version:** v1
**Source:** superpowers@claude-plugins-official

## What it does
Dispatches a code-reviewer subagent with precisely crafted context (git SHAs, implementation summary, requirements) to catch issues before they compound. The reviewer gets focused context, never the session's conversation history.

## When to use
- After completing each task in subagent-driven-development
- After implementing any major feature
- Before merging to main
- When stuck and needing a fresh perspective

## What it produces
A structured review report categorizing issues as Critical, Important, or Minor, with an overall readiness assessment.

## Related skills
subagent-driven-development, receiving-code-review, executing-plans
