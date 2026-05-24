---
name: diffusion-models
description: Build and deploy diffusion model pipelines for image generation, inpainting, and fine-tuning using Hugging Face Diffusers. Covers Stable Diffusion, SDXL, ControlNet, LORA fine-tuning, img2img, inpainting, and production serving with batching.
version: 1.0.0
tags: [diffusion-models, stable-diffusion, sdxl, controlnet, lora, huggingface, diffusers, image-generation, inpainting, fine-tuning]
---

# Diffusion Models

## Overview

Diffusion models learn to reverse a gradual noising process to generate high-quality images from noise, conditioned on text prompts, images, or other signals. The Hugging Face Diffusers library provides a consistent API across Stable Diffusion, SDXL, Kandinsky, DeepFloyd, and ControlNet pipelines. Fine-tuning via LoRA (Low-Rank Adaptation) lets you adapt any base model to custom styles or subjects with minimal compute and no catastrophic forgetting.

## When to Use

- Generating product images, marketing assets, or concept art from text descriptions
- Inpainting to remove objects or replace backgrounds in existing images
- Style transfer and image-to-image transformations
- Fine-tuning a base model on proprietary brand imagery or character consistency
- ControlNet for pose/depth/edge-conditioned generation
- Building a production image generation API with GPU batching
- Creating synthetic training data for downstream computer vision models

## Step-by-Step Workflow

### 1. Basic Text-to-Image Pipeline

```python
# pip install diffusers transformers accelerate torch
from diffusers import StableDiffusionXLPipeline
import torch

def load_sdxl_pipeline(model_id: str = "stabilityai/stable-diffusion-xl-base-1.0") -> StableDiffusionXLPipeline:
    """Load SDXL with memory optimizations for consumer GPUs."""
    pipe = StableDiffusionXLPipeline.from_pretrained(
        model_id,
        torch_dtype=torch.float16,
        use_safetensors=True,
        variant="fp16",
    )
    pipe = pipe.to("cuda")

    # Memory optimizations
    pipe.enable_model_cpu_offload()  # Moves models to CPU when not in use
    pipe.enable_vae_slicing()         # Processes VAE in slices to reduce VRAM
    pipe.enable_attention_slicing()   # Slices attention computation

    return pipe

def generate_image(
    pipe: StableDiffusionXLPipeline,
    prompt: str,
    negative_prompt: str = "blurry, low quality, distorted",
    width: int = 1024,
    height: int = 1024,
    num_inference_steps: int = 30,
    guidance_scale: float = 7.5,
    seed: int | None = None,
):
    generator = torch.Generator("cuda").manual_seed(seed) if seed is not None else None
    images = pipe(
        prompt=prompt,
        negative_prompt=negative_prompt,
        width=width,
        height=height,
        num_inference_steps=num_inference_steps,
        guidance_scale=guidance_scale,
        generator=generator,
    ).images
    return images[0]

# Usage
pipe = load_sdxl_pipeline()
image = generate_image(
    pipe,
    prompt="A majestic wolf howling at the moon, dramatic lighting, photorealistic, 8k",
    seed=42,
)
image.save("output.png")
```

### 2. Image-to-Image and Inpainting

```python
from diffusers import StableDiffusionXLImg2ImgPipeline, StableDiffusionXLInpaintPipeline
from PIL import Image
import torch

# Image-to-image: transform an existing image
def img2img(
    source_image: Image.Image,
    prompt: str,
    strength: float = 0.7,  # 0=no change, 1=completely new image
    guidance_scale: float = 7.5,
    num_steps: int = 30,
) -> Image.Image:
    pipe = StableDiffusionXLImg2ImgPipeline.from_pretrained(
        "stabilityai/stable-diffusion-xl-refiner-1.0",
        torch_dtype=torch.float16,
        use_safetensors=True,
        variant="fp16",
    ).to("cuda")

    result = pipe(
        prompt=prompt,
        image=source_image.resize((1024, 1024)),
        strength=strength,
        guidance_scale=guidance_scale,
        num_inference_steps=num_steps,
    ).images[0]
    return result

# Inpainting: replace masked regions
def inpaint(
    source_image: Image.Image,
    mask_image: Image.Image,   # White=region to fill, Black=keep
    prompt: str,
    negative_prompt: str = "blurry, artifacts",
    num_steps: int = 50,
) -> Image.Image:
    pipe = StableDiffusionXLInpaintPipeline.from_pretrained(
        "diffusers/stable-diffusion-xl-1.0-inpainting-0.1",
        torch_dtype=torch.float16,
        use_safetensors=True,
    ).to("cuda")

    # Both images must be same size and powers of 2 are optimal
    w, h = source_image.size
    result = pipe(
        prompt=prompt,
        negative_prompt=negative_prompt,
        image=source_image,
        mask_image=mask_image,
        width=w,
        height=h,
        strength=0.99,  # High strength for inpainting
        num_inference_steps=num_steps,
        guidance_scale=8.0,
    ).images[0]
    return result

# Create a mask programmatically with PIL
from PIL import ImageDraw

def create_rect_mask(image: Image.Image, x1: int, y1: int, x2: int, y2: int) -> Image.Image:
    mask = Image.new("RGB", image.size, "black")
    draw = ImageDraw.Draw(mask)
    draw.rectangle([x1, y1, x2, y2], fill="white")
    return mask
```

### 3. ControlNet — Conditioned Generation

```python
# pip install controlnet_aux
from diffusers import ControlNetModel, StableDiffusionXLControlNetPipeline
from controlnet_aux import OpenposeDetector
import torch
import numpy as np
from PIL import Image

def setup_openpose_controlnet() -> tuple:
    """SDXL + ControlNet Pose: generate image matching a reference pose."""
    controlnet = ControlNetModel.from_pretrained(
        "thibaud/controlnet-openpose-sdxl-1.0",
        torch_dtype=torch.float16,
    )
    pipe = StableDiffusionXLControlNetPipeline.from_pretrained(
        "stabilityai/stable-diffusion-xl-base-1.0",
        controlnet=controlnet,
        torch_dtype=torch.float16,
        use_safetensors=True,
    ).to("cuda")
    pipe.enable_model_cpu_offload()
    return pipe

def generate_from_pose(
    pipe: StableDiffusionXLControlNetPipeline,
    pose_image: Image.Image,
    prompt: str,
    controlnet_conditioning_scale: float = 0.8,
    num_steps: int = 30,
) -> Image.Image:
    # Extract pose keypoints
    detector = OpenposeDetector.from_pretrained("lllyasviel/Annotators")
    pose_map = detector(pose_image, include_face=True, include_hand=True)

    result = pipe(
        prompt=prompt,
        image=pose_map,
        controlnet_conditioning_scale=controlnet_conditioning_scale,
        num_inference_steps=num_steps,
        guidance_scale=7.5,
    ).images[0]
    return result

# Canny edge ControlNet for structural consistency
from diffusers import ControlNetModel, StableDiffusionControlNetPipeline
import cv2

def generate_from_edges(source_image: Image.Image, prompt: str) -> Image.Image:
    # Extract edges with Canny
    img_array = np.array(source_image.convert("RGB"))
    edges = cv2.Canny(img_array, 100, 200)
    edge_image = Image.fromarray(edges).convert("RGB")

    controlnet = ControlNetModel.from_pretrained(
        "lllyasviel/control_v11p_sd15_canny",
        torch_dtype=torch.float16,
    )
    pipe = StableDiffusionControlNetPipeline.from_pretrained(
        "runwayml/stable-diffusion-v1-5",
        controlnet=controlnet,
        torch_dtype=torch.float16,
    ).to("cuda")

    return pipe(prompt=prompt, image=edge_image, num_inference_steps=30).images[0]
```

### 4. LoRA Fine-Tuning for Custom Styles/Subjects

```python
# Fine-tune SDXL with LoRA for a custom concept
# Requires: 5-20 high-quality images of the subject, ~1-2 hours on A100

# Training script (via diffusers examples)
# accelerate launch train_dreambooth_lora_sdxl.py \
#   --pretrained_model_name_or_path="stabilityai/stable-diffusion-xl-base-1.0" \
#   --instance_data_dir="./my_images" \
#   --output_dir="./lora_output" \
#   --instance_prompt="a photo of sks widget product" \
#   --resolution=1024 \
#   --train_batch_size=1 \
#   --gradient_accumulation_steps=4 \
#   --learning_rate=1e-4 \
#   --lr_scheduler="constant" \
#   --lr_warmup_steps=0 \
#   --max_train_steps=1000 \
#   --checkpointing_steps=250 \
#   --seed=0 \
#   --mixed_precision="fp16" \
#   --enable_xformers_memory_efficient_attention

# Loading a LoRA for inference
from diffusers import StableDiffusionXLPipeline
import torch

def load_with_lora(
    base_model: str,
    lora_path: str,
    lora_scale: float = 0.9,
) -> StableDiffusionXLPipeline:
    pipe = StableDiffusionXLPipeline.from_pretrained(
        base_model,
        torch_dtype=torch.float16,
    ).to("cuda")

    # Load LoRA weights
    pipe.load_lora_weights(lora_path)
    pipe.fuse_lora(lora_scale=lora_scale)  # Fuse for faster inference

    return pipe

# Combining multiple LoRAs
def load_multiple_loras(base_model: str, loras: list[tuple[str, float]]) -> StableDiffusionXLPipeline:
    """Load multiple LoRA adapters and scale each independently."""
    pipe = StableDiffusionXLPipeline.from_pretrained(base_model, torch_dtype=torch.float16).to("cuda")

    adapter_names = []
    for i, (lora_path, scale) in enumerate(loras):
        name = f"lora_{i}"
        pipe.load_lora_weights(lora_path, adapter_name=name)
        adapter_names.append(name)

    weights = [scale for _, scale in loras]
    pipe.set_adapters(adapter_names, adapter_weights=weights)
    return pipe
```

### 5. Production FastAPI Serving with Batching

```python
# pip install fastapi uvicorn diffusers torch Pillow
import asyncio
import base64
import io
import uuid
from dataclasses import dataclass, field
from typing import Optional
import torch
from diffusers import StableDiffusionXLPipeline
from fastapi import FastAPI, BackgroundTasks
from fastapi.responses import JSONResponse
from PIL import Image
from pydantic import BaseModel

app = FastAPI(title="Diffusion API")

# Global pipeline (loaded once at startup)
pipeline: Optional[StableDiffusionXLPipeline] = None
request_queue: asyncio.Queue = asyncio.Queue()

class GenerateRequest(BaseModel):
    prompt: str
    negative_prompt: str = "blurry, low quality"
    width: int = 1024
    height: int = 1024
    steps: int = 30
    guidance_scale: float = 7.5
    seed: Optional[int] = None

class GenerateResponse(BaseModel):
    job_id: str
    status: str = "queued"

job_results: dict[str, dict] = {}

@app.on_event("startup")
async def startup():
    global pipeline
    pipeline = StableDiffusionXLPipeline.from_pretrained(
        "stabilityai/stable-diffusion-xl-base-1.0",
        torch_dtype=torch.float16,
        use_safetensors=True,
    ).to("cuda")
    pipeline.enable_model_cpu_offload()
    # Start the batch worker
    asyncio.create_task(batch_worker())

async def batch_worker():
    """Process requests in batches of up to 4 for GPU efficiency."""
    while True:
        batch = []
        # Collect up to 4 requests or wait up to 100ms
        try:
            first = await asyncio.wait_for(request_queue.get(), timeout=0.1)
            batch.append(first)
            while len(batch) < 4:
                try:
                    item = request_queue.get_nowait()
                    batch.append(item)
                except asyncio.QueueEmpty:
                    break
        except asyncio.TimeoutError:
            continue

        if not batch:
            continue

        # Process batch
        prompts = [item["req"].prompt for item in batch]
        neg_prompts = [item["req"].negative_prompt for item in batch]

        loop = asyncio.get_event_loop()
        images = await loop.run_in_executor(None, lambda: pipeline(
            prompt=prompts,
            negative_prompt=neg_prompts,
            num_inference_steps=batch[0]["req"].steps,
        ).images)

        for item, image in zip(batch, images):
            buf = io.BytesIO()
            image.save(buf, format="PNG")
            job_results[item["job_id"]] = {
                "status": "complete",
                "image": base64.b64encode(buf.getvalue()).decode(),
            }

@app.post("/generate", response_model=GenerateResponse)
async def generate(req: GenerateRequest):
    job_id = str(uuid.uuid4())
    job_results[job_id] = {"status": "queued"}
    await request_queue.put({"job_id": job_id, "req": req})
    return GenerateResponse(job_id=job_id)

@app.get("/result/{job_id}")
async def get_result(job_id: str):
    result = job_results.get(job_id, {"status": "not_found"})
    return JSONResponse(result)

# Run: uvicorn serving:app --host 0.0.0.0 --port 8000 --workers 1
```

### 6. Scheduler and Sampler Control

```python
# Different schedulers give different quality/speed tradeoffs
from diffusers import (
    StableDiffusionXLPipeline,
    EulerAncestralDiscreteScheduler,
    DPMSolverMultistepScheduler,
    DDIMScheduler,
    KDPM2AncestralDiscreteScheduler,
)
import torch

def compare_schedulers(pipe: StableDiffusionXLPipeline, prompt: str) -> dict:
    """Run the same prompt with different schedulers for comparison."""
    schedulers = {
        "euler_a": EulerAncestralDiscreteScheduler.from_config(pipe.scheduler.config),
        "dpm_2m": DPMSolverMultistepScheduler.from_config(pipe.scheduler.config),
        "ddim": DDIMScheduler.from_config(pipe.scheduler.config),
        "kdpm2_a": KDPM2AncestralDiscreteScheduler.from_config(pipe.scheduler.config),
    }

    results = {}
    for name, scheduler in schedulers.items():
        pipe.scheduler = scheduler
        image = pipe(
            prompt=prompt,
            num_inference_steps=25,
            guidance_scale=7.5,
            generator=torch.Generator("cuda").manual_seed(42),
        ).images[0]
        results[name] = image

    return results

# Guidance scale effect: higher = more prompt-faithful, lower = more creative
# Typical ranges:
# 3-5: Creative, less prompt-faithful
# 7-8: Balanced (recommended default)
# 10-15: Very prompt-faithful, can be oversaturated
# 20+: Usually artifacts
```

## Key Commands Reference

```bash
# Install diffusers ecosystem
pip install diffusers transformers accelerate xformers torch torchvision

# CUDA memory inspection
python -c "import torch; print(torch.cuda.memory_allocated()/1e9, 'GB used')"
python -c "import torch; print(torch.cuda.get_device_properties(0).total_memory/1e9, 'GB total')"

# Download model to local cache
python -c "from diffusers import StableDiffusionXLPipeline; StableDiffusionXLPipeline.from_pretrained('stabilityai/stable-diffusion-xl-base-1.0', use_safetensors=True)"

# List cached models
ls ~/.cache/huggingface/hub/

# LoRA training with accelerate
accelerate config  # Set up distributed training config
accelerate launch train_dreambooth_lora_sdxl.py --help

# Convert safetensors LoRA for Diffusers
# Most Civitai LoRAs work directly with pipe.load_lora_weights()

# Benchmark inference speed
python -c "
import time, torch
from diffusers import StableDiffusionXLPipeline
pipe = StableDiffusionXLPipeline.from_pretrained('stabilityai/stable-diffusion-xl-base-1.0', torch_dtype=torch.float16).to('cuda')
t0 = time.time()
pipe('test prompt', num_inference_steps=20)
print(f'{time.time()-t0:.2f}s per image')
"

# Serve with Docker + NVIDIA runtime
docker run --gpus all -p 8000:8000 your-diffusion-api:latest
```

## Common Patterns

### Pattern 1: Prompt Engineering for SDXL

```python
# SDXL responds well to structured prompts with quality boosters
def build_sdxl_prompt(subject: str, style: str, quality_tags: list[str] | None = None) -> tuple[str, str]:
    """Build positive and negative prompts optimized for SDXL."""
    default_quality = ["masterpiece", "best quality", "detailed", "sharp focus", "8k uhd"]
    quality = quality_tags or default_quality

    positive = f"{subject}, {style}, {', '.join(quality)}"
    negative = (
        "worst quality, low quality, blurry, pixelated, watermark, text, "
        "cropped, frame, bad anatomy, deformed, ugly, duplicate, extra limbs"
    )
    return positive, negative

pos, neg = build_sdxl_prompt(
    subject="a sleek modern laptop on a minimalist desk",
    style="professional product photography, soft studio lighting, white background",
)
image = generate_image(pipe, pos, neg, seed=42)
```

### Pattern 2: Deterministic Seeded Generation with Variations

```python
# Generate variations from a single seed for A/B comparison
def generate_variations(
    pipe: StableDiffusionXLPipeline,
    prompt: str,
    base_seed: int = 42,
    n_variations: int = 4,
    guidance_scales: list[float] | None = None,
) -> list[Image.Image]:
    scales = guidance_scales or [6.0, 7.5, 9.0, 12.0]
    images = []
    for i, scale in enumerate(scales[:n_variations]):
        gen = torch.Generator("cuda").manual_seed(base_seed + i)
        img = pipe(prompt=prompt, guidance_scale=scale, generator=gen).images[0]
        images.append(img)
    return images
```

### Pattern 3: SDXL Refiner Pipeline

```python
# Two-stage: base generates structure, refiner adds detail
from diffusers import StableDiffusionXLPipeline, StableDiffusionXLImg2ImgPipeline

def generate_with_refiner(prompt: str, seed: int = 42) -> Image.Image:
    base = StableDiffusionXLPipeline.from_pretrained(
        "stabilityai/stable-diffusion-xl-base-1.0",
        torch_dtype=torch.float16,
    ).to("cuda")
    refiner = StableDiffusionXLImg2ImgPipeline.from_pretrained(
        "stabilityai/stable-diffusion-xl-refiner-1.0",
        torch_dtype=torch.float16,
    ).to("cuda")

    gen = torch.Generator("cuda").manual_seed(seed)

    # Base: generate latent (output_type="latent" skips VAE decode)
    latent = base(
        prompt=prompt,
        num_inference_steps=40,
        denoising_end=0.8,  # Hand off to refiner at 80%
        output_type="latent",
        generator=gen,
    ).images[0]

    # Refiner: add high-frequency detail
    image = refiner(
        prompt=prompt,
        num_inference_steps=40,
        denoising_start=0.8,  # Start where base left off
        image=latent[None],   # Add batch dim
        generator=gen,
    ).images[0]

    return image
```

## Pitfalls to Avoid

1. **CUDA OOM on consumer GPUs**: SDXL at 1024x1024 requires ~10 GB VRAM. Always call `enable_model_cpu_offload()` and `enable_vae_slicing()` on GPUs with less than 16 GB. For 8 GB GPUs, also use `enable_sequential_cpu_offload()` and `torch.float16` — this slows inference but prevents OOM. Never load both base and refiner pipelines simultaneously on a single 8 GB card.

2. **LoRA scale too high causes style collapse**: Setting `lora_scale > 1.0` or fusing at full weight typically overrides the base model style entirely. Start at 0.7-0.8 and adjust from there. Always test LoRAs with diverse prompts at multiple scales before deploying to production.

3. **Not using `use_safetensors=True`**: Safetensors format is faster to load and safer than pickle-based `.bin` files (no arbitrary code execution). Always add `use_safetensors=True` to `from_pretrained()` calls. The Diffusers library will fall back to `.bin` if safetensors isn't available, but most modern checkpoints ship with both.

## Related Skills

- `computer-vision` — Using generated images as training data for downstream CV models
- `embedding-pipeline` — CLIP embeddings for image-text retrieval alongside diffusion generation
- `peft-fine-tuning` — LoRA and QLoRA patterns that also apply to diffusion model fine-tuning
- `ray-distributed-computing` — Distributing diffusion inference across GPU nodes with Ray Serve

## GitNexus Index

```json
{
  "skill": "diffusion-models",
  "category": "ai-ml",
  "triggers": ["diffusion model", "stable diffusion", "sdxl", "controlnet", "lora fine-tuning", "image generation", "inpainting", "img2img", "dreambooth", "huggingface diffusers"],
  "outputs": ["StableDiffusionXLPipeline", "ControlNetModel", "LoRA weights", "FastAPI serving", "inpainting pipeline"],
  "complexity": "high",
  "tools": ["diffusers", "torch", "accelerate", "controlnet_aux", "xformers", "fastapi", "python"]
}
```
