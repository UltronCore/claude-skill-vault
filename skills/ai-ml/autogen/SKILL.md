---
name: autogen
description: Microsoft's multi-agent conversation framework for building collaborative AI workflows
version: 1.0.0
tags: [llm, agents, multi-agent, microsoft, autogen, conversation]
---

# AutoGen — Multi-Agent Conversation Framework

## Overview

AutoGen (Microsoft Research) is a framework for building LLM applications using multiple AI agents that collaborate through conversations. Agents can be LLM-powered, tool-enabled, or human-in-the-loop. AutoGen v0.4+ (the new AgentChat API) provides a clean async-first API with teams of agents (RoundRobinGroupChat, SelectorGroupChat) and structured message passing. Widely used for code generation, research automation, and agentic task completion.

GitHub: https://github.com/microsoft/autogen (42k+ stars)

## When to Use

- Multi-agent task completion (researcher + critic + executor pattern)
- Automated code generation and debugging loops
- Human-in-the-loop workflows with AI assistance
- Building agent teams with specialized roles
- Complex reasoning that benefits from agent debate/critique

## Installation

```bash
pip install autogen-agentchat autogen-ext[openai]

# For code execution support
pip install autogen-ext[docker]
```

## Key Patterns / Usage

### Simple Two-Agent Conversation
```python
import asyncio
from autogen_agentchat.agents import AssistantAgent
from autogen_agentchat.teams import RoundRobinGroupChat
from autogen_agentchat.conditions import TextMentionTermination
from autogen_ext.models.openai import OpenAIChatCompletionClient

async def main():
    model_client = OpenAIChatCompletionClient(model="gpt-4o-mini")
    
    # Define agents
    writer = AssistantAgent(
        name="Writer",
        model_client=model_client,
        system_message="You write Python code solutions.",
    )
    
    reviewer = AssistantAgent(
        name="Reviewer",
        model_client=model_client,
        system_message=(
            "You review code for bugs and improvements. "
            "If the code is correct and complete, say 'APPROVED'."
        ),
    )
    
    # Team with termination condition
    termination = TextMentionTermination("APPROVED")
    team = RoundRobinGroupChat([writer, reviewer], termination_condition=termination)
    
    # Run
    result = await team.run(task="Write a Python function to check if a number is prime.")
    for msg in result.messages:
        print(f"\n[{msg.source}]: {msg.content}")

asyncio.run(main())
```

### Agent with Tools
```python
import asyncio
from autogen_agentchat.agents import AssistantAgent
from autogen_ext.models.openai import OpenAIChatCompletionClient

def get_weather(city: str) -> str:
    """Get current weather for a city."""
    # Simulate weather API
    return f"Weather in {city}: 72°F, partly cloudy"

def search_web(query: str) -> str:
    """Search the web for information."""
    return f"Search results for '{query}': [simulated results]"

async def main():
    model_client = OpenAIChatCompletionClient(model="gpt-4o")
    
    agent = AssistantAgent(
        name="ToolAgent",
        model_client=model_client,
        tools=[get_weather, search_web],
        system_message="Use available tools to answer questions accurately.",
    )
    
    # Single agent run
    response = await agent.run(task="What's the weather in Paris and Tokyo?")
    print(response.messages[-1].content)

asyncio.run(main())
```

### Code Execution Agent
```python
import asyncio
from autogen_agentchat.agents import AssistantAgent, CodeExecutorAgent
from autogen_agentchat.teams import RoundRobinGroupChat
from autogen_agentchat.conditions import TextMentionTermination
from autogen_ext.code_executors.local import LocalCommandLineCodeExecutor
from autogen_ext.models.openai import OpenAIChatCompletionClient

async def main():
    model_client = OpenAIChatCompletionClient(model="gpt-4o")
    
    # Code writer agent
    code_writer = AssistantAgent(
        name="CodeWriter",
        model_client=model_client,
        system_message=(
            "Write Python code to solve the given task. "
            "Wrap code in ```python ... ``` blocks. "
            "After execution succeeds, say TASK_COMPLETE."
        ),
    )
    
    # Code executor
    executor = CodeExecutorAgent(
        name="CodeExecutor",
        code_executor=LocalCommandLineCodeExecutor(work_dir="/tmp/autogen"),
    )
    
    termination = TextMentionTermination("TASK_COMPLETE")
    team = RoundRobinGroupChat([code_writer, executor], termination_condition=termination)
    
    result = await team.run(task="Analyze the first 20 Fibonacci numbers and print their sum.")
    print(result.messages[-1].content)

asyncio.run(main())
```

### Selector Group Chat (Dynamic Agent Selection)
```python
import asyncio
from autogen_agentchat.agents import AssistantAgent
from autogen_agentchat.teams import SelectorGroupChat
from autogen_agentchat.conditions import MaxMessageTermination
from autogen_ext.models.openai import OpenAIChatCompletionClient

async def main():
    model_client = OpenAIChatCompletionClient(model="gpt-4o")
    
    researcher = AssistantAgent(
        name="Researcher",
        model_client=model_client,
        system_message="You research and gather information on topics.",
    )
    
    analyst = AssistantAgent(
        name="Analyst",
        model_client=model_client,
        system_message="You analyze data and extract insights from research.",
    )
    
    writer = AssistantAgent(
        name="Writer",
        model_client=model_client,
        system_message="You write clear, structured reports based on analysis.",
    )
    
    # Selector automatically picks the right agent
    team = SelectorGroupChat(
        [researcher, analyst, writer],
        model_client=model_client,
        termination_condition=MaxMessageTermination(10),
    )
    
    result = await team.run(task="Research and report on the current state of quantum computing.")
    for msg in result.messages:
        print(f"\n[{msg.source}]\n{msg.content}")

asyncio.run(main())
```

### Using Local Models (Ollama)
```python
from autogen_ext.models.openai import OpenAIChatCompletionClient

# Point at Ollama local server
model_client = OpenAIChatCompletionClient(
    model="llama3.2",
    base_url="http://localhost:11434/v1",
    api_key="none",
    model_capabilities={
        "vision": False,
        "function_calling": True,
        "json_output": False,
    },
)
```

### Streaming Agent Output
```python
import asyncio
from autogen_agentchat.agents import AssistantAgent
from autogen_agentchat.base import TaskResult
from autogen_ext.models.openai import OpenAIChatCompletionClient

async def main():
    model_client = OpenAIChatCompletionClient(model="gpt-4o-mini")
    agent = AssistantAgent("StreamAgent", model_client=model_client)
    
    # Stream messages as they arrive
    async for msg in agent.run_stream(task="Explain the water cycle."):
        if hasattr(msg, "content"):
            print(msg.content, end="", flush=True)
        elif isinstance(msg, TaskResult):
            print(f"\n\nFinal: {msg.stop_reason}")

asyncio.run(main())
```

## Common Pitfalls

- **Infinite loops**: always set a termination condition (`MaxMessageTermination` or `TextMentionTermination`)
- **Tool schemas**: AutoGen auto-generates tool schemas from function signatures and docstrings — keep them accurate
- **API costs**: multi-agent conversations multiply API calls; test with `gpt-4o-mini` first
- **Code execution safety**: `LocalCommandLineCodeExecutor` runs code in your environment; use Docker executor for sandboxing
- **v0.4 breaking changes**: AutoGen v0.4 (AgentChat) has a completely different API from v0.2; check which version your docs reference
- **Async required**: the new AutoGen API is async-first; use `asyncio.run()` or run inside async context

## Related Skills

- `crewai` — alternative multi-agent framework with role-based crews
- `letta-memgpt` — agents with persistent memory across sessions
- `langgraph` — graph-based agent orchestration
- `multi-agent-orchestration` — general multi-agent patterns
- `agent-loop-patterns` — agent loop design patterns

## GitNexus Index

```
tool: autogen
category: agent-framework
tier: library
interface: python-sdk
platform: cross-platform
stars: 42000+
```
