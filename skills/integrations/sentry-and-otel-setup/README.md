# Sentry and OpenTelemetry Setup

**Category:** integrations
**Status:** active
**Version:** v1

## What it does
Configures comprehensive error tracking and performance monitoring using Sentry with OpenTelemetry (OTel) instrumentation for Next.js applications. Covers automatic error capture, distributed tracing, structured logging, error boundaries, and custom performance monitoring.

## When to use
- Adding error monitoring to a Next.js application for the first time
- Configuring distributed tracing for Server Actions and API routes
- Setting up structured logging with Sentry integration
- Establishing observability tooling before shipping to production

## What it produces
A fully configured Sentry + OTel observability stack including server/client/edge configs, instrumentation hook, logger wrapper, error boundaries, and custom error pages.

## Related skills
- supabase-auth-ssr-setup (auth utilities referenced in Sentry user context patterns)
- supabase-prisma-database-management (database query tracing via OTel)
