# LLM Observability

**Category:** integrations
**Status:** active
**Version:** v1

## What it does
Adds observability, tracing, and monitoring to Claude API calls in production workflows. Covers Langfuse (open-source traces), AgentOps (agent session monitoring), MLflow (prompt experiment tracking), and a DIY JSONL tracing approach with no extra dependencies.

## When to use
- Moving a Claude workflow from prototype to production
- Debugging why a Claude-powered feature produces inconsistent results
- A/B testing different prompt versions
- Tracking cost and latency across Claude API calls
- Building audit trails for compliance

## What it produces
An instrumented Claude workflow with full trace visibility — prompts, responses, latency, token counts, and quality metrics — viewable in Langfuse, AgentOps, or MLflow dashboards.

## Related skills
- sentry-and-otel-setup (error tracking complement)
- output-guardrails (log guardrail failures as observability events)
- claude-usage-orchestrator (cost and usage tracking)
