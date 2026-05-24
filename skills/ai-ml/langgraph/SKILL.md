# LangGraph Skill

## Overview
LangGraph is a library for building stateful, multi-actor AI applications with LLMs. It extends LangChain to support cyclic graphs, enabling sophisticated agent workflows with fine-grained control over state, flow, and memory.

## Key Concepts

### Graph Types
- **StateGraph**: Primary graph type with shared state schema across nodes
- **MessageGraph**: Simplified graph where state is a list of messages

### Core Components
- **Nodes**: Python functions or runnables that read/write state
- **Edges**: Connections between nodes (conditional or fixed)
- **State**: Typed dict schema shared across all nodes
- **Checkpointers**: Persist state between runs (memory, SQLite, Postgres)

## Basic Usage

```python
from langgraph.graph import StateGraph, END
from typing import TypedDict, Annotated
import operator

class AgentState(TypedDict):
    messages: Annotated[list, operator.add]
    next: str

def agent_node(state: AgentState):
    return {"messages": [response], "next": "tool" if needs_tool else END}

def tool_node(state: AgentState):
    return {"messages": [tool_result]}

graph = StateGraph(AgentState)
graph.add_node("agent", agent_node)
graph.add_node("tools", tool_node)
graph.set_entry_point("agent")
graph.add_conditional_edges("agent", lambda s: s["next"], {"tool": "tools", END: END})
graph.add_edge("tools", "agent")

app = graph.compile()
result = app.invoke({"messages": [HumanMessage(content="Hello")], "next": ""})
```

## ReAct Agent (Prebuilt)

```python
from langgraph.prebuilt import create_react_agent
from langchain_openai import ChatOpenAI

llm = ChatOpenAI(model="gpt-4o")
agent = create_react_agent(llm, tools=[search_tool, calculator_tool])
result = agent.invoke({"messages": [("user", "What is 2+2?")]})
```

## Persistence / Memory

```python
from langgraph.checkpoint.memory import MemorySaver
from langgraph.checkpoint.sqlite import SqliteSaver

checkpointer = SqliteSaver.from_conn_string("checkpoints.db")
app = graph.compile(checkpointer=checkpointer)

config = {"configurable": {"thread_id": "user-123"}}
result = app.invoke(input, config=config)
```

## Human-in-the-Loop

```python
from langgraph.graph import interrupt

def approval_node(state):
    decision = interrupt("Approve this action? (yes/no)")
    return {"approved": decision == "yes"}

app = graph.compile(checkpointer=checkpointer, interrupt_before=["approval"])
app.invoke(Command(resume="yes"), config=config)
```

## Streaming

```python
for chunk in app.stream(input, stream_mode="values"):
    print(chunk)

async for chunk in app.astream(input):
    print(chunk)
```

## Installation

```bash
pip install langgraph
pip install langgraph-checkpoint-sqlite
pip install langgraph-checkpoint-postgres
```

## Key Tips
- Use `Annotated[list, operator.add]` for accumulating state fields
- Always compile with `checkpointer` for stateful/conversational apps
- Use `interrupt_before`/`interrupt_after` for human-in-the-loop workflows
- Sub-graphs can be compiled and used as nodes in parent graphs
- Fan-out to parallel nodes: `graph.add_edge("start", ["node_a", "node_b"])`

## GitNexus Index
This skill is indexed by GitNexus for knowledge graph traversal.
Index path: /Users/localuser/claude-skill-vault/skills/ai-ml/langgraph/.gitnexus
Last indexed: 2026-05-23
