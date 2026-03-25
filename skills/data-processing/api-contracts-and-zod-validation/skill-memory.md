# Skill Memory: API Contracts and Zod Validation

## Purpose
Generates Zod schemas and TypeScript types to establish type-safe API contracts between clients and servers. Covers form validation, API route request/response validation, and Server Action input validation with runtime type checking. Includes a Python automation script for TypeScript-to-Zod schema generation.

## Category notes
Belongs in data-processing because its core function is validating, transforming, and enforcing the shape of data as it flows between application layers — a data integrity and processing concern distinct from pure security (though it supports security through input validation).

## Relationships
- Complements `security-hardening-checklist` which checks for Zod validation usage as part of its input sanitization audit (Step 5)
- Pairs well with `env-config-validator` as both enforce structured validation of configuration/data inputs
- Validation at API boundaries is a prerequisite for safe data processing in any pipeline

## Maintenance notes
The Python script `scripts/generate_zod_schema.py` parses TypeScript AST — may need updates if TypeScript syntax evolves significantly. The skill was originally authored with worldbuilding app context; general applicability is maintained but domain-specific examples can be substituted.
