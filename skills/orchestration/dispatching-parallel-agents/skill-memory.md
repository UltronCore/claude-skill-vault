# Skill Memory: Dispatching Parallel Agents

## Purpose
This skill defines the pattern for delegating independent problem domains to concurrent subagents. It focuses on precise context construction for each agent (never inheriting session history), grouping failures by independence, and integrating results after parallel completion. Applicable any time multiple unrelated tasks could be parallelized.

## Category notes
Classified as orchestration because it directly manages the distribution and coordination of work across multiple agents.

## Relationships
- subagent-driven-development: complementary — SDD dispatches agents sequentially per plan task; this skill dispatches truly parallel independent investigations
- systematic-debugging: frequently used together when multiple independent failures need investigation
- executing-plans: alternative for sequential task execution when parallel is not appropriate

## Maintenance notes
The real-world example (2025-10-03 debugging session) is illustrative and not personally identifying — it documents a pattern, not a specific user session.
