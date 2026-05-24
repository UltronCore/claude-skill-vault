---
name: together-ai
description: Together AI cloud inference API for open-source LLMs with OpenAI-compatible endpoints
version: 1.0.0
tags: [llm, inference, cloud, api, open-source-models, embeddings]
---

# Together AI — Cloud Inference for Open-Source LLMs

## Overview

Together AI provides fast, cheap cloud inference for 100+ open-source models (Llama, Mistral, Qwen, DeepSeek, Flux, SDXL) via OpenAI-compatible REST APIs. No model management — just call the API. Pricing is typically 5-10x cheaper than OpenAI for equivalent open-source alternatives. Supports chat completions, embeddings, image generation, and fine-tuning. Drop-in replacement for OpenAI SDK in most cases.

Website: https://www.together.ai
Docs: https://docs.together.ai

## When to Use

- Running open-source models (Llama, Mistral, DeepSeek) without self-hosting
- Cost optimization vs. OpenAI/Anthropic for high-volume inference
- Accessing the latest open-source models (often available same day as release)
- Embedding generation with BAAI/bge models at scale
- Image generation with Flux or SDXL at lower cost than Stability AI
- Fine-tuning open-source models without managing GPU infrastructure

## Installation

```bash
pip install together

# Or use via the OpenAI SDK (drop-in compatible)
pip install openai
```

## Key Patterns / Usage

### Basic Chat Completion
```python
from together import Together

client = Together(api_key="your-api-key")  # Or set TOGETHER_API_KEY env var

response = client.chat.completions.create(
    model="meta-llama/Llama-3.3-70B-Instruct-Turbo",
    messages=[
        {"role": "system", "content": "You are a helpful assistant."},
        {"role": "user", "content": "Explain RAG in one paragraph."},
    ],
    max_tokens=512,
    temperature=0.7,
)

print(response.choices[0].message.content)
```

### Using OpenAI SDK as Drop-In Replacement
```python
from openai import OpenAI

# Point OpenAI client at Together's endpoint
client = OpenAI(
    api_key="your-together-api-key",
    base_url="https://api.together.xyz/v1",
)

response = client.chat.completions.create(
    model="mistralai/Mistral-7B-Instruct-v0.3",
    messages=[{"role": "user", "content": "What is the capital of Japan?"}],
)

print(response.choices[0].message.content)
```

### Streaming Responses
```python
from together import Together

client = Together()

stream = client.chat.completions.create(
    model="meta-llama/Llama-3.3-70B-Instruct-Turbo",
    messages=[{"role": "user", "content": "Write a haiku about machine learning."}],
    stream=True,
    max_tokens=200,
)

for chunk in stream:
    if chunk.choices[0].delta.content:
        print(chunk.choices[0].delta.content, end="", flush=True)
print()
```

### Embeddings
```python
from together import Together

client = Together()

# Together hosts BGE and other embedding models
response = client.embeddings.create(
    model="BAAI/bge-large-en-v1.5",
    input=[
        "Machine learning automates predictive models.",
        "Deep learning uses neural networks.",
        "The weather is nice today.",
    ],
)

# Access embeddings
for i, embedding_obj in enumerate(response.data):
    print(f"Text {i}: {len(embedding_obj.embedding)} dimensions")

# Use for similarity
import numpy as np

embeddings = np.array([e.embedding for e in response.data])
sim = np.dot(embeddings[0], embeddings[1]) / (
    np.linalg.norm(embeddings[0]) * np.linalg.norm(embeddings[1])
)
print(f"Similarity between text 0 and 1: {sim:.3f}")
```

### Structured Output (JSON Mode)
```python
from together import Together
import json

client = Together()

response = client.chat.completions.create(
    model="meta-llama/Meta-Llama-3.1-8B-Instruct-Turbo",
    messages=[
        {
            "role": "user",
            "content": """Extract structured data from this text as JSON:
            
            'Alice Smith, 34, is a senior ML engineer at TechCorp in Seattle. 
            She has 8 years of experience in NLP and computer vision.'
            
            Return: {"name": str, "age": int, "title": str, "company": str, 
                     "location": str, "years_experience": int, "skills": [str]}""",
        }
    ],
    response_format={"type": "json_object"},
)

data = json.loads(response.choices[0].message.content)
print(data)
```

### Image Generation with Flux
```python
from together import Together
import base64

client = Together()

response = client.images.generate(
    prompt="A photorealistic image of a robot learning to paint in a studio",
    model="black-forest-labs/FLUX.1-schnell",
    width=1024,
    height=1024,
    steps=4,
    n=1,
)

# Get base64 image
image_b64 = response.data[0].b64_json
image_bytes = base64.b64decode(image_b64)

with open("generated_image.png", "wb") as f:
    f.write(image_bytes)
print("Image saved.")
```

### Fine-Tuning a Model
```python
from together import Together

client = Together()

# Upload training file (JSONL format, OpenAI compatible)
with open("training_data.jsonl", "rb") as f:
    file_response = client.files.upload(file=("training_data.jsonl", f))

file_id = file_response.id
print(f"Uploaded file: {file_id}")

# Start fine-tuning job
ft_job = client.fine_tuning.create(
    training_file=file_id,
    model="meta-llama/Meta-Llama-3.1-8B-Instruct-Reference",
    n_epochs=3,
    learning_rate=1e-5,
    suffix="my-custom-model",
)

print(f"Fine-tune job: {ft_job.id}, status: {ft_job.status}")

# Check status
job = client.fine_tuning.retrieve(ft_job.id)
print(f"Status: {job.status}, model: {job.output_name}")
```

### Async Batch Processing
```python
import asyncio
from together import AsyncTogether

async def process_batch(texts: list[str]) -> list[str]:
    client = AsyncTogether()
    
    tasks = [
        client.chat.completions.create(
            model="meta-llama/Meta-Llama-3.1-8B-Instruct-Turbo",
            messages=[{"role": "user", "content": f"Summarize in one sentence: {text}"}],
            max_tokens=100,
        )
        for text in texts
    ]
    
    responses = await asyncio.gather(*tasks)
    return [r.choices[0].message.content for r in responses]

texts = [
    "Long article about climate change...",
    "Report on quarterly earnings...",
    "Research paper on transformer architectures...",
]

summaries = asyncio.run(process_batch(texts))
for text, summary in zip(texts, summaries):
    print(f"Original: {text[:40]}...")
    print(f"Summary: {summary}\n")
```

## Common Pitfalls

- **Rate limits**: default rate limits are lower than OpenAI; implement backoff for high-volume use
- **Model availability**: popular models can have queue times; check status dashboard during peak hours
- **Context length varies**: different models have different max context — check model card before assuming 128k+
- **JSON mode reliability**: structured output support varies by model; test your target model
- **Cold start latency**: some less-popular models have longer cold starts; stick to top-tier models for latency-sensitive applications
- **Fine-tune data format**: must be JSONL with `{"messages": [...]}` per line in OpenAI format; validate before upload
- **Image output format**: images returned as base64 by default; decode before saving

## Related Skills

- `litellm-proxy` — unified proxy that includes Together AI as a provider
- `openrouter-litellm` — alternative multi-provider router
- `vllm-serving` — self-hosted alternative for full control
- `ollama-integration` — local alternative for privacy-sensitive use cases
- `peft-fine-tuning` — understanding LoRA fine-tuning (Together uses this internally)

## GitNexus Index

```
tool: together-ai
category: llm-inference
tier: platform
interface: python-sdk, rest-api
platform: cloud
stars: N/A (commercial platform)
```
