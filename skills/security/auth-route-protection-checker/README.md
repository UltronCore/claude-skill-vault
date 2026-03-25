# Auth Route Protection Checker

**Category:** security
**Status:** active
**Version:** v1

## What it does
Audits Next.js applications for authentication and authorization gaps across pages, API routes, server components, and server actions. Generates protection code, helper utilities, and a prioritized report of unprotected routes organized by severity.

## When to use
- When you need to audit an existing Next.js app for missing auth checks
- When adding role-based or permission-based access control to routes
- When generating middleware configuration for protected route groups
- When you need reusable auth helper functions (requireAuth, requireRole, checkPermission)

## What it produces
A full audit report categorizing routes by protection level (public, authenticated, role-protected, action-protected), along with generated TypeScript code for server components, API routes, server actions, and middleware. Also produces test suites and documentation.

## Related skills
- security-hardening-checklist
- supabase-rls-policy-generator
- csp-config-generator
