# Skill Memory: Output Guardrails

## Purpose
Provides patterns for validating and constraining Claude outputs before they reach users or downstream systems. Covers guardrails-ai library, manual retry/validation loops, PII detection, and NeMo-Guardrails YAML config for topical rails.

## Category notes
Belongs in security because guardrails are a safety and compliance mechanism for LLM-powered applications, protecting against PII leakage, unsafe content, and business rule violations.

## Relationships
- Complements security-hardening-checklist (application-level security)
- Complements auth-route-protection-checker (access control)
- Often applied to outputs from any skill that generates user-facing content
- Works alongside llm-observability to log validation failures for analysis

## Maintenance notes
guardrails-ai hub validators require separate `guardrails hub install` commands per validator. NeMo-Guardrails colang syntax continues to evolve — verify flow definition syntax against current NVIDIA/NeMo-Guardrails release. The manual PII regex patterns are illustrative; production use should supplement with a dedicated PII detection library (e.g., Microsoft Presidio).
