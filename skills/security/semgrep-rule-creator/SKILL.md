# Semgrep Rule Creator

## Overview
Create custom Semgrep rules to detect project-specific vulnerability patterns, enforce security policies, and build reusable detection logic for your organization's threat model.

## Trigger
Use when asked to write Semgrep rules, create custom SAST rules, detect a specific vulnerability pattern, or build a detection library for code review automation.

## Semgrep Rule Anatomy

```yaml
rules:
  - id: rule-id
    patterns:
      - pattern: |
          <pattern-here>
    message: |
      <human-readable description>
    severity: ERROR  # ERROR, WARNING, INFO
    languages: [python, javascript, java]
    metadata:
      cwe: "CWE-89"
      owasp: "A1:2021"
      confidence: HIGH
```

## Pattern Syntax

### Basic Patterns
- `$VAR` — matches any expression, captures as metavariable
- `$...ARGS` — matches zero or more arguments (ellipsis)
- `...` — matches any sequence of statements

### Pattern Operators
- `pattern` — single pattern match
- `patterns` — all must match (AND)
- `pattern-either` — any must match (OR)
- `pattern-not` — must NOT match
- `pattern-inside` — must be inside this context
- `pattern-not-inside` — must NOT be inside this context
- `focus-metavariable` — restrict match to a specific capture

### Metavariable Conditions
```yaml
metavariable-regex:
  metavariable: $FUNC
  regex: '(exec|system|popen)'

metavariable-comparison:
  metavariable: $SIZE
  comparison: $SIZE < 0
```

## Workflow

### 1. Identify the Pattern
- Find one or more real examples of the vulnerability in code
- Determine what makes the code dangerous vs. safe
- Identify common variations and aliases

### 2. Write a Minimal Pattern
Start with the simplest pattern that matches the bad case:
```yaml
pattern: os.system($CMD)
```

### 3. Reduce False Positives
Add `pattern-not` for known-safe usages:
```yaml
patterns:
  - pattern: os.system($CMD)
  - pattern-not: os.system("ls")
  - pattern-not-inside: |
      if $SAFE:
        ...
        os.system($CMD)
```

### 4. Add Taint Tracking (for data flow)
```yaml
mode: taint
pattern-sources:
  - pattern: request.args.get(...)
pattern-sinks:
  - pattern: os.system(...)
```

### 5. Test the Rule
```bash
semgrep --config=my-rule.yaml test-cases/
semgrep --test my-rule.yaml
```

Create test files:
```python
# ruleid: my-rule
os.system(user_input)  # should match

# ok: my-rule
os.system("safe-static-command")  # should not match
```

### 6. Package for Distribution
Organize rules in a registry-compatible structure:
```
rules/
  injection/
    command-injection.yaml
    sql-injection.yaml
  crypto/
    weak-hash.yaml
```

## Output
Deliver:
- `.yaml` rule file(s) ready to run with `semgrep --config`
- Test case files demonstrating true positives and true negatives
- Brief explanation of what each rule detects and why
