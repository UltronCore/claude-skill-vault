---
name: structured-generation
description: Extract structured data from LLMs using JSON mode, function calling, constrained decoding (outlines, guidance), and validation. Covers OpenAI, Anthropic, and local model approaches.
version: 1.0.0
tags: [llm, structured-output, json-mode, function-calling, outlines, instructor, pydantic, extraction]
---

# Structured Generation

## Overview

This skill covers reliably extracting structured data from LLMs — converting unstructured text into typed, validated objects. It covers the spectrum from simple JSON mode to constrained decoding with grammar-based sampling, with integrations for OpenAI (function calling), Anthropic (tool use), and local models via outlines/guidance. Validated with Pydantic for Python or Zod for TypeScript.

## When to Use

- Extracting entities (people, dates, amounts) from documents or emails
- Building pipelines that need LLM output consumed by downstream code
- Converting natural language queries to structured filters or API params
- Classification tasks that need consistent output types
- Replacing regex extraction with LLM-powered extraction with validation

## Step-by-Step Workflow

### 1. Instructor (Python — Best for OpenAI/Anthropic)
```bash
pip install instructor openai pydantic
```

```python
import instructor
from openai import OpenAI
from pydantic import BaseModel, Field
from typing import Optional
from datetime import date

client = instructor.from_openai(OpenAI())

# Define schema as Pydantic model
class InvoiceExtraction(BaseModel):
    invoice_number: str = Field(description="Invoice ID or number")
    vendor_name: str = Field(description="Name of the company issuing the invoice")
    amount: float = Field(description="Total amount due in numeric form")
    currency: str = Field(default="USD", description="3-letter currency code")
    due_date: Optional[date] = Field(description="Payment due date if specified")
    line_items: list[dict] = Field(default_factory=list, description="List of items")

def extract_invoice(text: str) -> InvoiceExtraction:
    return client.chat.completions.create(
        model="gpt-4o-mini",
        response_model=InvoiceExtraction,
        messages=[
            {"role": "system", "content": "You are an invoice data extraction expert."},
            {"role": "user", "content": f"Extract invoice data from:\n\n{text}"}
        ],
        max_retries=3,  # Instructor automatically retries on validation failure
    )

invoice = extract_invoice("Please pay $1,250.00 to Acme Corp by June 30, 2024 (Invoice #INV-2024-0042)")
print(invoice.vendor_name)  # "Acme Corp"
print(invoice.amount)       # 1250.0
print(invoice.due_date)     # date(2024, 6, 30)
```

### 2. Anthropic Tool Use for Structured Output
```python
import anthropic
import json
from pydantic import BaseModel

class SentimentAnalysis(BaseModel):
    sentiment: str  # positive, negative, neutral
    score: float    # -1.0 to 1.0
    reasoning: str
    key_phrases: list[str]

def analyze_sentiment(text: str) -> SentimentAnalysis:
    client = anthropic.Anthropic()
    
    response = client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=1024,
        tools=[{
            "name": "record_sentiment",
            "description": "Record the sentiment analysis result",
            "input_schema": SentimentAnalysis.model_json_schema()
        }],
        tool_choice={"type": "tool", "name": "record_sentiment"},
        messages=[{
            "role": "user",
            "content": f"Analyze the sentiment of this text:\n\n{text}"
        }]
    )
    
    # Extract tool use block
    for block in response.content:
        if block.type == "tool_use" and block.name == "record_sentiment":
            return SentimentAnalysis(**block.input)
    
    raise ValueError("Model did not use the expected tool")

result = analyze_sentiment("The product was amazing but shipping took forever!")
print(result.sentiment)    # "positive"  
print(result.score)        # 0.4
```

### 3. OpenAI JSON Mode (Simple Cases)
```python
from openai import OpenAI
import json

client = OpenAI()

def classify_intent(user_message: str) -> dict:
    response = client.chat.completions.create(
        model="gpt-4o-mini",
        response_format={"type": "json_object"},
        messages=[
            {
                "role": "system",
                "content": """Classify the user intent. Return JSON with:
                {
                  "intent": "search|buy|return|support|other",
                  "confidence": 0.0-1.0,
                  "entities": {"product": null, "order_id": null}
                }"""
            },
            {"role": "user", "content": user_message}
        ]
    )
    return json.loads(response.choices[0].message.content)

result = classify_intent("I want to return order #12345")
print(result["intent"])    # "return"
print(result["entities"])  # {"order_id": "12345", "product": null}
```

### 4. Constrained Decoding with Outlines (Local Models)
```python
import outlines
from outlines import models, generate
from pydantic import BaseModel

# Works with local models (Llama, Mistral, Phi)
model = models.transformers("microsoft/Phi-3-mini-4k-instruct")

class MedicalExtraction(BaseModel):
    patient_age: int
    diagnosis: str
    medications: list[str]
    follow_up_days: int

# Outlines guarantees valid JSON matching the schema
# Uses constrained decoding — impossible to produce invalid output
generator = generate.json(model, MedicalExtraction)

result = generator("""
Patient: 45-year-old male
Diagnosis: Hypertension
Medications: Lisinopril 10mg daily, Aspirin 81mg daily
Follow-up: 3 months
""")

print(type(result))           # MedicalExtraction
print(result.patient_age)     # 45
print(result.medications)     # ["Lisinopril 10mg daily", "Aspirin 81mg daily"]
```

### 5. Batch Processing with Validation
```python
from pydantic import BaseModel, ValidationError
from typing import TypeVar, Type
import instructor
from openai import OpenAI

T = TypeVar('T', bound=BaseModel)

def batch_extract(
    texts: list[str],
    schema: Type[T],
    system_prompt: str,
    batch_size: int = 5,
) -> tuple[list[T], list[dict]]:
    client = instructor.from_openai(OpenAI())
    results, errors = [], []
    
    for i in range(0, len(texts), batch_size):
        batch = texts[i:i + batch_size]
        for j, text in enumerate(batch):
            try:
                result = client.chat.completions.create(
                    model="gpt-4o-mini",
                    response_model=schema,
                    messages=[
                        {"role": "system", "content": system_prompt},
                        {"role": "user", "content": text}
                    ],
                    max_retries=2,
                )
                results.append(result)
            except Exception as e:
                errors.append({"text": text[:100], "error": str(e), "index": i + j})
        
        print(f"Processed {min(i + batch_size, len(texts))}/{len(texts)}")
    
    return results, errors
```

### 6. TypeScript with Zod + Vercel AI SDK
```typescript
import { generateObject } from 'ai';
import { openai } from '@ai-sdk/openai';
import { z } from 'zod';

const ProductSchema = z.object({
  name: z.string(),
  price: z.number().positive(),
  category: z.enum(['electronics', 'clothing', 'food', 'other']),
  features: z.array(z.string()),
  inStock: z.boolean(),
});

type Product = z.infer<typeof ProductSchema>;

async function extractProduct(description: string): Promise<Product> {
  const { object } = await generateObject({
    model: openai('gpt-4o-mini'),
    schema: ProductSchema,
    prompt: `Extract product information from: ${description}`,
  });
  
  return object; // Typed as Product, Zod-validated
}

const product = await extractProduct(
  "The Sony WH-1000XM5 headphones are $279.99, in electronics category, " +
  "featuring ANC, 30h battery, USB-C. Currently in stock."
);
```

## Key Commands Reference

```bash
# Python setup
pip install instructor openai anthropic pydantic outlines

# Inspect Pydantic JSON schema (to understand what's sent to LLM)
python -c "from mymodule import MySchema; print(MySchema.model_json_schema())"

# Test extraction against golden set
python -m pytest tests/extraction/ -v --tb=short

# Validate extraction quality
python scripts/eval_extraction.py --dataset data/ground_truth.jsonl

# TypeScript
npm install ai @ai-sdk/openai zod
```

## Common Patterns

### Pattern 1: Multi-Step Extraction with Reasoning
```python
class ExtractionWithReasoning(BaseModel):
    thinking: str = Field(description="Step-by-step reasoning before extracting")
    result: InvoiceExtraction

# Model reasons before committing to structured output
response = client.chat.completions.create(
    model="gpt-4o",
    response_model=ExtractionWithReasoning,
    messages=[...]
)
# Access reasoning for debugging/evaluation
print(response.thinking)
print(response.result)
```

### Pattern 2: Partial Extraction for Streaming
```python
# Instructor supports partial model streaming
for partial in client.chat.completions.create_partial(
    model="gpt-4o-mini",
    response_model=LargeSchema,
    stream=True,
    messages=[...]
):
    if partial.field_one is not None:
        print(f"Got field_one: {partial.field_one}")
```

### Pattern 3: Fallback Chain
```python
def robust_extract(text: str, schema: type) -> tuple[object, str]:
    """Try increasingly capable models until extraction succeeds."""
    for model, max_retries in [("gpt-4o-mini", 2), ("gpt-4o", 3)]:
        try:
            result = client.chat.completions.create(
                model=model,
                response_model=schema,
                max_retries=max_retries,
                messages=[{"role": "user", "content": text}],
            )
            return result, model
        except Exception:
            continue
    raise ValueError("All models failed to extract structured data")
```

## Pitfalls to Avoid

1. **Vague field descriptions**: The LLM only knows what fields mean from their names and descriptions. A field named `amount` with no description will be ambiguous (gross? net? with tax?). Write field descriptions as if explaining to a new employee: "Total invoice amount including all taxes and fees, as a float with 2 decimal places."

2. **No retry/validation loop**: LLMs occasionally produce invalid structured output even with JSON mode. Always wrap extraction in retry logic. Instructor handles this automatically — when using raw JSON mode, implement your own: parse → validate → retry with error message if invalid.

3. **Sending entire documents when only a section matters**: Sending a 50-page PDF to extract one invoice header wastes tokens and reduces accuracy. Pre-extract the relevant section with a regex or simpler heuristic, then pass only that to the LLM for structured extraction.

## Related Skills

- `instructor` — Deep dive into the Instructor library
- `prompt-chaining` — Multi-step extraction pipelines
- `embedding-pipeline` — Processing documents before extraction
- `data-quality-validation` — Validating extracted data quality

## GitNexus Index

```json
{
  "skill": "structured-generation",
  "category": "ai-ml",
  "triggers": ["structured output", "json extraction", "function calling", "tool use extraction", "pydantic llm", "instructor", "outlines", "constrained decoding"],
  "outputs": ["pydantic model", "extraction function", "validated output", "batch extractor"],
  "complexity": "medium",
  "tools": ["instructor", "openai", "anthropic", "outlines", "pydantic", "zod"]
}
```
