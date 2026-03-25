# Skill Memory: Environment Configuration Validator

## Purpose
Validates environment configuration files (.env.*) for completeness, correct variable scoping, naming convention compliance, and security vulnerabilities such as secrets exposed in NEXT_PUBLIC_ variables or weak JWT secrets. Supports cross-environment comparison and CI/CD pipeline integration via a Python validation script.

## Category notes
Belongs in data-processing because its primary function is parsing, validating, and reporting on structured configuration data — a data integrity operation. The security angle is secondary to the data validation and cross-environment consistency checking that forms the core workflow.

## Relationships
- Overlaps with `security-hardening-checklist` Step 7 (Environment Variables Audit) — this skill provides much deeper coverage of that specific area
- Pairs with `api-contracts-and-zod-validation` as both enforce structured validation: this skill at the configuration layer, the other at the API/form layer

## Maintenance notes
Examples in this skill include service-specific variable names (OPENAI_API_KEY, STRIPE_SECRET_KEY, SENTRY_DSN). These are common and illustrative rather than prescriptive. The Python validation script path (`scripts/validate_env.py`) assumes it lives in the project root.
