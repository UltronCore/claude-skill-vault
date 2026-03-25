# Output Guardrails

**Category:** security
**Status:** active
**Version:** v1

## What it does
Adds validation layers to Claude outputs to enforce business rules, safety policies, and format constraints. Covers the guardrails-ai library, manual retry loops with PII detection, and NeMo-Guardrails YAML configuration for topical rails.

## When to use
- Adding PII detection to user-facing Claude outputs
- Enforcing structured output formats with automatic retry
- Implementing content safety rails for agent systems
- Preventing topic drift in multi-turn conversations

## What it produces
A validated output pipeline that catches unsafe content, format violations, or PII before outputs reach users or downstream systems, with automatic retry logic where applicable.

## Related skills
- security-hardening-checklist (broader application security)
- auth-route-protection-checker (access control complement)
- llm-observability (log guardrail failures for analysis)
