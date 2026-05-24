---
name: prompt-chaining
description: Build reliable multi-step LLM pipelines using prompt chaining — decomposing complex tasks into sequential prompts where each output feeds the next. Covers gate conditions, parallel chains, and error handling.
version: 1.0.0
tags: [llm, prompt-chaining, pipeline, orchestration, langchain, anthropic, openai, multi-step]
---

# Prompt Chaining

## Overview

This skill covers designing and implementing prompt chains — sequences of LLM calls where each step's output becomes the next step's input. Chaining solves tasks too complex or unreliable for a single prompt by decomposing them into smaller, verifiable sub-tasks. It covers sequential chains, parallel fans, gate conditions, retry logic, and debugging failing chains. Applicable to any LLM provider.

## When to Use

- Complex reasoning tasks that exceed a single prompt's reliable capability
- Multi-stage document processing (extract → classify → transform → validate)
- Research workflows (search → summarize → synthesize → format)
- Code generation with review (generate → test → critique → refine)
- Any task where intermediate results need to be validated before continuing

## Step-by-Step Workflow

### 1. Simple Sequential Chain
```python
from anthropic import Anthropic
from typing import Optional

client = Anthropic()

def llm_call(prompt: str, system: str = "", model: str = "claude-sonnet-4-6") -> str:
    response = client.messages.create(
        model=model,
        max_tokens=2048,
        system=system or "You are a helpful assistant.",
        messages=[{"role": "user", "content": prompt}],
    )
    return response.content[0].text

# Chain: Research → Outline → Draft → Edit
def write_article_chain(topic: str) -> str:
    # Step 1: Research key points
    research = llm_call(
        f"List 5 key facts and insights about: {topic}. Be specific and cite examples.",
        system="You are a research analyst. Focus on accuracy.",
    )
    print(f"Research complete: {len(research)} chars")
    
    # Step 2: Create outline from research
    outline = llm_call(
        f"Create a 5-section article outline based on these research points:\n\n{research}",
        system="You are an editor. Create logical, compelling outlines.",
    )
    print(f"Outline complete: {len(outline)} chars")
    
    # Step 3: Write draft from outline
    draft = llm_call(
        f"Write a 600-word article following this outline:\n\n{outline}\n\nOriginal research:\n{research}",
        system="You are a professional writer. Be clear, engaging, and informative.",
    )
    print(f"Draft complete: {len(draft)} chars")
    
    # Step 4: Edit for quality
    final = llm_call(
        f"Edit this article for clarity, flow, and impact. Fix any issues:\n\n{draft}",
        system="You are a copy editor. Improve quality without changing facts.",
    )
    return final

article = write_article_chain("the future of quantum computing")
```

### 2. Chain with Gate Conditions
```python
def process_with_gate(text: str) -> dict:
    """Only proceed if quality gates pass."""
    
    # Step 1: Extract data
    extracted = llm_call(
        f"Extract all key entities (people, companies, amounts, dates) from:\n\n{text}",
        system="Extract precisely. Return JSON.",
    )
    
    # Gate 1: Validate extraction quality
    validation = llm_call(
        f"Review this extraction for completeness and accuracy. Reply with only 'PASS' or 'FAIL: <reason>'.\n\nOriginal text: {text}\n\nExtraction: {extracted}",
    )
    
    if validation.startswith("FAIL"):
        # Retry with feedback
        extracted = llm_call(
            f"Re-extract entities. Previous attempt failed: {validation}\n\nText:\n{text}",
        )
    
    # Step 2: Classify entities
    classified = llm_call(
        f"Classify each entity by type and importance (high/medium/low):\n\n{extracted}",
    )
    
    # Gate 2: Check minimum entities
    entity_count_check = llm_call(
        f"Count the total entities in this output. Reply with only a number:\n{classified}",
    )
    
    try:
        count = int(entity_count_check.strip())
        if count < 3:
            return {"status": "insufficient_data", "count": count, "data": classified}
    except ValueError:
        pass
    
    # Step 3: Generate summary
    summary = llm_call(
        f"Write a concise executive summary based on:\n\nEntities: {classified}\n\nOriginal: {text}",
    )
    
    return {"status": "success", "entities": classified, "summary": summary}
```

### 3. Parallel Chain (Fan-Out / Fan-In)
```python
import asyncio
from anthropic import AsyncAnthropic

async_client = AsyncAnthropic()

async def llm_call_async(prompt: str, system: str = "") -> str:
    response = await async_client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=1024,
        system=system,
        messages=[{"role": "user", "content": prompt}],
    )
    return response.content[0].text

async def parallel_analysis_chain(document: str) -> dict:
    """Analyze document from multiple angles simultaneously."""
    
    # Fan-out: run 4 analyses in parallel
    results = await asyncio.gather(
        llm_call_async(
            f"Summarize in 3 sentences:\n{document}",
            "Be concise and accurate.",
        ),
        llm_call_async(
            f"Identify risks and concerns in:\n{document}",
            "Be thorough about risks.",
        ),
        llm_call_async(
            f"Extract action items from:\n{document}",
            "Focus on what needs to be done.",
        ),
        llm_call_async(
            f"What questions does this raise? List 5:\n{document}",
            "Think critically.",
        ),
    )
    
    summary, risks, actions, questions = results
    
    # Fan-in: synthesize all analyses
    synthesis = await llm_call_async(
        f"""Synthesize these analyses into a coherent executive briefing:

SUMMARY: {summary}

RISKS: {risks}

ACTIONS: {actions}

OPEN QUESTIONS: {questions}""",
        "Create a cohesive, decision-ready briefing.",
    )
    
    return {
        "summary": summary,
        "risks": risks,
        "actions": actions,
        "questions": questions,
        "synthesis": synthesis,
    }

# Run
result = asyncio.run(parallel_analysis_chain(document_text))
```

### 4. Iterative Refinement Chain
```python
def iterative_code_chain(requirements: str, max_iterations: int = 3) -> str:
    """Generate code, test it conceptually, refine until passing."""
    
    # Initial generation
    code = llm_call(
        f"Write Python code for: {requirements}",
        "Write clean, production-ready Python with docstrings.",
    )
    
    for iteration in range(max_iterations):
        # Review code
        review = llm_call(
            f"""Review this code for bugs, edge cases, and improvements.
Return JSON: {{"score": 1-10, "issues": [...], "verdict": "PASS" or "NEEDS_WORK"}}

Requirements: {requirements}

Code:
```python
{code}
```""",
        )
        
        # Parse verdict
        import json, re
        try:
            review_data = json.loads(re.search(r'\{.*\}', review, re.DOTALL).group())
            if review_data.get("verdict") == "PASS" or review_data.get("score", 0) >= 8:
                print(f"Code approved on iteration {iteration + 1}")
                break
            
            # Refine with feedback
            issues_str = "\n".join(f"- {i}" for i in review_data.get("issues", []))
            code = llm_call(
                f"""Improve this code addressing these issues:
{issues_str}

Original requirements: {requirements}

Current code:
```python
{code}
```""",
                "Fix the identified issues while maintaining functionality.",
            )
        except (json.JSONDecodeError, AttributeError):
            break
    
    return code
```

### 5. Chain with Structured State
```python
from dataclasses import dataclass, field
from typing import Optional

@dataclass
class ChainState:
    """Typed state passed through the chain."""
    raw_input: str
    extracted_data: dict = field(default_factory=dict)
    enriched_data: dict = field(default_factory=dict)
    final_output: Optional[str] = None
    errors: list[str] = field(default_factory=list)
    metadata: dict = field(default_factory=dict)

def run_extraction_chain(raw_text: str) -> ChainState:
    state = ChainState(raw_input=raw_text)
    
    try:
        # Step 1: Extract
        extracted_json = llm_call(
            f"Extract structured data from this text as JSON:\n{raw_text}"
        )
        import json
        state.extracted_data = json.loads(extracted_json)
        state.metadata["extraction_tokens"] = len(extracted_json)
        
    except Exception as e:
        state.errors.append(f"Extraction failed: {e}")
        return state
    
    try:
        # Step 2: Enrich
        enriched_json = llm_call(
            f"Enrich this data with derived fields (sentiment, category, priority):\n{extracted_json}"
        )
        state.enriched_data = json.loads(enriched_json)
        
    except Exception as e:
        state.errors.append(f"Enrichment failed: {e}")
        # Continue with just extracted data
    
    # Step 3: Format for output
    state.final_output = llm_call(
        f"Format this data as a human-readable summary:\n{state.enriched_data or state.extracted_data}"
    )
    
    return state
```

## Key Commands Reference

```bash
# LangChain for managed chains
pip install langchain langchain-anthropic

from langchain_anthropic import ChatAnthropic
from langchain_core.prompts import ChatPromptTemplate
from langchain_core.output_parsers import StrOutputParser

model = ChatAnthropic(model="claude-sonnet-4-6")
parser = StrOutputParser()

# Pipe operator for clean chain syntax
chain = ChatPromptTemplate.from_template("Research: {topic}") | model | parser

# Sequential chain
full_chain = (
    ChatPromptTemplate.from_template("Research: {topic}") | model | parser
    | (lambda research: {"research": research, "topic": topic})
    | ChatPromptTemplate.from_template("Summarize: {research}") | model | parser
)
```

## Common Patterns

### Pattern 1: Chain-of-Thought Gate
```python
def cot_verified_answer(question: str) -> tuple[str, str]:
    """Get answer with chain-of-thought reasoning, then verify."""
    reasoning = llm_call(
        f"Think step-by-step to answer: {question}\n\nShow your reasoning.",
    )
    
    answer = llm_call(
        f"Based on this reasoning:\n{reasoning}\n\nGive a concise final answer to: {question}",
    )
    
    # Verify reasoning matches answer
    verification = llm_call(
        f"Does this answer logically follow from the reasoning? Answer YES or NO.\n\nReasoning: {reasoning}\nAnswer: {answer}",
    )
    
    if "NO" in verification:
        # Re-derive from scratch
        answer = llm_call(f"Answer directly and carefully: {question}")
    
    return answer, reasoning
```

### Pattern 2: Branching Chain
```python
def classify_then_handle(input_text: str) -> str:
    category = llm_call(
        f"Classify as 'bug', 'feature', or 'question': {input_text}. Reply with one word only."
    ).strip().lower()
    
    handlers = {
        "bug": lambda t: llm_call(f"Write a bug report for: {t}", "Focus on reproduction steps."),
        "feature": lambda t: llm_call(f"Write a feature spec for: {t}", "Focus on user value."),
        "question": lambda t: llm_call(f"Answer clearly: {t}", "Be direct and helpful."),
    }
    
    handler = handlers.get(category, handlers["question"])
    return handler(input_text)
```

### Pattern 3: Map-Reduce Chain
```python
def map_reduce_chain(documents: list[str], question: str) -> str:
    # Map: summarize each document
    summaries = [
        llm_call(f"Summarize key info relevant to '{question}':\n{doc}")
        for doc in documents
    ]
    
    # Reduce: synthesize all summaries
    combined = "\n\n---\n\n".join(f"Doc {i+1}: {s}" for i, s in enumerate(summaries))
    return llm_call(
        f"Answer '{question}' using these document summaries:\n\n{combined}",
        "Synthesize across all sources. Cite which document supports each point.",
    )
```

## Pitfalls to Avoid

1. **No intermediate validation**: Blindly passing output from step N to step N+1 amplifies errors. Add gate prompts that check output quality before continuing. A bad extraction produces a bad summary produces a wrong final answer — validate at each boundary.

2. **Context window overflow**: Passing full outputs through every step grows context rapidly. After 5-6 steps with long outputs, you may hit limits. Summarize intermediate outputs before passing them forward: don't carry the full chain history into every step.

3. **Not logging chain steps**: Debugging chains requires seeing every intermediate output. Log each step's input/output to a structured store (file, DB, Langfuse). Production chains without logging are impossible to debug when they fail silently at step 3 of 7.

## Related Skills

- `structured-generation` — Validated output at each chain step
- `streaming-llm-responses` — Streaming long chain outputs
- `llm-prompt-optimizer` — Optimizing individual prompts in a chain
- `langgraph` — State machines for complex branching chains

## GitNexus Index

```json
{
  "skill": "prompt-chaining",
  "category": "ai-ml",
  "triggers": ["prompt chain", "LLM pipeline", "multi-step LLM", "chain of prompts", "orchestration LLM", "sequential prompts"],
  "outputs": ["chain implementation", "gate condition", "parallel chain", "refinement loop"],
  "complexity": "medium",
  "tools": ["anthropic", "openai", "langchain", "asyncio"]
}
```
