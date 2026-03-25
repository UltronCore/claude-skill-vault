# Environment Configuration Validator

**Category:** data-processing
**Status:** active
**Version:** v1

## What it does
Validates `.env` files across local, staging, and production environments for required variables, correct scoping (NEXT_PUBLIC_* vs private), naming conventions, and security issues like weak secrets or credentials exposed in public variables. Includes a Python automation script for CI/CD integration.

## When to use
- When setting up a new environment and verifying all required variables are present
- When auditing env files for exposed secrets or improperly scoped variables
- When comparing variable consistency across dev/staging/production
- When integrating environment validation into a CI/CD deployment pipeline

## What it produces
Detailed validation reports with categorized errors and fixes for each issue type. Also produces a Python validation script (`scripts/validate_env.py`), reference documentation, and an `.env.example` template showing all required variables.

## Related skills
- api-contracts-and-zod-validation
- security-hardening-checklist
