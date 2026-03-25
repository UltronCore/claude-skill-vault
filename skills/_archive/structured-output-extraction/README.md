# Structured Output Extraction

**Category:** data-processing
**Status:** active
**Version:** v1

## What it does
Provides patterns for extracting guaranteed structured, typed output from Claude using tool_use, Pydantic models, or the instructor library.

## When to use
- Claude must return JSON that will be parsed by code
- Building typed pipelines where output structure matters
- Implementing data extraction from unstructured text
- Needing automatic retry on validation failure

## What it produces
Working code for tool_use-based extraction (no deps), instructor library integration, and pydantic-ai typed agents.

## Related skills
api-contracts-and-zod-validation, claude-api-integration
