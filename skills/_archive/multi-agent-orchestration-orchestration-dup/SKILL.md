---
name: multi-agent-orchestration
description: Design and implement multi-agent systems where specialized AI agents collaborate to complete complex tasks. Covers orchestrator-worker patterns, parallel execution, result aggregation, error recovery, agent handoffs, and production deployment with LangGraph and CrewAI.
version: 1.0.0
tags: [multi-agent, llm, orchestration, langgraph, crewai, openai, parallel-agents, agent-handoff, ai-agents, python]
---

# Multi-Agent Orchestration

## Overview

Multi-agent systems distribute complex tasks across specialized AI agents, each optimized for a specific subtask (research, coding, review, writing). An orchestrator coordinates work — routing tasks, aggregating results, handling failures, and ensuring output quality. The key insight: many tasks that seem sequential can be parallelized or broken into sub-agents, dramatically improving quality and reducing latency through specialization and parallelism.

## When to Use

- Complex tasks that require expertise in multiple domains (write code + test + document)
- Workflows where parallel execution saves wall-clock time (research 5 topics simultaneously)
- Long-horizon tasks where a single context window isn't enough
- Quality assurance: one agent produces, another critically reviews
- Tasks requiring human-in-the-loop approval at specific checkpoints
- Replacing monolithic prompts that return inconsistent results with structured pipelines

## Step-by-Step Workflow

### 1. Orchestrator-Worker Pattern (OpenAI SDK)

```python
# pip install openai pydantic
from openai import AsyncOpenAI
from pydantic import BaseModel
import asyncio
import json

client = AsyncOpenAI()

class SubTask(BaseModel):
    task_id: str
    agent_role: str
    instruction: str
    context: str = ""

class AgentResult(BaseModel):
    task_id: str
    agent_role: str
    output: str
    success: bool
    error: str | None = None

async def run_agent(task: SubTask) -> AgentResult:
    """Run a single specialized agent."""
    system_prompts = {
        "researcher": "You are an expert researcher. Gather comprehensive, factual information.",
        "writer": "You are a skilled technical writer. Create clear, well-structured content.",
        "reviewer": "You are a critical reviewer. Find flaws, inconsistencies, and improvements.",
        "coder": "You are an expert software engineer. Write clean, well-tested code.",
    }

    system = system_prompts.get(task.agent_role, "You are a helpful assistant.")
    if task.context:
        system += f"\n\nContext from previous steps:\n{task.context}"

    try:
        response = await client.chat.completions.create(
            model="gpt-4o",
            messages=[
                {"role": "system", "content": system},
                {"role": "user", "content": task.instruction},
            ],
            temperature=0.3,
        )
        return AgentResult(
            task_id=task.task_id,
            agent_role=task.agent_role,
            output=response.choices[0].message.content or "",
            success=True,
        )
    except Exception as e:
        return AgentResult(
            task_id=task.task_id,
            agent_role=task.agent_role,
            output="",
            success=False,
            error=str(e),
        )

async def orchestrate_parallel(tasks: list[SubTask]) -> list[AgentResult]:
    """Run independent tasks in parallel."""
    results = await asyncio.gather(*[run_agent(t) for t in tasks], return_exceptions=True)
    return [r if isinstance(r, AgentResult) else AgentResult(
        task_id=tasks[i].task_id, agent_role=tasks[i].agent_role,
        output="", success=False, error=str(r)
    ) for i, r in enumerate(results)]

async def orchestrate_sequential(tasks: list[SubTask]) -> list[AgentResult]:
    """Run tasks sequentially, passing context forward."""
    results = []
    accumulated_context = ""
    for task in tasks:
        task.context = accumulated_context
        result = await run_agent(task)
        results.append(result)
        if result.success:
            accumulated_context += f"\n\n--- {task.agent_role.upper()} OUTPUT ---\n{result.output}"
    return results

# Complete blog post pipeline
async def write_blog_post(topic: str) -> str:
    # Phase 1: parallel research
    research_tasks = [
        SubTask(task_id="research_1", agent_role="researcher",
                instruction=f"Research key facts and statistics about: {topic}"),
        SubTask(task_id="research_2", agent_role="researcher",
                instruction=f"Research expert opinions and recent developments on: {topic}"),
    ]
    research_results = await orchestrate_parallel(research_tasks)
    research_context = "\n\n".join(r.output for r in research_results if r.success)

    # Phase 2: sequential write + review
    pipeline_tasks = [
        SubTask(task_id="write", agent_role="writer",
                instruction=f"Write a compelling 800-word blog post about: {topic}",
                context=research_context),
        SubTask(task_id="review", agent_role="reviewer",
                instruction="Critically review the blog post above. Identify improvements."),
        SubTask(task_id="rewrite", agent_role="writer",
                instruction="Rewrite the blog post incorporating the reviewer's feedback."),
    ]
    pipeline_results = await orchestrate_sequential(pipeline_tasks)
    return pipeline_results[-1].output if pipeline_results else ""

# Run
result = asyncio.run(write_blog_post("the future of edge computing"))
print(result)
```

### 2. LangGraph State Machine for Agent Workflows

```python
# pip install langgraph langchain-openai
from langgraph.graph import StateGraph, END
from langchain_openai import ChatOpenAI
from langchain_core.messages import HumanMessage, AIMessage, SystemMessage
from typing import TypedDict, Annotated
import operator

llm = ChatOpenAI(model="gpt-4o", temperature=0)

class ResearchState(TypedDict):
    query: str
    research: str
    outline: str
    draft: str
    review_feedback: str
    final_article: str
    revision_count: int
    messages: Annotated[list, operator.add]

def research_agent(state: ResearchState) -> ResearchState:
    response = llm.invoke([
        SystemMessage(content="You are an expert researcher. Provide comprehensive research."),
        HumanMessage(content=f"Research this topic thoroughly: {state['query']}"),
    ])
    return {"research": response.content, "revision_count": 0}

def outline_agent(state: ResearchState) -> ResearchState:
    response = llm.invoke([
        SystemMessage(content="You create clear article outlines."),
        HumanMessage(content=f"Create a detailed article outline for '{state['query']}' using this research:\n{state['research']}"),
    ])
    return {"outline": response.content}

def writer_agent(state: ResearchState) -> ResearchState:
    context = f"Research:\n{state['research']}\n\nOutline:\n{state['outline']}"
    if state.get("review_feedback"):
        context += f"\n\nPrevious review feedback to address:\n{state['review_feedback']}"
    response = llm.invoke([
        SystemMessage(content="You are an expert technical writer."),
        HumanMessage(content=f"Write a complete article about '{state['query']}' based on:\n{context}"),
    ])
    return {"draft": response.content}

def reviewer_agent(state: ResearchState) -> ResearchState:
    response = llm.invoke([
        SystemMessage(content="You are a critical editor. Be specific about improvements needed."),
        HumanMessage(content=f"Review this article:\n{state['draft']}\n\nRespond with APPROVED or NEEDS_REVISION: followed by specific feedback."),
    ])
    feedback = response.content
    return {"review_feedback": feedback, "revision_count": state["revision_count"] + 1}

def should_revise(state: ResearchState) -> str:
    """Routing: revise up to 2 times, then finalize."""
    if state["revision_count"] >= 2:
        return "finalize"
    if "APPROVED" in state["review_feedback"].upper():
        return "finalize"
    return "revise"

def finalize_agent(state: ResearchState) -> ResearchState:
    return {"final_article": state["draft"]}

# Build the graph
workflow = StateGraph(ResearchState)
workflow.add_node("research", research_agent)
workflow.add_node("outline", outline_agent)
workflow.add_node("write", writer_agent)
workflow.add_node("review", reviewer_agent)
workflow.add_node("finalize", finalize_agent)

workflow.set_entry_point("research")
workflow.add_edge("research", "outline")
workflow.add_edge("outline", "write")
workflow.add_edge("write", "review")
workflow.add_conditional_edges("review", should_revise, {
    "revise": "write",
    "finalize": "finalize",
})
workflow.add_edge("finalize", END)

app = workflow.compile()

# Run
result = app.invoke({"query": "best practices for Kubernetes security in 2025"})
print(result["final_article"])
```

### 3. CrewAI for Role-Based Teams

```python
# pip install crewai crewai-tools
from crewai import Agent, Task, Crew, Process
from crewai_tools import SerperDevTool, WebsiteSearchTool

search_tool = SerperDevTool()

# Define specialized agents
researcher = Agent(
    role="Senior Research Analyst",
    goal="Find comprehensive, up-to-date information on the given topic",
    backstory="Expert researcher with 10+ years finding insights in complex domains",
    tools=[search_tool],
    verbose=True,
    allow_delegation=False,
    llm="gpt-4o",
)

engineer = Agent(
    role="Senior Software Engineer",
    goal="Write production-quality code with tests and documentation",
    backstory="Expert programmer who writes clean, maintainable code",
    verbose=True,
    allow_delegation=False,
    llm="gpt-4o",
)

reviewer = Agent(
    role="Code Reviewer",
    goal="Find bugs, security issues, and improvement opportunities",
    backstory="Principal engineer focused on code quality and security",
    verbose=True,
    allow_delegation=False,
    llm="gpt-4o",
)

# Define tasks with context dependencies
research_task = Task(
    description="Research best practices and patterns for {topic}. Focus on production considerations.",
    expected_output="Structured research report with specific recommendations and code examples",
    agent=researcher,
)

coding_task = Task(
    description="Based on the research, implement a production-ready solution for {topic}. Include error handling and tests.",
    expected_output="Complete Python module with unit tests and docstrings",
    agent=engineer,
    context=[research_task],  # Receives researcher's output
)

review_task = Task(
    description="Review the code implementation for {topic}. Identify bugs, security issues, and improvement opportunities.",
    expected_output="Detailed code review with specific line-by-line feedback and a severity rating",
    agent=reviewer,
    context=[coding_task],
)

# Run the crew
crew = Crew(
    agents=[researcher, engineer, reviewer],
    tasks=[research_task, coding_task, review_task],
    process=Process.sequential,  # or Process.hierarchical for a manager agent
    verbose=True,
)

result = crew.kickoff(inputs={"topic": "Redis distributed locking with Lua scripts"})
print(result.raw)
```

### 4. Agent Handoffs with Tool Use

```python
# Agents that hand off to each other using tool calls
from openai import AsyncOpenAI
import asyncio, json
from typing import Callable

client = AsyncOpenAI()

async def run_agent_with_handoff(
    system: str,
    user_input: str,
    tools: list[dict],
    tool_handlers: dict[str, Callable],
) -> str:
    messages = [
        {"role": "system", "content": system},
        {"role": "user", "content": user_input},
    ]

    while True:
        response = await client.chat.completions.create(
            model="gpt-4o",
            messages=messages,
            tools=tools,
        )
        msg = response.choices[0].message
        messages.append(msg.model_dump(exclude_none=True))

        if response.choices[0].finish_reason == "stop":
            return msg.content or ""

        if response.choices[0].finish_reason == "tool_calls":
            for tc in msg.tool_calls or []:
                fn_name = tc.function.name
                fn_args = json.loads(tc.function.arguments)

                if fn_name in tool_handlers:
                    result = await tool_handlers[fn_name](**fn_args)
                    messages.append({
                        "role": "tool",
                        "tool_call_id": tc.id,
                        "content": str(result),
                    })

# Triage agent that delegates to specialists
triage_tools = [
    {"type": "function", "function": {
        "name": "delegate_to_coder",
        "description": "Hand off a coding task to the coding specialist",
        "parameters": {"type": "object", "properties": {
            "task": {"type": "string", "description": "The coding task to delegate"},
        }, "required": ["task"]},
    }},
    {"type": "function", "function": {
        "name": "delegate_to_researcher",
        "description": "Hand off a research task to the research specialist",
        "parameters": {"type": "object", "properties": {
            "query": {"type": "string"},
        }, "required": ["query"]},
    }},
]

async def coding_specialist(task: str) -> str:
    return await run_agent_with_handoff(
        system="You are an expert coder. Write complete, tested implementations.",
        user_input=task,
        tools=[],
        tool_handlers={},
    )

async def research_specialist(query: str) -> str:
    return await run_agent_with_handoff(
        system="You are an expert researcher. Provide factual, sourced information.",
        user_input=query,
        tools=[],
        tool_handlers={},
    )

triage_handlers = {
    "delegate_to_coder": coding_specialist,
    "delegate_to_researcher": research_specialist,
}

async def triage(user_request: str) -> str:
    return await run_agent_with_handoff(
        system="You are a triage agent. Analyze requests and delegate to appropriate specialists using tools.",
        user_input=user_request,
        tools=triage_tools,
        tool_handlers=triage_handlers,
    )

result = asyncio.run(triage("Write a Python function to parse RSS feeds and extract article summaries"))
```

### 5. Production Agent API with FastAPI

```python
# Production multi-agent API with job tracking
from fastapi import FastAPI, BackgroundTasks
from pydantic import BaseModel
import uuid
from enum import Enum

app = FastAPI()

class JobStatus(str, Enum):
    PENDING = "pending"
    RUNNING = "running"
    COMPLETED = "completed"
    FAILED = "failed"

class AgentJob(BaseModel):
    topic: str
    pipeline: str = "blog"  # "blog", "code", "research"

class JobResult(BaseModel):
    job_id: str
    status: JobStatus
    output: str | None = None
    error: str | None = None

jobs: dict[str, JobResult] = {}

async def run_pipeline(job_id: str, topic: str, pipeline: str):
    jobs[job_id].status = JobStatus.RUNNING
    try:
        if pipeline == "blog":
            output = await write_blog_post(topic)
        else:
            output = await run_agent(SubTask(
                task_id=job_id, agent_role="researcher", instruction=f"Research: {topic}"
            ))
            output = output.output
        jobs[job_id].status = JobStatus.COMPLETED
        jobs[job_id].output = output
    except Exception as e:
        jobs[job_id].status = JobStatus.FAILED
        jobs[job_id].error = str(e)

@app.post("/jobs", response_model=JobResult)
async def create_job(job: AgentJob, background_tasks: BackgroundTasks):
    job_id = str(uuid.uuid4())
    result = JobResult(job_id=job_id, status=JobStatus.PENDING)
    jobs[job_id] = result
    background_tasks.add_task(run_pipeline, job_id, job.topic, job.pipeline)
    return result

@app.get("/jobs/{job_id}", response_model=JobResult)
async def get_job(job_id: str):
    return jobs.get(job_id, JobResult(job_id=job_id, status=JobStatus.PENDING))
```

### 6. Agent Memory and Context Management

```python
# Persistent memory for long-running agent sessions
from dataclasses import dataclass, field
from collections import deque
import json

@dataclass
class AgentMemory:
    """Maintains conversation history and extracted facts."""
    short_term: deque = field(default_factory=lambda: deque(maxlen=20))
    facts: dict[str, str] = field(default_factory=dict)
    task_log: list[dict] = field(default_factory=list)

    def add_message(self, role: str, content: str):
        self.short_term.append({"role": role, "content": content})

    def extract_and_store_fact(self, key: str, value: str):
        self.facts[key] = value

    def get_context_window(self, max_tokens: int = 4000) -> list[dict]:
        """Return recent messages, trimming to fit token budget."""
        messages = list(self.short_term)
        # Simple token estimate: 4 chars ≈ 1 token
        while messages and sum(len(m["content"]) for m in messages) // 4 > max_tokens:
            messages.pop(0)
        return messages

    def summarize_facts(self) -> str:
        if not self.facts:
            return ""
        return "Known facts:\n" + "\n".join(f"- {k}: {v}" for k, v in self.facts.items())

    def log_task(self, agent: str, task: str, result: str, success: bool):
        self.task_log.append({"agent": agent, "task": task, "success": success, "result_preview": result[:200]})

# Use memory across multiple agent invocations
memory = AgentMemory()
memory.add_message("user", "Research the latest trends in vector databases")
memory.extract_and_store_fact("user_preference", "prefers Python examples")
```

## Key Commands Reference

```bash
# Install frameworks
pip install openai langgraph langchain-openai crewai crewai-tools
pip install pydantic asyncio fastapi uvicorn

# LangGraph visualization
pip install langgraph-cli
langgraph dev  # Local development server with graph visualization

# Monitor agent runs (LangSmith)
pip install langsmith
export LANGCHAIN_TRACING_V2=true
export LANGCHAIN_API_KEY=your-key
# All LangChain/LangGraph runs auto-traced to LangSmith

# CrewAI CLI
crewai create crew my_crew    # Scaffold a new crew project
crewai run                     # Run the crew

# OpenAI parallel batch (for high-volume offline processing)
# Use Batch API for 50% cheaper, async processing
client.batches.create(input_file_id=file_id, endpoint="/v1/chat/completions", completion_window="24h")
```

## Common Patterns

### Pattern 1: Map-Reduce Agent Pattern

```python
async def map_reduce_agents(items: list[str], reducer_prompt: str) -> str:
    """Process N items in parallel (map), then combine (reduce)."""
    # Map: process each item independently
    map_tasks = [
        SubTask(task_id=f"map_{i}", agent_role="researcher", instruction=f"Summarize: {item}")
        for i, item in enumerate(items)
    ]
    map_results = await orchestrate_parallel(map_tasks)

    # Reduce: combine all results into final answer
    combined = "\n\n".join(
        f"Item {i}: {r.output}" for i, r in enumerate(map_results) if r.success
    )
    reduce_task = SubTask(
        task_id="reduce", agent_role="writer",
        instruction=f"{reducer_prompt}\n\nInputs:\n{combined}"
    )
    reduce_result = await run_agent(reduce_task)
    return reduce_result.output
```

### Pattern 2: Self-Healing Agent with Retry

```python
async def resilient_agent(task: SubTask, max_retries: int = 3) -> AgentResult:
    """Retry failed agent tasks with exponential backoff."""
    import asyncio
    for attempt in range(max_retries):
        result = await run_agent(task)
        if result.success:
            return result
        if attempt < max_retries - 1:
            wait = 2 ** attempt  # 1s, 2s, 4s
            await asyncio.sleep(wait)
            task.instruction += f"\n\n[Attempt {attempt+2}: Previous attempt failed with: {result.error}]"
    return result
```

### Pattern 3: Human-in-the-Loop Checkpoint

```python
async def with_human_approval(task: SubTask, auto_approve: bool = False) -> AgentResult:
    """Run agent, then get human approval before proceeding."""
    result = await run_agent(task)
    if not result.success:
        return result

    if auto_approve:
        return result

    print(f"\n--- Agent Output ({task.agent_role}) ---\n{result.output}\n")
    approval = input("Approve? (y/n/edit): ").strip().lower()

    if approval == "n":
        return AgentResult(task_id=task.task_id, agent_role=task.agent_role,
                          output="", success=False, error="Rejected by human reviewer")
    elif approval == "edit":
        edited = input("Enter corrected output: ")
        result.output = edited

    return result
```

## Pitfalls to Avoid

1. **Passing entire conversation history to every agent**: Each agent only needs context relevant to its task. Passing 50k tokens of prior conversation to a reviewer agent wastes cost and degrades quality (lost in the middle problem). Pass only the specific output from the previous agent, plus any facts that are genuinely needed.

2. **No timeout or circuit breaker**: A single slow agent (network issue, very long response) blocks the entire pipeline. Always wrap `run_agent` calls with `asyncio.wait_for(run_agent(task), timeout=60)` and handle `TimeoutError` explicitly — either retry or return a partial result.

3. **Agents hallucinating success**: Without structured output validation, an agent that "completes" a task might return plausible-sounding but wrong output. Use Pydantic models or `instructor` library to enforce structured responses, and add a validation agent that checks outputs against known constraints before passing them to the next stage.

## Related Skills

- `langgraph` — Deep dive into LangGraph state machines and persistence
- `crewai` — CrewAI teams with hierarchical manager agents
- `agent-loop-patterns` — ReAct loops, chain-of-thought, and tool-use patterns
- `dispatching-parallel-agents` — Infrastructure patterns for fan-out agent execution

## GitNexus Index

```json
{
  "skill": "multi-agent-orchestration",
  "category": "ai-ml",
  "triggers": ["multi-agent", "agent orchestration", "langgraph agents", "crewai", "parallel agents", "agent handoff", "orchestrator worker", "agent pipeline"],
  "outputs": ["orchestrate_parallel", "orchestrate_sequential", "StateGraph", "Crew", "AgentResult", "AgentJob API"],
  "complexity": "high",
  "tools": ["openai", "langgraph", "crewai", "langsmith", "fastapi", "pydantic", "asyncio"]
}
```
