---
name: letta-memgpt
description: Build LLM agents with persistent memory and stateful long-term context (formerly MemGPT)
version: 1.0.0
tags: [llm, agents, memory, stateful, letta, memgpt]
---

# Letta (MemGPT) — LLM Agents with Persistent Memory

## Overview

Letta (formerly MemGPT) is a framework for building LLM agents with persistent, stateful memory that survives across conversations. It implements a hierarchical memory architecture (in-context working memory + archival storage) that lets agents remember facts, preferences, and history indefinitely. The Letta server provides a REST API for creating and managing agents, with support for multi-user deployments and tool/function calling.

GitHub: https://github.com/letta-ai/letta (14k+ stars)

## When to Use

- Chatbots that remember users across sessions
- Personal AI assistants with persistent context
- Long-running agents that accumulate knowledge over time
- Multi-turn research or task agents that need to recall prior work
- Building stateful agent applications without managing memory manually

## Installation

```bash
pip install letta

# Start Letta server (stores data locally by default)
letta server

# Or run in Docker
docker run -p 8283:8283 -v ~/.letta:/home/user/.letta lettaai/letta:latest
```

## Key Patterns / Usage

### Create and Chat with an Agent
```python
from letta import create_client

client = create_client()  # connects to local server

# Create an agent with a persona and human description
agent_state = client.create_agent(
    name="my-assistant",
    persona="I am a helpful assistant who remembers everything about you.",
    human="My name is Example User. I'm a developer who loves AI.",
    llm_config=client.get_config().default_llm_config,
    embedding_config=client.get_config().default_embedding_config,
)

print(f"Created agent: {agent_state.id}")
```

### Send Messages and Get Responses
```python
from letta import create_client

client = create_client()

# Get existing agent
agents = client.list_agents()
agent_id = agents[0].id

# Send a message
response = client.send_message(
    agent_id=agent_id,
    message="What's my name?",
    role="user",
)

# Parse the response
for message in response.messages:
    if hasattr(message, "function_call"):
        pass  # internal memory operations
    elif hasattr(message, "content"):
        print(f"Agent: {message.content}")
```

### Agent with Custom Memory Sections
```python
from letta import create_client
from letta.schemas.memory import ChatMemory

client = create_client()

# Create agent with structured memory
memory = ChatMemory(
    human="Name: Example User. Occupation: Software developer. Favorite language: Python.",
    persona="I am a coding assistant specializing in Python and AI. I remember all user preferences.",
)

agent_state = client.create_agent(
    name="coding-assistant",
    memory=memory,
)

# Update memory sections
client.update_agent(
    agent_id=agent_state.id,
    memory=ChatMemory(
        human="Name: Example User. Occupation: Software developer. Currently working on an iOS app.",
        persona=memory.persona,
    ),
)
```

### Using Archival Memory (Long-term Storage)
```python
from letta import create_client

client = create_client()
agent_id = "your-agent-id"

# Insert facts into archival memory
client.insert_archival_memory(
    agent_id=agent_id,
    memory="Example User prefers dark mode in all apps.",
)
client.insert_archival_memory(
    agent_id=agent_id,
    memory="the user's project deadline for the iOS app is June 15, 2026.",
)

# Search archival memory
results = client.get_archival_memory(
    agent_id=agent_id,
    query="deadlines",
)
for result in results:
    print(result.text)
```

### Adding Custom Tools to Agents
```python
from letta import create_client

client = create_client()

def search_documentation(query: str) -> str:
    """
    Search the project documentation for relevant information.
    
    Args:
        query: The search query string
        
    Returns:
        Relevant documentation snippets
    """
    # Your implementation here
    return f"Documentation results for: {query}"

# Register tool
tool = client.create_tool(search_documentation)

# Create agent with tool
agent_state = client.create_agent(
    name="doc-agent",
    tools=[tool.name],
)
```

### REST API Usage
```python
import httpx

BASE_URL = "http://localhost:8283"

# Create agent via API
response = httpx.post(f"{BASE_URL}/v1/agents/", json={
    "name": "api-agent",
    "llm_config": {
        "model": "gpt-4o-mini",
        "model_endpoint_type": "openai",
    },
    "embedding_config": {
        "embedding_model": "text-embedding-ada-002",
        "embedding_endpoint_type": "openai",
        "embedding_dim": 1536,
    },
})
agent_id = response.json()["id"]

# Send message
msg_response = httpx.post(
    f"{BASE_URL}/v1/agents/{agent_id}/messages",
    json={"messages": [{"role": "user", "text": "Remember that I prefer Python 3.12"}]},
)
print(msg_response.json())
```

### Multi-User Setup
```python
from letta import create_client

client = create_client()

# Create per-user agents (stateful per user)
user_agents = {}

def get_or_create_agent(user_id: str):
    if user_id not in user_agents:
        agent = client.create_agent(
            name=f"agent-{user_id}",
            human=f"User ID: {user_id}",
        )
        user_agents[user_id] = agent.id
    return user_agents[user_id]

# Chat with user-specific agent
agent_id = get_or_create_agent("user123")
response = client.send_message(
    agent_id=agent_id,
    message="My favorite color is blue.",
    role="user",
)
```

## Common Pitfalls

- **Server must be running**: `letta server` must be running before using the client SDK
- **Memory limits**: in-context memory has token limits; facts overflow to archival storage automatically
- **LLM API keys**: set `OPENAI_API_KEY` (or other provider) before starting the server
- **Agent IDs**: always persist agent IDs; losing them means losing the agent's memory handle
- **Tool schemas**: tool docstrings are parsed for parameters — keep them clear and accurate
- **Message parsing**: responses include internal memory function calls; filter for user-facing messages

## Related Skills

- `autogen` — multi-agent conversation framework (different memory model)
- `ai-agent-memory` — general patterns for agent memory
- `langchain` — alternative agent framework with memory modules
- `agent-loop-patterns` — agent loop design patterns

## GitNexus Index

```
tool: letta-memgpt
category: agent-framework
tier: self-hosted
interface: rest-api, python-sdk
platform: cross-platform
stars: 14000+
```
