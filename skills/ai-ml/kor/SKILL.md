---
name: kor
description: Structured data extraction from LLMs using schema definitions and few-shot examples
version: 1.0.0
tags: [llm, extraction, structured-output, langchain, schema, few-shot]
---

# Kor — Structured Data Extraction from LLMs

## Overview

Kor is a Python library that helps extract structured data from text using LLMs. It works by defining an extraction schema with type annotations and optional few-shot examples, then generating a prompt that coerces the LLM into returning machine-parseable output. Kor uses LangChain under the hood and produces validated, typed output dictionaries. Particularly useful for information extraction pipelines where reliability matters more than raw speed.

GitHub: https://github.com/eyurtsev/kor (1k+ stars)

## When to Use

- Extracting structured records from unstructured text (invoices, resumes, emails)
- Building NLP pipelines that need reliable typed output without manual parsing
- Few-shot extraction where examples dramatically improve accuracy
- When you want schema-defined extraction with minimal prompt engineering
- Prototyping extraction pipelines before committing to a vector-store approach

## Installation

```bash
pip install kor

# Kor uses LangChain for LLM access
pip install kor langchain langchain-openai
```

## Key Patterns / Usage

### Basic Object Extraction
```python
from kor import create_extraction_chain, Object, Text
from langchain_openai import ChatOpenAI

llm = ChatOpenAI(model="gpt-4o-mini", temperature=0)

# Define a schema for what to extract
schema = Object(
    id="person",
    description="Personal information about a person.",
    attributes=[
        Text(id="name", description="The full name of the person."),
        Text(id="age", description="The age of the person in years."),
        Text(id="occupation", description="The person's job or profession."),
    ],
    examples=[
        (
            "Alice, 32, works as a software engineer at a tech startup.",
            [{"name": "Alice", "age": "32", "occupation": "software engineer"}],
        )
    ],
)

chain = create_extraction_chain(llm, schema)
result = chain.invoke("John is a 45-year-old doctor who lives in New York.")
print(result["data"])
# {'person': [{'name': 'John', 'age': '45', 'occupation': 'doctor'}]}
```

### Extracting Multiple Records
```python
from kor import create_extraction_chain, Object, Text, Number

schema = Object(
    id="product",
    description="Product information from a catalog listing.",
    attributes=[
        Text(id="name", description="Product name."),
        Number(id="price", description="Product price in USD."),
        Text(id="category", description="Product category."),
    ],
    examples=[
        (
            "Blue widget, $12.99, category: hardware",
            [{"name": "Blue widget", "price": "12.99", "category": "hardware"}],
        )
    ],
    many=True,  # Extract multiple items
)

chain = create_extraction_chain(llm, schema)
text = """
- Red laptop bag: $29.99, accessories
- USB-C Hub 7-port: $45.00, electronics  
- Mechanical keyboard: $89.99, peripherals
"""
result = chain.invoke(text)
for product in result["data"]["product"]:
    print(f"{product['name']}: ${product['price']}")
```

### Nested Schema Extraction
```python
from kor import create_extraction_chain, Object, Text

address_schema = Object(
    id="address",
    description="A mailing address.",
    attributes=[
        Text(id="street", description="Street address."),
        Text(id="city", description="City name."),
        Text(id="state", description="State abbreviation."),
        Text(id="zip", description="ZIP code."),
    ],
)

contact_schema = Object(
    id="contact",
    description="Contact information for a person or business.",
    attributes=[
        Text(id="name", description="Full name or business name."),
        Text(id="phone", description="Phone number."),
        Text(id="email", description="Email address."),
        address_schema,  # Nest the address schema
    ],
    examples=[
        (
            "Reach Bob Smith at bob@example.com, (555) 123-4567, 100 Main St, Austin TX 78701",
            [{"name": "Bob Smith", "email": "bob@example.com", "phone": "(555) 123-4567",
              "address": [{"street": "100 Main St", "city": "Austin", "state": "TX", "zip": "78701"}]}],
        )
    ],
)

chain = create_extraction_chain(llm, contact_schema)
result = chain.invoke("Contact Acme Corp at info@acme.com, 415-555-9000, 500 Market St, San Francisco CA 94105")
print(result["data"])
```

### Selection (Enum) Fields
```python
from kor import create_extraction_chain, Object, Text, Selection

schema = Object(
    id="ticket",
    description="Support ticket classification.",
    attributes=[
        Text(id="summary", description="Brief summary of the issue."),
        Selection(
            id="priority",
            description="Ticket priority level.",
            options=["low", "medium", "high", "critical"],
        ),
        Selection(
            id="category",
            description="Issue category.",
            options=["billing", "technical", "account", "general"],
        ),
    ],
    examples=[
        (
            "My account was charged twice — this is urgent!",
            [{"summary": "Double charge on account", "priority": "critical", "category": "billing"}],
        )
    ],
)

chain = create_extraction_chain(llm, schema)
result = chain.invoke("I can't log in, it keeps saying password incorrect.")
print(result["data"]["ticket"])
# [{'summary': 'Login failure', 'priority': 'high', 'category': 'account'}]
```

### Batch Processing with Error Handling
```python
from kor import create_extraction_chain, Object, Text

schema = Object(
    id="invoice",
    description="Invoice data from billing records.",
    attributes=[
        Text(id="invoice_number", description="Invoice ID or number."),
        Text(id="vendor", description="Vendor or supplier name."),
        Text(id="amount", description="Total invoice amount."),
        Text(id="due_date", description="Payment due date."),
    ],
)

chain = create_extraction_chain(llm, schema)

invoices = [
    "Invoice #1042 from Acme Supplies, total $1,250.00, due 2024-02-15",
    "Bill from Webhost Co. (INV-2024-003): $89.99 due on February 28th",
    "No invoice data here, just a memo.",
]

for text in invoices:
    try:
        result = chain.invoke(text)
        data = result["data"].get("invoice", [])
        if data:
            print(f"Extracted: {data[0]}")
        else:
            print(f"No data found in: {text[:40]}...")
    except Exception as e:
        print(f"Extraction failed: {e}")
```

### Inspecting the Generated Prompt
```python
from kor import create_extraction_chain, Object, Text
from kor.encoders import JSONEncoder

# See what prompt Kor generates
schema = Object(
    id="event",
    description="Calendar event details.",
    attributes=[
        Text(id="title", description="Event title."),
        Text(id="date", description="Event date."),
        Text(id="location", description="Event location."),
    ],
)

chain = create_extraction_chain(llm, schema, encoder_or_encoder_class=JSONEncoder)

# Inspect the prompt
prompt = chain.get_prompts()[0]
print(prompt.format(text="Team meeting Thursday at 2pm in Conference Room B"))
```

## Common Pitfalls

- **LangChain dependency**: Kor couples to LangChain; version mismatches between `kor`, `langchain`, and `langchain-openai` are common — pin all three
- **All outputs are strings**: Number, Text, etc. return string values; cast to `int`/`float` in post-processing
- **Few-shot examples are critical**: Without examples, extraction quality degrades significantly on ambiguous text
- **Many=False by default**: Forgetting `many=True` means only the first match is returned even when multiple exist
- **No retry logic**: Kor doesn't retry malformed LLM output; wrap the chain call in a retry loop for production
- **OpenAI-centric**: Works best with OpenAI models; other providers may need prompt tuning
- **Limited maintenance**: Kor is minimally maintained; consider `instructor` or Pydantic-based extraction for new projects

## Related Skills

- `instructor` — alternative with retry logic and broader model support
- `marvin` — higher-level AI functions including extract()
- `structured-output-extraction` — general structured extraction patterns
- `outlines` — token-level constrained generation as an alternative

## GitNexus Index

```
tool: kor
category: llm-extraction
tier: library
interface: python-sdk
platform: cross-platform
stars: 1000+
```
