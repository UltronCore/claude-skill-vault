---
name: ai-agent-memory
description: Design and implement memory systems for AI agents — short-term working context, episodic memory in vector stores, entity extraction into knowledge graphs, procedural memory for learned behaviors, and memory consolidation. Covers LangGraph memory, Mem0, and custom multi-tier architectures.
version: 1.0.0
tags: [ai-agents, memory, vector-store, knowledge-graph, episodic-memory, langchain, mem0, long-term-memory, context-management]
---

# AI Agent Memory

## Overview

LLM agents have zero intrinsic memory — each API call starts fresh. Building useful agents requires designing explicit memory systems: in-context (what fits in the prompt), episodic (past conversation/event history in vector stores), semantic (facts and entities in knowledge graphs), and procedural (learned action patterns). The challenge is retrieval — storing is easy, but fetching the right memories at the right time without overwhelming the context window is an engineering problem. Multi-tier architectures mirror human memory: fast working memory (in-context), slower episodic memory (vector search), and persistent semantic memory (graph database or KV store).

## When to Use

- Agents that need to remember user preferences, past conversations, or domain knowledge
- Customer service bots that must recall previous interactions across sessions
- Research agents accumulating knowledge over many investigation steps
- Personal AI assistants with persistent user-specific context
- Coding agents that learn project conventions over time
- Any agent system where cold-start (forgetting everything between sessions) degrades quality

## Step-by-Step Workflow

### 1. In-Context Memory Management

```python
# src/agent/context_manager.py
from anthropic import Anthropic
from dataclasses import dataclass
from typing import Optional
import tiktoken

@dataclass
class Message:
    role: str   # "user" | "assistant"
    content: str
    tokens: int = 0

class ContextWindowManager:
    """Manage conversation history within token limits."""

    def __init__(self, max_tokens: int = 150_000, model: str = "claude-sonnet-4-6"):
        self.max_tokens = max_tokens
        self.reserve_for_response = 4096
        self.messages: list[Message] = []
        self.client = Anthropic()

    def count_tokens(self, text: str) -> int:
        # Rough estimate: 4 chars per token
        return len(text) // 4

    def add_message(self, role: str, content: str):
        tokens = self.count_tokens(content)
        self.messages.append(Message(role=role, content=content, tokens=tokens))
        self._trim_if_needed()

    def _trim_if_needed(self):
        """Remove oldest messages (preserving system context) when over limit."""
        total_tokens = sum(m.tokens for m in self.messages)
        budget = self.max_tokens - self.reserve_for_response

        # Always keep the last N messages for coherence
        min_keep = 4

        while total_tokens > budget and len(self.messages) > min_keep:
            # Remove oldest message (index 0)
            removed = self.messages.pop(0)
            total_tokens -= removed.tokens

    def get_messages_for_api(self) -> list[dict]:
        return [{"role": m.role, "content": m.content} for m in self.messages]

    def summarize_old_messages(self, messages_to_summarize: list[Message]) -> str:
        """Use LLM to compress old conversation into a summary."""
        transcript = "\n".join(
            f"{m.role}: {m.content}" for m in messages_to_summarize
        )
        response = self.client.messages.create(
            model="claude-haiku-4-5",  # Use cheap model for summarization
            max_tokens=512,
            messages=[{
                "role": "user",
                "content": f"Summarize this conversation in 3-5 bullet points:\n\n{transcript}"
            }],
        )
        return response.content[0].text
```

### 2. Episodic Memory with Vector Store

```python
# src/agent/episodic_memory.py
from openai import OpenAI
from qdrant_client import QdrantClient
from qdrant_client.models import Distance, VectorParams, PointStruct
from datetime import datetime
import uuid
import json

class EpisodicMemory:
    """Store and retrieve past agent experiences using semantic search."""

    def __init__(self, collection_name: str = "agent_episodes"):
        self.openai = OpenAI()
        self.qdrant = QdrantClient(url="http://localhost:6333")
        self.collection = collection_name
        self.embed_dim = 1536  # text-embedding-3-small

        # Create collection if not exists
        self._init_collection()

    def _init_collection(self):
        collections = [c.name for c in self.qdrant.get_collections().collections]
        if self.collection not in collections:
            self.qdrant.create_collection(
                self.collection,
                vectors_config=VectorParams(size=self.embed_dim, distance=Distance.COSINE),
            )

    def _embed(self, text: str) -> list[float]:
        resp = self.openai.embeddings.create(
            model="text-embedding-3-small",
            input=text,
        )
        return resp.data[0].embedding

    def store_episode(
        self,
        summary: str,
        full_transcript: str,
        user_id: str,
        metadata: dict = None,
    ):
        """Store a conversation episode with its embedding."""
        vector = self._embed(summary)
        self.qdrant.upsert(
            collection_name=self.collection,
            points=[PointStruct(
                id=str(uuid.uuid4()),
                vector=vector,
                payload={
                    "summary": summary,
                    "transcript": full_transcript,
                    "user_id": user_id,
                    "timestamp": datetime.utcnow().isoformat(),
                    **(metadata or {}),
                },
            )],
        )

    def recall_relevant(
        self,
        query: str,
        user_id: str,
        top_k: int = 5,
        score_threshold: float = 0.7,
    ) -> list[dict]:
        """Retrieve memories most relevant to the current query."""
        query_vector = self._embed(query)
        results = self.qdrant.search(
            collection_name=self.collection,
            query_vector=query_vector,
            limit=top_k,
            score_threshold=score_threshold,
            query_filter={
                "must": [{"key": "user_id", "match": {"value": user_id}}]
            },
        )

        return [
            {
                "summary": r.payload["summary"],
                "timestamp": r.payload["timestamp"],
                "relevance": r.score,
            }
            for r in results
        ]

    def format_for_prompt(self, memories: list[dict]) -> str:
        """Format recalled memories for injection into the system prompt."""
        if not memories:
            return ""
        lines = ["Relevant past conversations:"]
        for mem in memories:
            lines.append(f"- [{mem['timestamp'][:10]}] {mem['summary']} (relevance: {mem['relevance']:.2f})")
        return "\n".join(lines)
```

### 3. Entity Memory (Semantic/Factual)

```python
# src/agent/entity_memory.py
# Extract and store facts about entities mentioned in conversations
import json
from anthropic import Anthropic

class EntityMemory:
    """Store structured facts about people, places, projects, etc."""

    def __init__(self, storage_backend):
        self.client = Anthropic()
        self.storage = storage_backend  # Redis, PostgreSQL, etc.

    def extract_entities(self, conversation: str) -> list[dict]:
        """Use LLM to extract entities and facts from conversation."""
        response = self.client.messages.create(
            model="claude-haiku-4-5",
            max_tokens=1024,
            messages=[{
                "role": "user",
                "content": f"""Extract entities and facts from this conversation.
Return JSON array of objects with fields: entity_type, entity_name, facts (list of strings).
Only extract durable facts (preferences, attributes, relationships), not transient info.

Conversation:
{conversation}

Return ONLY valid JSON, no explanation."""
            }],
        )
        try:
            return json.loads(response.content[0].text)
        except json.JSONDecodeError:
            return []

    def update_entity(self, user_id: str, entity_type: str, entity_name: str, new_facts: list[str]):
        """Merge new facts with existing entity knowledge."""
        key = f"entity:{user_id}:{entity_type}:{entity_name.lower()}"
        existing = self.storage.get(key) or {"facts": []}
        existing["facts"] = list(set(existing["facts"] + new_facts))
        existing["updated_at"] = datetime.utcnow().isoformat()
        self.storage.set(key, existing)

    def get_entity_context(self, user_id: str, entity_names: list[str]) -> str:
        """Get all known facts about mentioned entities."""
        facts = []
        for name in entity_names:
            for entity_type in ["person", "project", "company", "preference"]:
                key = f"entity:{user_id}:{entity_type}:{name.lower()}"
                data = self.storage.get(key)
                if data:
                    facts.append(f"{name} ({entity_type}): {'; '.join(data['facts'])}")
        return "\n".join(facts) if facts else ""
```

### 4. Mem0 — Managed Memory Layer

```python
# pip install mem0ai
# Mem0: managed memory service that handles all tiers automatically
from mem0 import MemoryClient

memory = MemoryClient(api_key="your-mem0-api-key")

def agent_with_memory(user_id: str, user_message: str) -> str:
    """Agent that automatically stores and retrieves relevant memories."""
    # Search for relevant memories
    memories = memory.search(user_message, user_id=user_id, limit=5)
    memory_context = "\n".join(
        f"- {m['memory']}" for m in memories
    )

    system_prompt = f"""You are a helpful assistant.
{'RELEVANT MEMORIES:\n' + memory_context if memory_context else ''}"""

    response = anthropic_client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=1024,
        system=system_prompt,
        messages=[{"role": "user", "content": user_message}],
    )
    assistant_reply = response.content[0].text

    # Store the exchange as a new memory
    memory.add(
        messages=[
            {"role": "user", "content": user_message},
            {"role": "assistant", "content": assistant_reply},
        ],
        user_id=user_id,
    )

    return assistant_reply
```

## Key Commands Reference

```bash
# Mem0 Python client
pip install mem0ai

# Set up Qdrant for episodic memory
docker run -p 6333:6333 qdrant/qdrant

# Quick test of episodic memory system
python -c "
from src.agent.episodic_memory import EpisodicMemory
em = EpisodicMemory()
em.store_episode('User prefers Python, dislikes TypeScript', '...transcript...', 'user_123')
results = em.recall_relevant('What language should I use?', 'user_123')
print(results)
"

# Clear all memories for a user (GDPR deletion)
qdrant_client.delete(
    collection_name='agent_episodes',
    points_selector={'filter': {'must': [{'key': 'user_id', 'match': {'value': 'user_123'}}]}}
)
```

## Common Patterns

### Pattern 1: Hierarchical Memory Retrieval

```python
# Query multiple memory tiers in parallel, merge and rank results
async def get_relevant_context(user_id: str, query: str) -> str:
    episodic_task = asyncio.create_task(
        episodic_memory.recall_relevant(query, user_id, top_k=5)
    )
    entity_task = asyncio.create_task(
        entity_memory.get_entity_context(user_id, extract_names(query))
    )

    episodic, entity = await asyncio.gather(episodic_task, entity_task)

    parts = []
    if entity:
        parts.append(f"Known facts:\n{entity}")
    if episodic:
        parts.append(f"Past conversations:\n{episodic_memory.format_for_prompt(episodic)}")

    return "\n\n".join(parts)
```

### Pattern 2: Memory Consolidation (Forgetting Strategically)

```python
# Periodic job: summarize old episodic memories into semantic facts
# Prevents unbounded growth while preserving important knowledge
async def consolidate_memories(user_id: str, older_than_days: int = 30):
    old_memories = await episodic_memory.get_memories_older_than(user_id, older_than_days)

    if len(old_memories) < 10:
        return  # Not enough to consolidate

    # Use LLM to extract durable facts from episodic memories
    response = anthropic_client.messages.create(
        model="claude-haiku-4-5",
        max_tokens=512,
        messages=[{"role": "user", "content": f"""Extract 5-10 durable facts about this user from their conversation history.
Only include preferences, goals, constraints, and important context.

History:
{json.dumps(old_memories, indent=2)}

Return JSON list of strings."""}],
    )

    facts = json.loads(response.content[0].text)
    for fact in facts:
        entity_memory.update_entity(user_id, "user_preference", "general", [fact])

    # Archive old episodic memories to reduce storage
    await episodic_memory.archive_old(user_id, older_than_days)
```

### Pattern 3: LangGraph Persistent Memory

```python
# LangGraph with built-in checkpointing for persistent agent state
from langgraph.graph import StateGraph, MessagesState
from langgraph.checkpoint.postgres import PostgresSaver

# Checkpointer persists agent state between invocations
checkpointer = PostgresSaver.from_conn_string("postgresql://localhost/agents")

def build_agent_graph():
    workflow = StateGraph(MessagesState)
    workflow.add_node("agent", call_model)
    workflow.add_node("tools", call_tools)
    workflow.add_edge("agent", "tools")
    return workflow.compile(checkpointer=checkpointer)

graph = build_agent_graph()

# Resume a conversation — memory is automatically loaded
result = graph.invoke(
    {"messages": [{"role": "user", "content": "What did we discuss yesterday?"}]},
    config={"configurable": {"thread_id": "user_123_session_A"}},
    # thread_id is the key that persists memory across calls
)
```

## Pitfalls to Avoid

1. **Injecting all memories into every prompt**: Retrieving 50 past conversations and inserting them all into the system prompt burns tokens and dilutes the model's focus. Always use semantic search with a relevance threshold (>0.7 cosine similarity) to retrieve only what's relevant to the current query. Set a hard cap on injected memories (5-10 maximum).

2. **Storing memories without user consent or deletion capability**: Users have a right to know what's stored about them and to delete it. Build memory storage with `user_id` as a first-class field in every record, implement deletion endpoints, and respect data retention policies. GDPR requires "right to erasure" — your memory system must support bulk deletion by user ID.

3. **Conflating short-term context and long-term memory**: In-context history (the current conversation) is different from persisted episodic memory (past sessions). Mixing them causes inconsistencies — edits to in-context messages don't update the vector store, and old vector store entries may contradict current context. Treat them as separate layers with explicit handoffs: when a session ends, consolidate the in-context history into the vector store.

## Related Skills

- `rag-pipeline` — Retrieval-augmented generation patterns
- `vector-db-integration` — Vector database setup and querying
- `multi-agent-orchestration` — Memory sharing across agents
- `knowledge-graph` — Graph-based semantic memory

## GitNexus Index

```json
{
  "skill": "ai-agent-memory",
  "category": "ai",
  "triggers": ["agent memory", "AI memory system", "episodic memory", "long-term memory LLM", "Mem0", "agent context management", "vector memory agent", "entity memory", "memory consolidation", "LangGraph checkpointing", "persistent agent state"],
  "outputs": ["EpisodicMemory", "EntityMemory", "ContextWindowManager", "mem0.search()", "mem0.add()", "recall_relevant()", "consolidate_memories()", "PostgresSaver checkpointer"],
  "complexity": "high",
  "tools": ["anthropic", "openai", "qdrant", "mem0", "langgraph", "redis", "postgresql", "python"]
}
```
