# Security Hardening Checklist

**Category:** security
**Status:** active
**Version:** v1

## What it does
Performs a comprehensive 12-step security audit of Next.js applications covering security headers, cookie configuration, RLS policies, input sanitization, rate limiting, environment variables, HTTPS enforcement, CORS, and dependency vulnerabilities. Produces a scored report with prioritized recommendations and fix scripts.

## When to use
- When doing a full security review of a Next.js application
- When preparing an app for production deployment
- When a security audit is required (compliance, team review, etc.)
- When investigating a specific security concern and wanting full context

## What it produces
A comprehensive security audit report with an overall security score, categorized issues (critical/high/medium/low), generated fix code for each issue area, and automation scripts. Output includes TypeScript utilities and SQL scripts for remediation.

## Related skills
- auth-route-protection-checker
- csp-config-generator
- supabase-rls-policy-generator
- env-config-validator
