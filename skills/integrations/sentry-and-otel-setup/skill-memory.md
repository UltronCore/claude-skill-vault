# Skill Memory: Sentry and OpenTelemetry Setup

## Purpose
Guides the full setup of Sentry error tracking and OpenTelemetry performance monitoring for Next.js applications. Covers installation via the Sentry wizard, configuration of server/client/edge configs, structured logging wrapper creation, React error boundaries, custom error pages, and manual Server Action instrumentation. Includes sample rate configuration patterns to balance observability with quota management.

## Category notes
Belongs in integrations because it integrates the Sentry SaaS platform and the OpenTelemetry standard into a Next.js application stack.

## Relationships
- Often used alongside supabase-auth-ssr-setup (for setting Sentry user context from auth)
- Often used alongside supabase-prisma-database-management (Prisma queries auto-trace via OTel)
- Applicable to any Next.js project regardless of database or auth choice

## Maintenance notes
Sentry SDK APIs evolve frequently; verify `startTransaction` vs `startSpan` API against current @sentry/nextjs version. The `experimental.instrumentationHook` flag in Next.js became stable in Next.js 15 — update documentation when widely adopted.
