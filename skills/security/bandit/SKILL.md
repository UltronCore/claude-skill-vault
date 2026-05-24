---
name: bandit
description: Find Python security vulnerabilities with Bandit — a static analysis tool that detects common security issues in Python code like SQL injection, command injection, hardcoded secrets, use of insecure functions, and more. Use this skill whenever the user wants to audit Python code for security issues, add security linting to CI/CD, or review Python security findings. Trigger for "bandit python", "python security linting", "bandit scan", "python security audit", or "bandit security".

SAFETY NOTE: Bandit is a purely defensive static analysis tool that scans your own codebase.
---

# Bandit: Python Security Linter

Bandit is a static analysis tool for Python that finds common security issues in source code. It works by building an AST from Python code and running security checks (plugins) against it. It's a mandatory part of any Python project's security posture.

## Installation

```bash
pip install bandit

# With SARIF output support (for GitHub)
pip install bandit[sarif]

# Via pipx (recommended for global install)
pipx install bandit
```

## Basic Usage

```bash
# Scan a single file
bandit my_script.py

# Scan a directory recursively
bandit -r ./src/

# Scan with output level (HIGH only)
bandit -r ./src/ -ll  # only high confidence, high severity

# Scan and output as JSON
bandit -r ./src/ -f json -o bandit-report.json

# Verbose output with code snippets
bandit -r ./src/ -v

# Scan and set exit code based on severity
bandit -r ./src/ --exit-zero  # always exit 0 (for informational runs)
bandit -r ./src/              # exits non-zero if issues found (default)
```

## Understanding Severity and Confidence

```
>> Issue: [B608:hardcoded_sql_expressions] Possible SQL injection via string-based query construction.
   Severity: Medium   Confidence: Medium
   CWE: CWE-89 (https://cwe.mitre.org/data/definitions/89.html)
   Location: my_app/db.py:45

>> Issue: [B602:subprocess_popen_with_shell_equals_true] subprocess call with shell=True identified
   Severity: High     Confidence: High
   CWE: CWE-78
   Location: my_app/utils.py:89
```

- **Severity**: How bad the vulnerability is (LOW, MEDIUM, HIGH)
- **Confidence**: How certain Bandit is this is a real issue (LOW, MEDIUM, HIGH)
- **CWE**: Common Weakness Enumeration reference

## Common Issues Bandit Catches

### SQL Injection (B608)

```python
# BAD — Bandit flags this
def get_user(username):
    query = "SELECT * FROM users WHERE name = '" + username + "'"
    cursor.execute(query)

# GOOD — parameterized query
def get_user(username):
    query = "SELECT * FROM users WHERE name = %s"
    cursor.execute(query, (username,))
```

### Command Injection (B602, B603, B605)

```python
# BAD — shell=True with user input
import subprocess
def run_command(user_input):
    subprocess.call(user_input, shell=True)  # B602: HIGH

# BAD — os.system with user input
import os
os.system("ls " + user_input)  # B605

# GOOD — use list args, no shell
def run_command(path):
    subprocess.run(["ls", "-la", path], check=True)  # safe
```

### Hardcoded Passwords and Secrets (B105, B106, B107)

```python
# BAD — hardcoded password
password = "supersecret123"  # B105

# BAD — hardcoded in function args
def connect(host, password="admin123"):  # B107
    ...

# GOOD — load from environment
import os
password = os.environ["DB_PASSWORD"]
```

### Insecure Cryptography (B303, B304, B324)

```python
# BAD — MD5 is cryptographically broken
import hashlib
hashlib.md5(data).hexdigest()  # B324: use of weak MD5

# BAD — SHA1 weak for security purposes
hashlib.sha1(data).hexdigest()  # B324

# GOOD — use SHA-256 or better
hashlib.sha256(data).hexdigest()

# BAD — DES encryption
from Crypto.Cipher import DES  # B304

# GOOD — use AES-256 or better
from Crypto.Cipher import AES
```

### XML Vulnerabilities (B313-B320)

```python
# BAD — vulnerable to XXE (XML External Entity) attacks
from xml.etree import ElementTree
tree = ElementTree.parse("file.xml")  # B314

# GOOD — use defusedxml
import defusedxml.ElementTree
tree = defusedxml.ElementTree.parse("file.xml")

pip install defusedxml
```

### Insecure Deserialization (B301, B302)

```python
# BAD — pickle can execute arbitrary code on deserialization
import pickle
data = pickle.loads(user_input)  # B301: HIGH

# GOOD — use JSON for untrusted data
import json
data = json.loads(user_input)
```

### Random Number Security (B311)

```python
# BAD — random is not cryptographically secure
import random
token = random.randint(100000, 999999)  # B311

# GOOD — use secrets for security tokens
import secrets
token = secrets.randbelow(900000) + 100000
session_key = secrets.token_hex(32)
```

### Assert Statements (B101)

```python
# BAD — assertions can be disabled with -O flag
assert user.is_authenticated, "Must be logged in"  # B101

# GOOD — raise explicit exception
if not user.is_authenticated:
    raise PermissionError("Must be logged in")
```

## CI/CD Integration

### GitHub Actions

```yaml
# .github/workflows/bandit.yml
name: Python Security Check
on: [push, pull_request]

jobs:
  bandit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.12'

      - name: Install Bandit
        run: pip install bandit[sarif]

      - name: Run Bandit security scan
        run: |
          bandit -r src/ \
            -f sarif \
            -o bandit-results.sarif \
            --severity-level medium \
            --confidence-level medium

      - name: Upload SARIF to GitHub Security
        uses: github/codeql-action/upload-sarif@v3
        if: always()
        with:
          sarif_file: bandit-results.sarif
```

### Pre-commit Hook

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/PyCQA/bandit
    rev: 1.7.8
    hooks:
      - id: bandit
        args: ['-c', 'pyproject.toml']
        types: [python]
```

## Configuration

```toml
# pyproject.toml
[tool.bandit]
exclude_dirs = ["tests", "venv", ".venv", "migrations"]
skips = ["B101", "B404"]  # skip assert check and subprocess import
severity = "MEDIUM"
confidence = "MEDIUM"

# per-file ignores
[tool.bandit.assert_used]
skips = ["*_test.py", "*test_*.py"]
```

```ini
# .bandit (legacy config file)
[bandit]
targets: src
exclude: tests,venv
skips: B101,B404
level: 2   # HIGH only
confidence: 2  # HIGH confidence only
```

## Suppressing False Positives

```python
# Suppress with inline comment
hash_value = hashlib.md5(non_sensitive_data).hexdigest()  # nosec B324

# Or with specific test ID and reason
result = subprocess.run(  # nosec B603 -- internal tool, no user input
    ["git", "log", "--oneline"],
    capture_output=True,
    text=True,
)
```

## Useful Bandit Test IDs

| Test ID | Issue | Severity |
|---|---|---|
| B101 | assert_used | Low |
| B105 | hardcoded_password_string | Low |
| B106 | hardcoded_password_funcarg | Low |
| B301 | pickle usage | Medium |
| B303 | MD5/SHA1 use | Medium |
| B311 | random for security | Low |
| B324 | hashlib insecure | High |
| B501-B504 | SSL/TLS issues | High |
| B601 | paramiko shell | High |
| B602 | subprocess shell=True | High |
| B608 | SQL injection | Medium |
| B701 | Jinja2 autoescape | High |
| B703 | Django mark_safe | Medium |

## GitNexus Index

This skill is indexed by GitNexus for knowledge graph traversal.
Index path: /Users/localuser/.claude/skills/bandit/.gitnexus
Last indexed: 2026-05-24
