# Skill Memory: LLM Observability

## Purpose
Provides patterns for adding observability, tracing, and monitoring to Claude API calls. Covers Langfuse (open-source, self-hostable), AgentOps (agent-focused), MLflow (experiment tracking), and a minimal DIY JSONL tracing approach requiring no extra dependencies.

## Category notes
Belongs in integrations because it integrates third-party observability platforms (Langfuse, AgentOps, MLflow) into Claude Code workflows for production monitoring.

## Relationships
- Complements sentry-and-otel-setup (Sentry for errors, Langfuse/AgentOps for LLM-specific traces)
- Applies to any skill that makes Claude API calls in production
- Pairs with output-guardrails (log guardrail failures as observability events)
- Useful alongside claude-usage-orchestrator for cost tracking

## Maintenance notes
Langfuse decorator API (`@observe()`) requires langfuse>=2.0. AgentOps `record_action` decorator syntax may change — verify against current AgentOps-AI/agentops release. MLflow `log_text` requires mlflow>=1.24. The DIY JSONL approach is the most stable option as it has no external dependencies.
