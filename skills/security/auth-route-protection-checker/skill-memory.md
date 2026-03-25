# Skill Memory: Auth Route Protection Checker

## Purpose
Performs systematic audits of Next.js application route protection, identifying pages, API routes, server components, and server actions that lack proper authentication or authorization checks. Generates TypeScript protection code, reusable helper utilities, middleware configuration, test suites, and prioritized remediation reports.

## Category notes
Belongs in security because its core purpose is identifying and remediating authentication and authorization vulnerabilities in web application routing — a foundational aspect of application security posture.

## Relationships
- Complements `security-hardening-checklist` which covers broader security concerns beyond routing
- Works alongside `supabase-rls-policy-generator` for database-level security when Supabase is the auth provider
- Pairs with `csp-config-generator` for layered security (route auth + content security policy)

## Maintenance notes
Skill references Supabase as a primary auth provider example but includes patterns for NextAuth and Clerk as well. If new auth providers become common, example patterns may need updating.
