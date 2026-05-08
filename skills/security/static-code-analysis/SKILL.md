# Static Code Analysis

## Overview
Multi-tool static analysis skill combining CodeQL, Semgrep, and other SAST tools to systematically find security vulnerabilities and code quality issues across polyglot codebases.

## Trigger
Use when asked to run static analysis, find vulnerabilities with CodeQL or Semgrep, or perform automated security scanning of source code.

## Supported Languages
JavaScript/TypeScript, Python, Java, C/C++, Go, Ruby, C#, Swift, Kotlin

## Workflow

### 1. Tool Selection
Choose tools based on language and goal:
- **CodeQL**: Deep semantic analysis, data-flow tracking, excellent for finding injection flaws and complex vulnerability patterns
- **Semgrep**: Fast pattern-based scanning, great for custom rules, dependency checks, and quick wins
- **Bandit**: Python-specific security linting
- **ESLint security plugins**: JavaScript/TypeScript
- **gosec**: Go security checker

### 2. CodeQL Analysis
```bash
# Initialize database
codeql database create <db-path> --language=<lang> --source-root=<src>

# Run security queries
codeql database analyze <db-path> \
  --format=sarif-latest \
  --output=results.sarif \
  codeql/<lang>-queries:codeql-suites/<lang>-security-extended.qls
```

Key query suites:
- `security-and-quality` — broad coverage
- `security-extended` — deeper security checks
- Custom `.ql` files for project-specific patterns

### 3. Semgrep Analysis
```bash
# Run OWASP top 10 ruleset
semgrep --config=p/owasp-top-ten <path>

# Run language-specific security rules
semgrep --config=p/<lang> <path>

# Run all security rules
semgrep --config=p/security-audit <path>
```

### 4. Aggregating Results
- Deduplicate findings across tools
- Cross-reference with known CVEs where applicable
- Prioritize by: reachability, exploitability, data sensitivity

### 5. Triage Process
For each finding:
1. Confirm it's a true positive (not a false positive)
2. Assess exploitability in context
3. Assign severity (Critical/High/Medium/Low)
4. Write remediation recommendation

### 6. SARIF Output
Merge results into unified SARIF for GitHub Advanced Security or other SARIF viewers:
```bash
semgrep --config=auto --sarif > semgrep.sarif
```

## Output
Structured report with:
- Tool coverage summary
- Finding count by severity and tool
- Detailed findings with code snippets
- Remediation guidance per finding
- SARIF file for CI integration
