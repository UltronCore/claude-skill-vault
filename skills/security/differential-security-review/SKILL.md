---
name: differential-security-review
description: Analyze code diffs and PRs specifically for security implications, identifying newly introduced vulnerabilities and security regressions.
---

# Differential Security Review

## Overview
Analyze code changes (diffs, pull requests, commits) specifically for security implications. Focus attention on what changed rather than the full codebase, identifying newly introduced vulnerabilities, security regressions, and missing security controls.

## Trigger
Use when asked to security-review a PR, analyze a diff for vulnerabilities, check a commit for security issues, or perform a security-focused code review on changed code.

## Workflow

### 1. Obtain the Diff
```bash
# Compare branches
git diff main..feature-branch

# Review specific PR (with gh CLI)
gh pr diff <PR-number>

# Single commit
git show <commit-hash>

# Range of commits
git diff <base-commit>..<head-commit>
```

### 2. Categorize Changed Files
Prioritize review based on file type and location:
- **High priority**: Auth, crypto, payment, session management, input parsing
- **Medium priority**: API endpoints, data models, middleware
- **Lower priority**: UI components, tests, documentation, build configs

### 3. Security-Focused Diff Analysis

#### For each changed function/method:
- What new external input is accepted?
- What new data flows to sinks (DB, FS, shell, network)?
- Are new permissions or capabilities added?
- Are existing security controls removed or bypassed?

#### Patterns to flag:
- Removing input validation or sanitization
- Disabling authentication or authorization checks
- Adding new SQL queries without parameterization
- Introducing `eval()`, `exec()`, `system()` with non-literal args
- Deserializing untrusted data
- Weakening cryptographic operations
- Adding new dependencies with known CVEs
- Changing security-relevant configuration values
- Hardcoding secrets or credentials

### 4. Logic Change Analysis
Beyond pattern matching, reason about:
- Does the change alter the trust model? (e.g., trusting a new header)
- Does the change bypass an existing rate limit or access control?
- Are new error paths introduced that might leak sensitive info?
- Does the change introduce race conditions in security-sensitive flows?

### 5. Test Coverage Check
- Are security-relevant changes covered by tests?
- Are tests checking security invariants or just happy paths?
- Were any security tests removed or disabled?

### 6. Context-Aware Review
Pull additional context as needed:
- How is the changed function called? (callers)
- What calls the changed function? (callees)
- What is the full data flow for new inputs?

### 7. Severity Rating for Diff Findings
- **Blocker**: New exploitable vulnerability introduced
- **High**: Security regression, removed control without replacement
- **Medium**: Weakened defense-in-depth, missing security enhancement
- **Low**: Style/best-practice deviation with minor security relevance
- **Comment**: Observation or question worth discussing

## Output
PR review comments (inline where possible) or a structured diff security report with:
- Summary of security-relevant changes reviewed
- Findings by severity with line references
- Pass/Fail recommendation with justification
- Questions for the author about intent

## Related Skills
- `c-security-review` — C/C++ security review
- `semgrep-rule-creator` — custom detection rules
- `gha-security-review` — CI/CD security

## GitNexus Index
This skill is indexed by GitNexus for knowledge graph traversal.
Index path: /Users/localuser/.claude/skills/differential-security-review/.gitnexus
Last indexed: 2026-05-23
