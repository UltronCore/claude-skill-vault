---
name: code-sandbox
description: Execute untrusted code safely and use AI-powered coding assistance — sandboxed execution and Aider integration
type: tool-routing
repos_absorbed: [bytedance/SandboxFusion, Aider-AI/aider]
---

# Code Sandbox

Routes code execution and AI coding tasks to the right tool.

## Routing Table

| Need | Tool |
|------|------|
| Execute untrusted code safely | SandboxFusion |
| AI pair programming in existing codebase | Aider |
| LLM benchmark evaluation (code tasks) | SandboxFusion |
| Apply AI-generated edits to repo | Aider |
| Multi-language sandboxed execution | SandboxFusion |
| Git-aware AI coding agent | Aider |

## SandboxFusion — Safe Code Execution

SandboxFusion (ByteDance) provides isolated, multi-language code execution for LLM benchmarking and untrusted code evaluation.

### Quick Start (Docker)

```bash
# Pull and run SandboxFusion server
docker pull bytedance/sandbox-fusion:latest
docker run -d -p 8080:8080 --privileged bytedance/sandbox-fusion:latest

# Or with docker-compose
git clone https://github.com/bytedance/SandboxFusion.git
cd SandboxFusion
docker compose up -d
```

### Execute Code via API

```python
import requests

SANDBOX_URL = "http://localhost:8080"

def execute_code(code: str, language: str = "python") -> dict:
    response = requests.post(f"{SANDBOX_URL}/run_code", json={
        "code": code,
        "language": language,
        "timeout": 10,  # seconds
    })
    return response.json()

# Run Python
result = execute_code("print('Hello, world!')", "python")
print(result["stdout"])  # Hello, world!
print(result["stderr"])  # (empty)
print(result["exit_code"])  # 0

# Run JavaScript
result = execute_code("console.log(2 + 2)", "javascript")

# Run with test cases (for LLM eval)
response = requests.post(f"{SANDBOX_URL}/run_code", json={
    "code": "def add(a, b): return a + b",
    "language": "python",
    "test_cases": [
        {"input": "add(1, 2)", "expected": "3"},
        {"input": "add(-1, 1)", "expected": "0"}
    ]
})
```

### Supported Languages
Python, JavaScript, TypeScript, Java, C, C++, Go, Rust, PHP, Ruby, Bash, R, Scala, Kotlin

### LLM Benchmark Mode
```python
# Evaluate LLM-generated code against test suites
response = requests.post(f"{SANDBOX_URL}/submit", json={
    "dataset": "humaneval",
    "problem_id": "HumanEval/0",
    "solution": llm_generated_code,
    "language": "python"
})
print(response.json()["passed"])  # True/False
```

### Security Properties
- Each execution runs in isolated container
- No network access by default
- Resource limits (CPU, memory, time)
- No filesystem persistence between runs

## Aider — AI Pair Programming

Aider is a terminal-based AI coding assistant that works with your existing git repo.

### Installation

```bash
pip install aider-chat
# or
pipx install aider-chat
```

### Basic Usage

```bash
# Start Aider in your repo
cd /path/to/your/project
aider

# With specific model
aider --model gpt-4o
aider --model claude-opus-4-5-20251001  # Use with Claude

# Add specific files to context
aider src/main.py tests/test_main.py

# Pass instruction directly
aider --message "Add input validation to the user registration function" src/auth.py
```

### Common Workflows

```bash
# Fix a bug
aider --message "Fix the KeyError in process_data() when key is missing" src/processor.py

# Add a feature
aider --message "Add pagination support to the /users endpoint" src/api/users.py

# Write tests
aider --message "Write pytest unit tests for all functions in utils.py" src/utils.py tests/test_utils.py

# Refactor
aider --message "Refactor this class to use composition instead of inheritance" src/models.py

# Review and explain
aider --message "Explain what this function does and suggest improvements" src/complex_algo.py
```

### Key Flags

```bash
--model MODEL          # LLM to use (gpt-4o, claude-opus-4-5-20251001, etc.)
--no-git               # Don't use git (disable auto-commit)
--yes                  # Auto-confirm all prompts
--no-auto-commits      # Make changes but don't auto-commit
--read FILE            # Add file as read-only context (no edits)
--message "..."        # Send message without interactive mode
--edit-format diff     # Use diff format for edits (default: udiff)
--cache-prompts        # Cache API calls (reduce cost on retries)
```

### Environment Setup

```bash
# Set API key (pick one)
export OPENAI_API_KEY=sk-...
export ANTHROPIC_API_KEY=sk-ant-...

# Use Claude models
aider --model claude-opus-4-6
aider --model claude-sonnet-4-6

# Use local model via Ollama
aider --model ollama/codellama:34b
```

### .aider.conf.yml (project config)

```yaml
# .aider.conf.yml in project root
model: claude-sonnet-4-6
no-auto-commits: true
read:
  - README.md
  - ARCHITECTURE.md
```

## Decision Guide

**"Run code from an LLM safely"** → SandboxFusion
**"Evaluate if LLM-generated code passes tests"** → SandboxFusion
**"Add a feature to my existing repo"** → Aider
**"Fix a bug with AI help"** → Aider
**"Write tests for existing code"** → Aider
**"Multi-language code execution in CI"** → SandboxFusion API

## Integration: Aider + Claude Code

When working inside Claude Code, use Aider for:
- Bulk edits across many files (Aider's whole-repo context)
- Applying a diff from Claude Code suggestions
- Iterative coding with automatic git commits

```bash
# Apply Claude's suggestion using Aider
aider --message "$(cat suggestion.txt)" --yes src/target.py
```

## Environment Variables

```bash
OPENAI_API_KEY=          # For Aider with GPT-4
ANTHROPIC_API_KEY=       # For Aider with Claude
SANDBOX_FUSION_URL=      # SandboxFusion server URL (default: http://localhost:8080)
```

## GitNexus Index
This skill is indexed by GitNexus for knowledge graph traversal.
Index path: /Users/localuser/claude-skill-vault/skills/misc/code-sandbox/.gitnexus
Last indexed: 2026-05-23
