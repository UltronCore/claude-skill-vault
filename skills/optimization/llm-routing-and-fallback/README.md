# LLM Routing and Fallback

**Category:** optimization
**Status:** active
**Version:** v1

## What it does
Provides patterns for routing LLM API calls through cost-efficient proxy layers with automatic model fallback, budget enforcement, and multi-provider support.

## When to use
- Building tools that need model-switching without code changes
- Enforcing API spend caps
- Tiering model quality by task complexity
- Unifying Claude + other LLMs behind one interface

## What it produces
Working code patterns for litellm (Python) and Vercel AI SDK (TypeScript) integration.

## Related skills
claude-usage-orchestrator, sentry-and-otel-setup
