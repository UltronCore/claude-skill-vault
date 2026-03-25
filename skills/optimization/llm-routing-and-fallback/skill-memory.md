# Skill Memory: LLM Routing and Fallback

## Purpose
Teaches Claude Code skills how to route LLM calls efficiently using litellm (Python) or Vercel AI SDK (TypeScript). Focuses on cost reduction, fallback reliability, and model tiering.

## Category notes
Belongs in optimization — the primary value is reducing API costs and improving reliability.

## Relationships
Pairs with claude-usage-orchestrator (which decides WHEN to use expensive models) — this skill handles HOW to implement the routing technically.

## Maintenance notes
Update when new Claude model IDs are released. litellm model string format: "anthropic/{model-id}".
