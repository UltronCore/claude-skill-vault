---
name: replicate
description: Replicate cloud platform for running and deploying ML models via simple Python API
version: 1.0.0
tags: [ml, inference, cloud, image-generation, deployment, api, models]
---

# Replicate — ML Model Deployment Platform

## Overview

Replicate is a cloud platform for running ML models via a simple Python API. It hosts thousands of community models (Stable Diffusion, Flux, Llama, Whisper, SDXL, ControlNet, etc.) with pay-per-second billing. You can also deploy your own models in Docker containers. The API is extremely simple — pass inputs, get outputs — with no infrastructure management. Especially strong for image/video generation, audio processing, and vision models.

GitHub: https://github.com/replicate/replicate-python (1k+ stars)
Website: https://replicate.com

## When to Use

- Running image/video generation models (Flux, SDXL, AnimateDiff) without GPU setup
- Quick ML model experiments without containerization overhead
- Running community models that aren't on HuggingFace
- Deploying your own custom model with a REST API in minutes
- Audio transcription with Whisper at scale
- Building apps that need ML capabilities without self-hosting

## Installation

```bash
pip install replicate

export REPLICATE_API_TOKEN="your-token-here"
```

## Key Patterns / Usage

### Basic Model Run
```python
import replicate

# Run Flux for image generation
output = replicate.run(
    "black-forest-labs/flux-schnell",
    input={
        "prompt": "A photorealistic image of a robot painting a sunset",
        "num_outputs": 1,
        "aspect_ratio": "16:9",
        "output_format": "webp",
    }
)

# output is a list of URLs
for image_url in output:
    print(f"Generated image: {image_url}")
```

### Download Generated Image
```python
import replicate
import requests
from pathlib import Path

output = replicate.run(
    "black-forest-labs/flux-dev",
    input={
        "prompt": "Abstract digital art, vibrant colors, 8k resolution",
        "num_inference_steps": 28,
        "guidance": 3.5,
        "width": 1440,
        "height": 1024,
    }
)

for i, image_url in enumerate(output):
    response = requests.get(str(image_url))
    Path(f"output_{i}.webp").write_bytes(response.content)
    print(f"Saved output_{i}.webp")
```

### Streaming Output for LLMs
```python
import replicate

# Stream text output from Llama
for event in replicate.stream(
    "meta/meta-llama-3-70b-instruct",
    input={
        "prompt": "Explain the attention mechanism in transformers",
        "max_tokens": 512,
        "temperature": 0.7,
        "system_prompt": "You are a helpful ML educator.",
    }
):
    print(str(event), end="", flush=True)
print()
```

### Audio Transcription with Whisper
```python
import replicate

# Transcribe a local audio file
with open("audio.mp3", "rb") as f:
    output = replicate.run(
        "openai/whisper",
        input={
            "audio": f,
            "language": "en",
            "transcription": "plain text",
            "translate": False,
        }
    )

print(output["transcription"])

# Or from a URL
output = replicate.run(
    "vaibhavs10/incredibly-fast-whisper",
    input={
        "audio": "https://example.com/podcast.mp3",
        "language": "None",  # Auto-detect
        "batch_size": 64,
    }
)
print(output["text"])
```

### Image-to-Image and Inpainting
```python
import replicate

# Image-to-image transformation
output = replicate.run(
    "stability-ai/sdxl",
    input={
        "image": open("input.jpg", "rb"),
        "prompt": "Convert to anime art style, vivid colors",
        "strength": 0.6,
        "num_inference_steps": 30,
    }
)

# ControlNet for precise control
output = replicate.run(
    "jagilley/controlnet-canny",
    input={
        "image": open("sketch.png", "rb"),
        "prompt": "Professional product photo, white background",
        "num_samples": "1",
        "image_resolution": "512",
    }
)
```

### Async Prediction (Long-Running Jobs)
```python
import replicate
import time

# Create a prediction and check status later
prediction = replicate.predictions.create(
    version="stability-ai/stable-video-diffusion:3f0457e4619daac51203dedb472816fd4af51f3149fa7a9e0b5ffcf1b8172438",
    input={
        "input_image": open("frame.jpg", "rb"),
        "sizing_strategy": "maintain_aspect_ratio",
        "frames_per_second": 6,
        "motion_bucket_id": 127,
    }
)

print(f"Prediction ID: {prediction.id}, Status: {prediction.status}")

# Poll for completion
while prediction.status not in ["succeeded", "failed", "canceled"]:
    time.sleep(2)
    prediction.reload()
    print(f"Status: {prediction.status}")

if prediction.status == "succeeded":
    print(f"Output: {prediction.output}")
else:
    print(f"Failed: {prediction.error}")
```

### Deploy Your Own Model
```python
# 1. Create a Cog model (cog.yaml + predict.py)
# Then deploy via CLI: cog push r8.im/your-username/your-model

# 2. Use the deployed model in Python
import replicate

# Run your custom deployed model
output = replicate.run(
    "your-username/your-model:latest",
    input={"text": "Hello, world!", "temperature": 0.8}
)
print(output)

# Or create a deployment for consistent latency
deployment = replicate.deployments.get("your-username/your-deployment-name")
prediction = deployment.predictions.create(
    input={"text": "Hello from deployment!"}
)
prediction.wait()
print(prediction.output)
```

### Batch Processing Multiple Inputs
```python
import replicate
import concurrent.futures

prompts = [
    "A serene mountain landscape at dawn",
    "A futuristic city with flying cars at night",
    "A cozy coffee shop on a rainy afternoon",
]

def generate_image(prompt: str) -> str:
    output = replicate.run(
        "black-forest-labs/flux-schnell",
        input={"prompt": prompt, "num_outputs": 1}
    )
    return str(output[0])

# Run in parallel (respects your API rate limits)
with concurrent.futures.ThreadPoolExecutor(max_workers=3) as executor:
    futures = {executor.submit(generate_image, p): p for p in prompts}
    for future in concurrent.futures.as_completed(futures):
        prompt = futures[future]
        url = future.result()
        print(f"Prompt: {prompt[:40]}... -> {url}")
```

## Common Pitfalls

- **Cold starts**: community models have long cold starts (30-120s); use deployments for latency-sensitive apps
- **Output URLs expire**: Replicate output URLs expire after 1 hour — download and store outputs immediately
- **Webhook vs polling**: for long-running models, webhooks are more efficient than polling; use `webhook` parameter
- **File inputs**: always pass file objects with `open("file", "rb")` for local files; URLs work too
- **Rate limits**: free tier is very limited; upgrade for production use
- **Model versions**: pin to a specific version hash for reproducible results; `latest` can change behavior
- **Cost unpredictability**: GPU-second billing can spike on slow models; test with small batches first

## Related Skills

- `together-ai` — alternative for LLM inference (cheaper for text)
- `modal-gpu` — run your own models on serverless GPU with more control
- `diffusion-models` — understanding the models running on Replicate
- `vllm-serving` — self-hosted alternative for LLM serving
- `computer-vision` — vision model patterns that pair with Replicate

## GitNexus Index

```
tool: replicate
category: ml-inference
tier: platform
interface: python-sdk, rest-api
platform: cloud
stars: 1000+
```
