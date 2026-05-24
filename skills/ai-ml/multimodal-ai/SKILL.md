---
name: multimodal-ai
description: >
  Vision and multimodal AI with Claude (image input, document analysis) and other models. Triggers on: image_url, base64 image, vision, pdf analysis, document understanding, ImageBlock, image/jpeg, image/png.
---

# Multimodal AI

## When to Use
- Sending images to Claude for analysis, description, or OCR
- Processing PDFs or documents with vision
- Combining image understanding with tool use
- Batch image analysis pipelines
- Handling file uploads in Next.js with vision
- Analyzing manga pages, UI screenshots, or charts

## Core Rules
1. Images can be provided as base64 (any source) or URL (publicly accessible HTTPS URLs only).
2. Supported media types: `image/jpeg`, `image/png`, `image/gif`, `image/webp`.
3. Maximum image size: 5MB per image; recommended max dimension: 1568px on the longest side.
4. Claude can handle up to ~20 images per request, but keep total request size under 20MB.
5. For URL images, Claude fetches them at request time — ensure they are publicly accessible (no auth, no signed URLs that expire).
6. PDFs are supported via the `document` block type with base64-encoded content.
7. Reduce image dimensions before sending if the image is larger than needed — smaller = faster + cheaper.
8. For OCR tasks, send the image at full resolution; for layout tasks, lower resolution is fine.
9. When analyzing multiple images, label them (e.g., "Image 1:", "Image 2:") in your prompt for clear referencing.
10. Always specify what you want from the image — vague prompts yield vague results.

## Single Image (Base64, Python)

```python
import anthropic
import base64
from pathlib import Path

client = anthropic.Anthropic()

def analyze_image(image_path: str, prompt: str) -> str:
    image_data = Path(image_path).read_bytes()
    b64_data = base64.standard_b64encode(image_data).decode("utf-8")

    # Detect media type from extension
    ext = Path(image_path).suffix.lower()
    media_type_map = {
        ".jpg": "image/jpeg", ".jpeg": "image/jpeg",
        ".png": "image/png", ".gif": "image/gif", ".webp": "image/webp"
    }
    media_type = media_type_map.get(ext, "image/jpeg")

    response = client.messages.create(
        model="claude-opus-4-5",
        max_tokens=1024,
        messages=[
            {
                "role": "user",
                "content": [
                    {
                        "type": "image",
                        "source": {
                            "type": "base64",
                            "media_type": media_type,
                            "data": b64_data,
                        },
                    },
                    {"type": "text", "text": prompt},
                ],
            }
        ],
    )
    return response.content[0].text

# Usage
description = analyze_image("screenshot.png", "Describe the UI layout in this screenshot.")
text = analyze_image("document.jpg", "Extract all text from this image (OCR).")
```

## Single Image (URL)

```python
response = client.messages.create(
    model="claude-opus-4-5",
    max_tokens=1024,
    messages=[
        {
            "role": "user",
            "content": [
                {
                    "type": "image",
                    "source": {
                        "type": "url",
                        "url": "https://upload.wikimedia.org/wikipedia/commons/thumb/4/47/PNG_transparency_demonstration_1.png/280px-PNG_transparency_demonstration_1.png",
                    },
                },
                {"type": "text", "text": "What do you see in this image?"},
            ],
        }
    ],
)
print(response.content[0].text)
```

## Multiple Images

```python
def compare_images(image_paths: list[str], comparison_prompt: str) -> str:
    content = []
    for i, path in enumerate(image_paths):
        b64 = base64.standard_b64encode(Path(path).read_bytes()).decode()
        ext = Path(path).suffix.lower()
        media_type = {"jpg": "image/jpeg", "jpeg": "image/jpeg",
                      "png": "image/png", "webp": "image/webp"}.get(ext.lstrip("."), "image/jpeg")

        content.append({"type": "text", "text": f"Image {i+1}:"})
        content.append({
            "type": "image",
            "source": {"type": "base64", "media_type": media_type, "data": b64}
        })

    content.append({"type": "text", "text": comparison_prompt})

    response = client.messages.create(
        model="claude-opus-4-5",
        max_tokens=2048,
        messages=[{"role": "user", "content": content}],
    )
    return response.content[0].text

# Compare before/after UI screenshots
result = compare_images(
    ["before.png", "after.png"],
    "What changed between Image 1 and Image 2? List specific UI differences."
)
```

## PDF / Document Analysis

```python
import base64
from pathlib import Path

def analyze_pdf(pdf_path: str, question: str) -> str:
    pdf_data = base64.standard_b64encode(Path(pdf_path).read_bytes()).decode()

    response = client.messages.create(
        model="claude-opus-4-5",
        max_tokens=4096,
        messages=[
            {
                "role": "user",
                "content": [
                    {
                        "type": "document",
                        "source": {
                            "type": "base64",
                            "media_type": "application/pdf",
                            "data": pdf_data,
                        },
                    },
                    {"type": "text", "text": question},
                ],
            }
        ],
    )
    return response.content[0].text

# Usage
summary = analyze_pdf("report.pdf", "Summarize the key findings from this report.")
data = analyze_pdf("invoice.pdf", "Extract: vendor name, invoice number, total amount, due date. Return as JSON.")
```

## TypeScript: Base64 Image

```typescript
import Anthropic from "@anthropic-ai/sdk";
import fs from "fs";
import path from "path";

const client = new Anthropic();

async function analyzeImage(imagePath: string, prompt: string): Promise<string> {
  const imageBuffer = fs.readFileSync(imagePath);
  const base64Data = imageBuffer.toString("base64");

  const ext = path.extname(imagePath).toLowerCase();
  const mediaTypeMap: Record<string, string> = {
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".png": "image/png",
    ".gif": "image/gif",
    ".webp": "image/webp",
  };
  const mediaType = (mediaTypeMap[ext] ?? "image/jpeg") as
    | "image/jpeg"
    | "image/png"
    | "image/gif"
    | "image/webp";

  const response = await client.messages.create({
    model: "claude-opus-4-5",
    max_tokens: 1024,
    messages: [
      {
        role: "user",
        content: [
          {
            type: "image",
            source: { type: "base64", media_type: mediaType, data: base64Data },
          },
          { type: "text", text: prompt },
        ],
      },
    ],
  });

  return (response.content[0] as Anthropic.TextBlock).text;
}
```

## Next.js File Upload + Vision API Route

```typescript
// app/api/analyze-image/route.ts
import { NextRequest, NextResponse } from "next/server";
import Anthropic from "@anthropic-ai/sdk";

const client = new Anthropic();

export async function POST(req: NextRequest) {
  const formData = await req.formData();
  const file = formData.get("image") as File;
  const prompt = (formData.get("prompt") as string) || "Describe this image.";

  if (!file) {
    return NextResponse.json({ error: "No image provided" }, { status: 400 });
  }

  // Validate file type
  const validTypes = ["image/jpeg", "image/png", "image/gif", "image/webp"];
  if (!validTypes.includes(file.type)) {
    return NextResponse.json({ error: "Unsupported image type" }, { status: 400 });
  }

  const arrayBuffer = await file.arrayBuffer();
  const base64 = Buffer.from(arrayBuffer).toString("base64");

  const response = await client.messages.create({
    model: "claude-opus-4-5",
    max_tokens: 1024,
    messages: [
      {
        role: "user",
        content: [
          {
            type: "image",
            source: {
              type: "base64",
              media_type: file.type as "image/jpeg" | "image/png" | "image/gif" | "image/webp",
              data: base64,
            },
          },
          { type: "text", text: prompt },
        ],
      },
    ],
  });

  return NextResponse.json({
    result: (response.content[0] as Anthropic.TextBlock).text,
  });
}
```

```typescript
// React component for image upload
"use client";
import { useState } from "react";

export function ImageAnalyzer() {
  const [result, setResult] = useState("");
  const [loading, setLoading] = useState(false);

  async function handleUpload(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file) return;

    setLoading(true);
    const formData = new FormData();
    formData.append("image", file);
    formData.append("prompt", "Describe what you see in this image in detail.");

    const res = await fetch("/api/analyze-image", { method: "POST", body: formData });
    const data = await res.json();
    setResult(data.result);
    setLoading(false);
  }

  return (
    <div>
      <input type="file" accept="image/*" onChange={handleUpload} />
      {loading && <p>Analyzing...</p>}
      {result && <p>{result}</p>}
    </div>
  );
}
```

## Manga Page Analysis

```python
def analyze_manga_page(image_path: str) -> dict:
    """Extract panels, text, and reading order from a manga page."""
    b64 = base64.standard_b64encode(Path(image_path).read_bytes()).decode()

    response = client.messages.create(
        model="claude-opus-4-5",
        max_tokens=2048,
        messages=[
            {
                "role": "user",
                "content": [
                    {
                        "type": "image",
                        "source": {"type": "base64", "media_type": "image/jpeg", "data": b64},
                    },
                    {
                        "type": "text",
                        "text": """Analyze this manga page. Return JSON with:
- "panels": list of panel descriptions in reading order (right-to-left, top-to-bottom)
- "dialogue": list of all speech bubbles/text in reading order
- "sound_effects": list of sound effects (onomatopoeia)
- "page_summary": one sentence summary of what happens

Return only valid JSON, no other text.""",
                    },
                ],
            }
        ],
    )

    import json
    return json.loads(response.content[0].text)
```

## Image Resizing Before Send (Python)

```python
from PIL import Image
import io
import base64

def prepare_image(image_path: str, max_dimension: int = 1568) -> tuple[str, str]:
    """Resize image if needed, return (base64_data, media_type)."""
    img = Image.open(image_path)

    # Resize if too large
    if max(img.size) > max_dimension:
        ratio = max_dimension / max(img.size)
        new_size = (int(img.width * ratio), int(img.height * ratio))
        img = img.resize(new_size, Image.LANCZOS)

    # Convert RGBA to RGB for JPEG
    if img.mode in ("RGBA", "P") and image_path.endswith((".jpg", ".jpeg")):
        img = img.convert("RGB")

    buffer = io.BytesIO()
    fmt = "PNG" if image_path.endswith(".png") else "JPEG"
    img.save(buffer, format=fmt, quality=85)
    buffer.seek(0)

    b64 = base64.standard_b64encode(buffer.read()).decode()
    media_type = "image/png" if fmt == "PNG" else "image/jpeg"
    return b64, media_type
```

## Vision + Tool Use

```python
# Claude can look at an image and call tools based on what it sees
tools = [
    {
        "name": "log_ui_issue",
        "description": "Log a UI bug or accessibility issue found in a screenshot",
        "input_schema": {
            "type": "object",
            "properties": {
                "issue_type": {"type": "string", "enum": ["layout", "color", "text", "missing_element", "accessibility"]},
                "severity": {"type": "string", "enum": ["low", "medium", "high"]},
                "description": {"type": "string"},
                "location": {"type": "string", "description": "Where in the UI (e.g. 'top-right navigation bar')"}
            },
            "required": ["issue_type", "severity", "description", "location"]
        }
    }
]

b64 = base64.standard_b64encode(Path("ui_screenshot.png").read_bytes()).decode()

response = client.messages.create(
    model="claude-opus-4-5",
    max_tokens=2048,
    tools=tools,
    tool_choice={"type": "any"},  # Force tool use
    messages=[
        {
            "role": "user",
            "content": [
                {"type": "image", "source": {"type": "base64", "media_type": "image/png", "data": b64}},
                {"type": "text", "text": "Review this UI screenshot for accessibility and layout issues. Log each issue you find."},
            ]
        }
    ],
)
```

## Batch Image Analysis

```python
import asyncio
import anthropic
from pathlib import Path

async def analyze_images_batch(image_paths: list[str], prompt: str) -> list[dict]:
    """Analyze multiple images concurrently."""
    client = anthropic.AsyncAnthropic()

    async def analyze_one(path: str) -> dict:
        b64 = base64.standard_b64encode(Path(path).read_bytes()).decode()
        ext = Path(path).suffix.lower().lstrip(".")
        media_type = {"jpg": "image/jpeg", "jpeg": "image/jpeg",
                      "png": "image/png", "webp": "image/webp"}.get(ext, "image/jpeg")
        try:
            response = await client.messages.create(
                model="claude-haiku-4-5",  # Use Haiku for batch cost savings
                max_tokens=512,
                messages=[{
                    "role": "user",
                    "content": [
                        {"type": "image", "source": {"type": "base64", "media_type": media_type, "data": b64}},
                        {"type": "text", "text": prompt}
                    ]
                }],
            )
            return {"path": path, "result": response.content[0].text, "error": None}
        except Exception as e:
            return {"path": path, "result": None, "error": str(e)}

    # Run up to 5 concurrent requests
    semaphore = asyncio.Semaphore(5)
    async def bounded(path):
        async with semaphore:
            return await analyze_one(path)

    return await asyncio.gather(*[bounded(p) for p in image_paths])

# Usage
results = asyncio.run(analyze_images_batch(
    ["page1.jpg", "page2.jpg", "page3.jpg"],
    "Is there any text in this image? If yes, transcribe it."
))
```

## Model Comparison for Vision Tasks

| Task | Best Model | Why |
|------|-----------|-----|
| Detailed analysis / reasoning | `claude-opus-4-5` | Best visual understanding |
| Fast OCR / simple description | `claude-haiku-4-5` | Cheap and fast |
| Document extraction | `claude-sonnet-4-5` | Balance of quality/cost |
| Batch processing | `claude-haiku-4-5` | Cost-efficient at scale |
| Code/UI screenshots | `claude-opus-4-5` | Best detail recognition |
| Medical/scientific images | `claude-opus-4-5` | Nuanced understanding |

## Related Skills
- `computer-vision` — vision models
- `diffusion-models` — image generation
- `embedding-pipeline` — multimodal embeddings

## GitNexus Index
This skill is indexed by GitNexus for knowledge graph traversal.
Index path: /Users/localuser/.claude/skills/multimodal-ai/.gitnexus
Last indexed: 2026-05-23
