# Skill Memory: Structured Output Extraction

## Purpose
Teaches Claude Code skills how to reliably extract typed, structured data from Claude responses. Primary method is tool_use (no extra dependencies). instructor library adds Pydantic validation + retry. pydantic-ai for full agent systems.

## Category notes
Belongs in data-processing — the core task is transforming unstructured LLM output into structured, validated data.

## Relationships
Pairs with api-contracts-and-zod-validation (TypeScript schema validation) and claude-api-integration (core API patterns). llm-routing-and-fallback handles model selection before calling.

## Maintenance notes
tool_use is the most reliable pattern — prefer it over prompt-based JSON extraction. instructor handles retries automatically when Pydantic validation fails. Do not use plain "return JSON" prompting for production code.
