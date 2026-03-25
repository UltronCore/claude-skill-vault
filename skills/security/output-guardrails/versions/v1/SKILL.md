---
name: output-guardrails
description: Add safety validation, output constraints, and content guardrails to Claude Code skill outputs. Use when skill outputs need to be validated against business rules, safety policies, or format constraints before being used. Trigger when users mention guardrails, output validation, safety checks, content filtering, or LLM output constraints.
---

# Output Guardrails

Guardrails validate Claude outputs before they reach users or downstream systems — catching format violations, unsafe content, or business rule breaches.

## Pattern 1: guardrails-ai (Python)
```python
pip install guardrails-ai

from guardrails import Guard
from guardrails.hub import ValidLength, RegexMatch

guard = Guard().use_many(
    ValidLength(min=10, max=500),
    RegexMatch(regex=r"^[A-Za-z0-9\s.,!?]+$", match_full=False)
)

raw_llm_output = "Claude's response here"
validated = guard.parse(raw_llm_output)
# Raises ValidationError if constraints fail
```

## Pattern 2: Manual validation layer
```python
from anthropic import Anthropic
import re

client = Anthropic()

def safe_complete(prompt: str, max_retries: int = 3) -> str:
    for attempt in range(max_retries):
        response = client.messages.create(
            model="claude-sonnet-4-6",
            max_tokens=1024,
            messages=[{"role": "user", "content": prompt}]
        )
        output = response.content[0].text

        # Custom validation
        if contains_pii(output):
            prompt += "\nIMPORTANT: Do not include personal information."
            continue
        if not is_valid_format(output):
            prompt += "\nReturn only valid JSON."
            continue
        return output

    raise ValueError("Could not generate valid output after retries")

def contains_pii(text: str) -> bool:
    patterns = [
        r'\b\d{3}-\d{2}-\d{4}\b',  # SSN
        r'\b\d{16}\b',               # Credit card
        r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b'  # Email
    ]
    return any(re.search(p, text) for p in patterns)
```

## Pattern 3: NeMo-Guardrails topical rails (YAML config)
```yaml
# config.yml
models:
  - type: main
    engine: anthropic
    model: claude-sonnet-4-6

rails:
  input:
    flows:
      - check user message
  output:
    flows:
      - check bot response

define flow check user message
  if detect jailbreak
    bot inform cannot help with this
    stop

define flow check bot response
  if response contains competitor mention
    bot rephrase response without competitor
```

## When to add guardrails
- User-facing outputs (PII, harmful content risk)
- Financial or legal content (accuracy requirements)
- Structured output pipelines (format enforcement)
- Multi-turn agents (prevent topic drift)

## Related skills
security-hardening-checklist, auth-route-protection-checker, structured-output-extraction
