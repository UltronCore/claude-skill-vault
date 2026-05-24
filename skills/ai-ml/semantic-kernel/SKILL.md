---
name: semantic-kernel
description: Microsoft's AI orchestration SDK for integrating LLMs into .NET, Python, and Java apps
version: 1.0.0
tags: [llm, orchestration, microsoft, dotnet, python, plugins, agents]
---

# Semantic Kernel — Microsoft AI Orchestration SDK

## Overview

Semantic Kernel (SK) is Microsoft's open-source AI orchestration SDK for building enterprise AI applications in .NET, Python, and Java. It provides a plugin architecture where native functions and LLM prompts are treated as interchangeable "skills," enabling composable AI pipelines. Features include automatic function calling, memory (vector stores), planning, and agent patterns. Used heavily in Microsoft 365 Copilot and Azure AI integrations.

GitHub: https://github.com/microsoft/semantic-kernel (24k+ stars)

## When to Use

- Building AI features in .NET/C# enterprise applications
- LLM orchestration with structured plugins and function calling
- Integrating AI into existing Microsoft stack (Azure OpenAI, Teams, M365)
- Composable prompt pipelines with memory and tool use
- Production AI with enterprise patterns (retry, telemetry, DI)

## Installation

```bash
# Python
pip install semantic-kernel

# .NET
dotnet add package Microsoft.SemanticKernel
```

## Key Patterns / Usage

### Basic Kernel Setup (Python)
```python
import asyncio
from semantic_kernel import Kernel
from semantic_kernel.connectors.ai.open_ai import OpenAIChatCompletion
from semantic_kernel.connectors.ai.function_choice_behavior import FunctionChoiceBehavior

async def main():
    kernel = Kernel()
    
    # Add AI service
    kernel.add_service(
        OpenAIChatCompletion(
            service_id="chat",
            ai_model_id="gpt-4o-mini",
            api_key="your-api-key",
        )
    )
    
    # Simple invocation
    result = await kernel.invoke_prompt(
        "What is the capital of {{$country}}?",
        country="France",
    )
    print(result)

asyncio.run(main())
```

### Plugin with Native Functions
```python
from semantic_kernel.functions import kernel_function
from semantic_kernel.plugin_definition import kernel_plugin_definition

@kernel_plugin_definition
class WeatherPlugin:
    @kernel_function(description="Get current weather for a city")
    def get_weather(self, city: str) -> str:
        """Get weather information for the specified city."""
        # Simulate API call
        return f"Weather in {city}: 72°F, partly cloudy"
    
    @kernel_function(description="Convert temperature from Celsius to Fahrenheit")
    def celsius_to_fahrenheit(self, celsius: float) -> float:
        return (celsius * 9/5) + 32

# Register and use
kernel.add_plugin(WeatherPlugin(), plugin_name="Weather")

result = await kernel.invoke_prompt(
    "What's the weather in Tokyo and convert 25°C to Fahrenheit?",
    settings=OpenAIChatPromptExecutionSettings(
        function_choice_behavior=FunctionChoiceBehavior.Auto(),
    ),
)
```

### Memory and Vector Store
```python
from semantic_kernel.memory import SemanticTextMemory
from semantic_kernel.connectors.memory.chroma import ChromaMemoryStore

memory = SemanticTextMemory(
    storage=ChromaMemoryStore(host="localhost", port=8000),
    embeddings_generator=kernel.get_service("embedding"),
)

# Save memories
await memory.save_information(
    collection="company-docs",
    id="policy-001",
    text="Our return policy allows 30-day returns for all products.",
)

# Search
results = await memory.search(
    collection="company-docs",
    query="return policy",
    limit=3,
)
for result in results:
    print(f"[{result.relevance:.2f}] {result.text}")
```

### Chat Completion with History
```python
from semantic_kernel.contents import ChatHistory
from semantic_kernel.connectors.ai.open_ai import OpenAIChatPromptExecutionSettings

async def chat():
    kernel = Kernel()
    kernel.add_service(OpenAIChatCompletion(service_id="chat", ai_model_id="gpt-4o-mini"))
    chat_service = kernel.get_service("chat")
    
    history = ChatHistory()
    history.add_system_message("You are a helpful coding assistant.")
    
    while True:
        user_input = input("You: ")
        if user_input == "exit":
            break
            
        history.add_user_message(user_input)
        
        result = await chat_service.get_chat_message_content(
            chat_history=history,
            settings=OpenAIChatPromptExecutionSettings(max_tokens=500),
        )
        
        print(f"Assistant: {result}")
        history.add_assistant_message(str(result))
```

### Azure OpenAI Integration
```python
from semantic_kernel.connectors.ai.open_ai import AzureChatCompletion

kernel.add_service(
    AzureChatCompletion(
        service_id="azure-chat",
        deployment_name="gpt-4o",
        endpoint="https://your-resource.openai.azure.com",
        api_key="your-azure-key",
    )
)
```

### .NET / C# Quick Start
```csharp
using Microsoft.SemanticKernel;

var builder = Kernel.CreateBuilder();
builder.AddOpenAIChatCompletion("gpt-4o-mini", "your-api-key");

var kernel = builder.Build();

// Invoke prompt
var result = await kernel.InvokePromptAsync(
    "Summarize: {{$content}}",
    new KernelArguments { ["content"] = longText }
);
Console.WriteLine(result);

// With plugin
kernel.ImportPluginFromType<WeatherPlugin>();
var response = await kernel.InvokePromptAsync(
    "What's the weather in Paris?",
    new KernelArguments(),
    executionSettings: new OpenAIPromptExecutionSettings {
        ToolCallBehavior = ToolCallBehavior.AutoInvokeKernelFunctions
    }
);
```

### Agents (AutoGen-style)
```python
from semantic_kernel.agents import ChatCompletionAgent
from semantic_kernel.agents.group_chat import AgentGroupChat

agent1 = ChatCompletionAgent(
    service_id="chat",
    kernel=kernel,
    name="Writer",
    instructions="You write creative content.",
)

agent2 = ChatCompletionAgent(
    service_id="chat",
    kernel=kernel,
    name="Critic",
    instructions="You critique content and suggest improvements. Say APPROVED when done.",
)

group_chat = AgentGroupChat(agents=[agent1, agent2])
async for response in group_chat.invoke(task="Write a tagline for an AI company."):
    print(f"[{response.name}]: {response.content}")
```

## Common Pitfalls

- **Service ID required**: every service needs a unique `service_id`; multiple services need explicit selection
- **Async throughout**: SK Python is async-first; wrap in `asyncio.run()` or use async context
- **Plugin naming**: function names must be unique within a plugin; plugin names must be unique in kernel
- **Rate limiting**: SK doesn't retry by default; add retry policies for production
- **Memory vs RAG**: SK memory is simple vector search; for production RAG use dedicated vector DB skill
- **Version drift**: SK evolves rapidly; API breaks between minor versions — pin your version

## Related Skills

- `autogen` — alternative multi-agent framework
- `langchain` — alternative LLM orchestration framework
- `vector-rag-advanced` — production RAG patterns
- `azure-cloud-architect` — Azure AI service integration
- `agent-loop-patterns` — agent design patterns

## GitNexus Index

```
tool: semantic-kernel
category: llm-orchestration
tier: library
interface: python-sdk, dotnet-sdk
platform: cross-platform
stars: 24000+
```
