# Skill Memory: Security Hardening Checklist

## Purpose
Orchestrates a full-spectrum security audit across a Next.js application, systematically checking 10+ security domains: headers, cookies, database RLS, input validation, rate limiting, environment variables, HTTPS, CORS, and dependency vulnerabilities. Generates a scored report with fix code and prioritized remediation steps.

## Category notes
This is the broadest and most foundational skill in the security category — it serves as a top-level audit entry point that delegates deeper work to more specialized skills. Belongs in security as its sole purpose is identifying and remediating application security weaknesses.

## Relationships
- Acts as a "parent" audit skill that references concerns addressed in detail by `auth-route-protection-checker`, `csp-config-generator`, `supabase-rls-policy-generator`, and `env-config-validator`
- For deep-dive work on any individual area, those specialized skills should be used directly

## Maintenance notes
The OWASP Top 10 reference in `references/owasp-top-10.md` should be kept current as the list is updated periodically. Rate limiting examples use Upstash — if other providers become more common, example code may need expansion.
