# Dispatching Parallel Agents

**Category:** orchestration
**Status:** active
**Version:** v1
**Source:** superpowers@claude-plugins-official

## What it does
Identifies independent problem domains across multiple failures or tasks, then dispatches one focused subagent per domain to work concurrently. Each agent receives precisely crafted context without session history, allowing multiple investigations or implementations to happen simultaneously.

## When to use
- Three or more test files failing with different root causes
- Multiple independent subsystems broken simultaneously
- Any scenario where tasks have no shared state or sequential dependencies
- When sequential investigation would waste time on unrelated problems

## What it produces
Parallel agent summaries covering root causes and changes made, which the orchestrator integrates and verifies with a full test suite run.

## Related skills
subagent-driven-development, systematic-debugging, executing-plans
