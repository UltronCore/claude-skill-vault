# CSP Config Generator

**Category:** security
**Status:** active
**Version:** v1

## What it does
Analyzes a Next.js application's resource usage (scripts, styles, fonts, images, APIs) and generates a tailored Content Security Policy configuration using nonce-based, hash-based, or fallback strategies. Produces middleware, next.config.ts, and a CSP violation reporting endpoint.

## When to use
- When adding CSP headers to a Next.js app for the first time
- When tightening an existing permissive CSP (removing unsafe-inline/unsafe-eval)
- When setting up CSP violation reporting infrastructure
- When handling dev vs production CSP differences

## What it produces
TypeScript files for nonce generation, CSP middleware, next.config.ts header configuration, a violation reporting API route, test suite, and documentation. Covers all 10 standard CSP directives with environment-aware values.

## Related skills
- security-hardening-checklist
- auth-route-protection-checker
