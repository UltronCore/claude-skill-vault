---
name: prompt-versioning
description: >
  Prompt management, versioning, A/B testing, and evaluation tracking for production AI features. Triggers on: prompt version, prompt management, prompt registry, prompt A/B test, prompt eval, system prompt tracking.
---

# Prompt Versioning

## When to Use
- Managing multiple versions of system prompts across environments
- A/B testing two prompt variants in production
- Tracking which prompt version produced which output
- Rolling back a prompt after a regression
- Building a prompt registry for a multi-feature AI app
- Integrating with Langfuse or LangSmith for prompt observability

## Core Rules
1. Treat prompts as code — version them in git, review them in PRs, and deploy them deliberately.
2. Never hardcode prompts as inline strings in application code — externalize them to files or a registry.
3. Always log which prompt version produced each output so you can correlate versions with quality metrics.
4. Use environment variables or config to select prompt versions (`PROMPT_VERSION=v2` in staging).
5. A/B tests must be deterministic for a given user (hash user ID) — random per-request is fine for aggregate testing only.
6. Validate prompt templates before deploying — check that all `{variables}` are present in the render context.
7. Keep a CHANGELOG for each prompt in the registry — short entries explaining what changed and why.
8. Never delete old prompt versions — archive them with a `deprecated: true` flag for audit trail.
9. Evals should be automated and run against every new prompt version before promoting to production.
10. Store prompt metadata (model, temperature, max_tokens) alongside the prompt text — they are part of the prompt spec.

## Prompt-as-Code: YAML File Structure

```yaml
# prompts/summarizer/v2.yaml
name: summarizer
version: "2.1.0"
description: "Summarizes articles into bullet points. Added length constraint."
model: claude-sonnet-4-5
temperature: 0.3
max_tokens: 512
created_at: "2025-01-15"
deprecated: false

system: |
  You are an expert content summarizer. Your task is to distill articles
  into clear, actionable bullet points.

  Rules:
  - Extract only the most important information
  - Use plain language, avoid jargon
  - Limit to {max_bullets} bullet points
  - Each bullet point must be one sentence

user_template: |
  Summarize the following article:

  {article_text}

changelog:
  - version: "2.1.0"
    date: "2025-01-15"
    change: "Added max_bullets parameter for length control"
  - version: "2.0.0"
    date: "2025-01-01"
    change: "Rewrote rules for cleaner output"
  - version: "1.0.0"
    date: "2024-12-01"
    change: "Initial version"
```

## Prompt Registry (Python)

```python
import yaml
import os
import re
from pathlib import Path
from typing import Optional
from dataclasses import dataclass

@dataclass
class PromptSpec:
    name: str
    version: str
    system: str
    user_template: Optional[str]
    model: str
    temperature: float
    max_tokens: int
    metadata: dict

class PromptRegistry:
    def __init__(self, prompts_dir: str = "prompts"):
        self.prompts_dir = Path(prompts_dir)
        self._cache: dict[str, PromptSpec] = {}

    def load(self, name: str, version: str = "latest") -> PromptSpec:
        """Load a prompt by name and version."""
        cache_key = f"{name}:{version}"
        if cache_key in self._cache:
            return self._cache[cache_key]

        if version == "latest":
            # Find highest version
            versions = sorted(
                self.prompts_dir.glob(f"{name}/v*.yaml"),
                key=lambda p: [int(x) for x in re.findall(r"\d+", p.stem)],
                reverse=True,
            )
            if not versions:
                raise FileNotFoundError(f"No prompts found for '{name}'")
            path = versions[0]
        else:
            path = self.prompts_dir / name / f"{version}.yaml"

        if not path.exists():
            raise FileNotFoundError(f"Prompt not found: {path}")

        with open(path) as f:
            data = yaml.safe_load(f)

        spec = PromptSpec(
            name=data["name"],
            version=data["version"],
            system=data["system"],
            user_template=data.get("user_template"),
            model=data.get("model", "claude-sonnet-4-5"),
            temperature=data.get("temperature", 0.7),
            max_tokens=data.get("max_tokens", 1024),
            metadata=data,
        )
        self._cache[cache_key] = spec
        return spec

    def render(self, name: str, variables: dict, version: str = "latest") -> dict:
        """Load prompt, render templates, return ready-to-use dict."""
        spec = self.load(name, version)

        def render_template(template: str) -> str:
            try:
                return template.format(**variables)
            except KeyError as e:
                raise ValueError(f"Missing template variable {e} in prompt '{name}'")

        result = {
            "model": spec.model,
            "temperature": spec.temperature,
            "max_tokens": spec.max_tokens,
            "system": render_template(spec.system),
            "prompt_version": spec.version,
            "prompt_name": spec.name,
        }
        if spec.user_template:
            result["user_message"] = render_template(spec.user_template)
        return result

# Usage
registry = PromptRegistry("prompts")

# Get environment-specific version
version = os.environ.get("SUMMARIZER_PROMPT_VERSION", "latest")
rendered = registry.render("summarizer", {
    "article_text": "The quick brown fox...",
    "max_bullets": 5,
}, version=version)

print(f"Using prompt v{rendered['prompt_version']}")
```

## Git-Based Version Control

```bash
# Directory structure
prompts/
  summarizer/
    v1.yaml
    v2.yaml
    v2.1.yaml    # Current production
  classifier/
    v1.yaml
    v2.yaml      # Staged in staging

# Workflow
# 1. Create new prompt version
cp prompts/summarizer/v2.1.yaml prompts/summarizer/v2.2.yaml
# Edit v2.2.yaml

# 2. Test in development
SUMMARIZER_PROMPT_VERSION=v2.2 python test_summarizer.py

# 3. Review as PR — diffs are readable YAML
git diff prompts/summarizer/v2.1.yaml prompts/summarizer/v2.2.yaml

# 4. Deploy to staging
SUMMARIZER_PROMPT_VERSION=v2.2 deploy staging

# 5. Promote to production
SUMMARIZER_PROMPT_VERSION=v2.2 deploy production

# 6. Rollback if needed
SUMMARIZER_PROMPT_VERSION=v2.1 deploy production
```

## Environment-Based Prompt Selection

```python
import os
from prompt_registry import PromptRegistry

registry = PromptRegistry()

PROMPT_VERSIONS = {
    "development": {
        "summarizer": os.environ.get("SUMMARIZER_PROMPT_VERSION", "latest"),
        "classifier": "v1",
    },
    "staging": {
        "summarizer": "v2.2",
        "classifier": "v2",
    },
    "production": {
        "summarizer": "v2.1",  # Pinned — only change deliberately
        "classifier": "v1",
    },
}

env = os.environ.get("APP_ENV", "development")

def get_prompt(name: str, variables: dict) -> dict:
    version = PROMPT_VERSIONS[env].get(name, "latest")
    return registry.render(name, variables, version=version)
```

## A/B Test Framework

```python
import hashlib
import random
from dataclasses import dataclass

@dataclass
class ABVariant:
    name: str       # "control" or "treatment"
    prompt_version: str
    weight: float   # 0.0 to 1.0, weights must sum to 1.0

class PromptABTest:
    def __init__(self, name: str, variants: list[ABVariant]):
        assert abs(sum(v.weight for v in variants) - 1.0) < 0.001, "Weights must sum to 1.0"
        self.name = name
        self.variants = variants

    def get_variant(self, user_id: str | None = None) -> ABVariant:
        """
        If user_id is provided: deterministic assignment (same user always gets same variant).
        If no user_id: random assignment.
        """
        if user_id:
            # Hash user_id + test name for stable assignment
            hash_val = int(hashlib.md5(f"{self.name}:{user_id}".encode()).hexdigest(), 16)
            bucket = (hash_val % 10000) / 10000.0
        else:
            bucket = random.random()

        cumulative = 0.0
        for variant in self.variants:
            cumulative += variant.weight
            if bucket < cumulative:
                return variant

        return self.variants[-1]  # Fallback

# Define A/B test
summarizer_test = PromptABTest(
    name="summarizer_v2_test",
    variants=[
        ABVariant("control", "v2.1", weight=0.5),
        ABVariant("treatment", "v2.2", weight=0.5),
    ],
)

def summarize_with_ab_test(article: str, user_id: str = None) -> dict:
    variant = summarizer_test.get_variant(user_id)
    rendered = registry.render("summarizer", {"article_text": article}, variant.prompt_version)

    import anthropic
    client = anthropic.Anthropic()
    response = client.messages.create(
        model=rendered["model"],
        max_tokens=rendered["max_tokens"],
        system=rendered["system"],
        messages=[{"role": "user", "content": rendered.get("user_message", article)}],
    )

    result_text = response.content[0].text

    # Log for analysis
    log_prompt_result(
        test_name=summarizer_test.name,
        variant=variant.name,
        prompt_version=variant.prompt_version,
        input_tokens=response.usage.input_tokens,
        output_tokens=response.usage.output_tokens,
        result=result_text,
    )

    return {"text": result_text, "variant": variant.name, "version": variant.prompt_version}
```

## Prompt Result Logging

```python
import json
import datetime
import uuid
from pathlib import Path

def log_prompt_result(
    test_name: str,
    variant: str,
    prompt_version: str,
    input_tokens: int,
    output_tokens: int,
    result: str,
    user_id: str = None,
    metadata: dict = None,
    log_dir: str = "prompt_logs",
):
    Path(log_dir).mkdir(exist_ok=True)
    log_entry = {
        "id": str(uuid.uuid4()),
        "timestamp": datetime.datetime.utcnow().isoformat(),
        "test_name": test_name,
        "variant": variant,
        "prompt_version": prompt_version,
        "user_id": user_id,
        "input_tokens": input_tokens,
        "output_tokens": output_tokens,
        "result_preview": result[:200],  # Don't log full results for PII
        **(metadata or {}),
    }
    log_file = Path(log_dir) / f"{datetime.date.today()}.jsonl"
    with open(log_file, "a") as f:
        f.write(json.dumps(log_entry) + "\n")

def analyze_ab_results(log_dir: str = "prompt_logs") -> dict:
    """Aggregate A/B test results from log files."""
    from collections import defaultdict
    stats = defaultdict(lambda: {"count": 0, "input_tokens": 0, "output_tokens": 0})

    for log_file in Path(log_dir).glob("*.jsonl"):
        with open(log_file) as f:
            for line in f:
                entry = json.loads(line)
                key = f"{entry['test_name']}:{entry['variant']}"
                stats[key]["count"] += 1
                stats[key]["input_tokens"] += entry.get("input_tokens", 0)
                stats[key]["output_tokens"] += entry.get("output_tokens", 0)

    return dict(stats)
```

## Template Validation

```python
import re
import yaml

def validate_prompt_template(template: str, required_vars: list[str]) -> list[str]:
    """Check that all required variables are present in the template."""
    found_vars = set(re.findall(r"\{(\w+)\}", template))
    missing = [v for v in required_vars if v not in found_vars]
    unknown = [v for v in found_vars if v not in required_vars]
    errors = []
    if missing:
        errors.append(f"Missing required variables: {missing}")
    if unknown:
        errors.append(f"Unknown variables (not in required list): {unknown}")
    return errors

def validate_prompt_file(path: str) -> list[str]:
    """Validate a prompt YAML file."""
    with open(path) as f:
        data = yaml.safe_load(f)

    errors = []
    required_fields = ["name", "version", "system"]
    for field in required_fields:
        if field not in data:
            errors.append(f"Missing required field: {field}")

    if "user_template" in data and "variables" in data:
        template_errors = validate_prompt_template(
            data["user_template"], data.get("variables", [])
        )
        errors.extend(template_errors)

    return errors

# Run in CI/CD
import sys
errors = validate_prompt_file("prompts/summarizer/v2.2.yaml")
if errors:
    print("Prompt validation failed:")
    for e in errors:
        print(f"  - {e}")
    sys.exit(1)
print("Prompt validation passed.")
```

## Langfuse Integration

```python
# pip install langfuse
from langfuse import Langfuse
from langfuse.decorators import observe, langfuse_context
import anthropic
import os

langfuse = Langfuse(
    public_key=os.environ["LANGFUSE_PUBLIC_KEY"],
    secret_key=os.environ["LANGFUSE_SECRET_KEY"],
    host="https://cloud.langfuse.com",
)

client = anthropic.Anthropic()

@observe()  # Automatically traces this function
def summarize_with_langfuse(article: str, prompt_version: str = "v2.1") -> str:
    rendered = registry.render("summarizer", {"article_text": article}, prompt_version)

    # Track prompt version as metadata
    langfuse_context.update_current_observation(
        metadata={"prompt_version": prompt_version, "prompt_name": "summarizer"},
    )

    response = client.messages.create(
        model=rendered["model"],
        max_tokens=rendered["max_tokens"],
        system=rendered["system"],
        messages=[{"role": "user", "content": rendered.get("user_message", article)}],
    )
    return response.content[0].text

# Alternatively: use Langfuse prompt management
def use_langfuse_prompt(article: str) -> str:
    """Fetch prompt from Langfuse's prompt registry."""
    prompt_obj = langfuse.get_prompt("summarizer", version=2)  # Versioned in Langfuse
    compiled = prompt_obj.compile(article_text=article)

    response = client.messages.create(
        model="claude-sonnet-4-5",
        max_tokens=512,
        messages=[{"role": "user", "content": compiled}],
    )
    return response.content[0].text
```

## Simple Eval Runner

```python
import json
from typing import Callable

def run_prompt_eval(
    eval_cases: list[dict],
    prompt_fn: Callable[[dict], str],
    scorer_fn: Callable[[str, dict], float],
    prompt_version: str,
) -> dict:
    """
    Run a set of eval cases against a prompt function.

    eval_cases: list of {"input": ..., "expected": ..., "metadata": ...}
    prompt_fn: function(case) -> model output string
    scorer_fn: function(output, case) -> float (0.0-1.0)
    """
    results = []
    for case in eval_cases:
        output = prompt_fn(case["input"])
        score = scorer_fn(output, case)
        results.append({
            "input": case["input"],
            "expected": case.get("expected"),
            "output": output,
            "score": score,
            "passed": score >= 0.7,
        })

    passed = sum(1 for r in results if r["passed"])
    avg_score = sum(r["score"] for r in results) / len(results)

    summary = {
        "prompt_version": prompt_version,
        "total": len(results),
        "passed": passed,
        "failed": len(results) - passed,
        "pass_rate": passed / len(results),
        "avg_score": avg_score,
        "results": results,
    }

    print(f"Prompt {prompt_version}: {passed}/{len(results)} passed ({avg_score:.1%} avg score)")
    return summary

# Example usage
eval_cases = [
    {"input": "Python is a high-level language created by Guido van Rossum.", "expected_contains": "Python"},
    {"input": "The Eiffel Tower is in Paris, France.", "expected_contains": "Paris"},
]

def my_prompt_fn(text: str) -> str:
    rendered = registry.render("summarizer", {"article_text": text, "max_bullets": 3})
    import anthropic
    client = anthropic.Anthropic()
    r = client.messages.create(model="claude-haiku-4-5", max_tokens=256,
                               system=rendered["system"],
                               messages=[{"role": "user", "content": text}])
    return r.content[0].text

def contains_scorer(output: str, case: dict) -> float:
    expected = case.get("expected_contains", "")
    return 1.0 if expected.lower() in output.lower() else 0.0

results = run_prompt_eval(eval_cases, my_prompt_fn, contains_scorer, "v2.1")
```

## Prompt File Organization

```
prompts/
├── summarizer/
│   ├── v1.yaml          # Deprecated
│   ├── v2.yaml          # Previous
│   └── v2.1.yaml        # Current production
├── classifier/
│   └── v1.yaml
├── chat_assistant/
│   ├── v1.yaml
│   └── v2.yaml
└── evals/
    ├── summarizer_eval.jsonl    # Ground truth cases
    └── classifier_eval.jsonl
```

## GitNexus Index
This skill is indexed by GitNexus for knowledge graph traversal.
Index path: /Users/localuser/claude-skill-vault/skills/ai-ml/prompt-versioning/.gitnexus
Last indexed: 2026-05-23
